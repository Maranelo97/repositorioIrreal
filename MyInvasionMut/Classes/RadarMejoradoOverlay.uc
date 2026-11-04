// Dibuja encima del radar de Invasion (HUDInvasion):
// - un punto fijo, sin el parpadeo del pulso, por cada monstruo (amarillo) y cada jugador
//   (verde). Los bots no se tapan: quedan con el punto tenue del radar del juego, asi no
//   llenan el radar;
// - una linea vertical en cada monstruo y cada jugador que esta en otro piso;
// - el Rey Cthulhu (Marianosky's rage) como un circulo rojo mas grande, con su linea del
//   mismo color.
// Lo que queda fuera del circulo del radar no se dibuja.
// Ademas muestra la oleada actual y la final debajo del reloj, con el simbolo del Skaarj
// (opcion "Mostrar la oleada").
// La ubicacion de cada punto sale de InvasionRadarMath, asi todo queda pegado a los puntos
// del radar aunque cambie de lugar o tamano.
class RadarMejoradoOverlay extends HudOverlay;

var RadarMejoradoReplicationInfo Settings;  // configuracion del servidor
var color MonsterColor, HumanColor;
var color OtherColor;       // pawns sin jugador (por ejemplo vehiculos vacios)
var color ChampionColor;    // punto y linea del Rey Cthulhu
var float DotRadiusScale;   // radio del punto fijo respecto del tamano del punto del radar
var float ChampionRadiusScale;  // radio del punto del Rey Cthulhu (mas grande que el resto)
var float FullLengthExtra;  // diferencia extra (sobre MinHeightDiff) para el largo maximo de la linea
var float GroundTraceDist;  // hasta donde se busca el piso debajo de un pawn en el aire
// Oleada debajo del reloj, armada con los mismos widgets que el reloj de HudCDeathMatch
// (TimerBackgroundDisc, TimerBackground, TimerIcon y los numeros DigitsBig), una fila mas abajo
var string WaveIconName;             // simbolo de equipo del Skaarj, del juego
var Material WaveIcon;
var HudBase.SpriteWidget WaveDisc;     // circulo oscuro, como el del reloj
var HudBase.SpriteWidget WaveBack;     // barra oscura detras de los numeros
var HudBase.SpriteWidget WaveSymbol;   // simbolo del Skaarj, del tamano del cronometro
var HudBase.SpriteWidget WaveSlash;    // un escalon de la barra "/" entre la oleada actual y la final
var HudBase.NumericWidget WaveNumber;  // oleada actual
var HudBase.NumericWidget WaveFinal;   // oleada final
var HudBase.DigitSet WaveDigits;       // los mismos numeros que el reloj (DigitsBig)
var int DigitAdvance;                  // ancho de un numero, en las unidades de OffsetX de los numeros

// Altura del piso sobre el que esta P: sus pies si camina, o el piso debajo si salta o cae.
// Se usa solo para el jugador que mira el radar, asi las lineas no parpadean al saltar.
// (Para los monstruos se usa su altura real: con el piso debajo, un monstruo volando sobre
// una parte mas baja del mapa aparecia "abajo" aunque estuviera arriba.)
simulated function float GroundZ(Pawn P)
{
    local vector HitLocation, HitNormal;

    if (P.Physics != PHYS_Flying && P.Physics != PHYS_Falling)
        return P.Location.Z - P.CollisionHeight;

    if (Trace(HitLocation, HitNormal, P.Location - vect(0, 0, 1) * GroundTraceDist, P.Location, false) != None)
        return HitLocation.Z;
    return P.Location.Z - P.CollisionHeight;
}

// Bots: la informacion del jugador (que se replica a todos) dice si es un bot
simulated function bool IsBot(Pawn P)
{
    return P.PlayerReplicationInfo != None && P.PlayerReplicationInfo.bBot;
}

simulated function color DotColorFor(Pawn P)
{
    if (Monster(P) != None)
        return MonsterColor;
    if (P.PlayerReplicationInfo != None)
        return HumanColor;
    return OtherColor;
}

// Linea de altura de P (si esta en otro piso), recortada en el borde del radar
simulated function DrawHeightLine(Canvas C, Pawn P, float X, float Y, float FeetZ, float DotSize, float DotRadius,
    float StemW, float MinDiff, float CircleX, float CircleY, float CircleR)
{
    local float DZ, StemLen, StemTop, StemBottom, HalfChord;

    // Altura real de los pies (vuele o camine) contra el piso del jugador
    DZ = (P.Location.Z - P.CollisionHeight) - FeetZ;
    if (Abs(DZ) < MinDiff)
        return;

    // Largo entre medio punto y dos puntos, segun la diferencia de altura
    StemLen = DotSize * (0.5 + 1.5 * FMin(1.0, (Abs(DZ) - MinDiff) / FullLengthExtra));

    // Como en los radares de los juegos de vuelo: si esta arriba, el punto queda
    // sobre un poste (la linea baja); si esta abajo, el punto cuelga de la linea (la linea sube)
    if (DZ > 0)
    {
        StemTop = Y + DotRadius;
        StemBottom = StemTop + StemLen;
    }
    else
    {
        StemBottom = Y - DotRadius;
        StemTop = StemBottom - StemLen;
    }

    if (Abs(X - CircleX) >= CircleR)
        return;
    HalfChord = Sqrt(CircleR * CircleR - (X - CircleX) * (X - CircleX));
    StemTop = FMax(StemTop, CircleY - HalfChord);
    StemBottom = FMin(StemBottom, CircleY + HalfChord);
    if (StemBottom - StemTop < 1.0)
        return;

    C.SetPos(X - 0.5 * StemW, StemTop);
    C.DrawTile(Texture'Engine.WhiteTexture', StemW, StemBottom - StemTop, 0, 0, 4, 4);
}

simulated function Render(Canvas C)
{
    local HUDInvasion H;
    local Pawn P, Champion;
    local CthulhuBossVisual BossVisual;
    local vector Start;
    local int ViewYaw;
    local float Dist, DotSize, DotRadius, X, Y, StemW, FeetZ;
    local float CircleX, CircleY, CircleR;
    local float ChampionX, ChampionY;
    local bool bChampionOnRadar, bSpecial;

    H = HUDInvasion(Owner);
    if (Settings == None || !class'InvasionRadarMath'.static.RadarDrawnThisFrame(H))
        return;
    if (Settings.bShowWave)
        DrawWave(C, H);
    if (!Settings.bColoredDots && !Settings.bShowHeightLines)
        return;

    class'InvasionRadarMath'.static.GetViewer(H, Start, ViewYaw, FeetZ);
    if (H.PawnOwner != None)
        FeetZ = GroundZ(H.PawnOwner);

    DotSize = class'InvasionRadarMath'.static.DotSize(H, C);
    DotRadius = DotSize * DotRadiusScale;
    StemW = FMax(2.0, DotSize * 0.15);
    class'InvasionRadarMath'.static.GetRadarCircle(H, C, CircleX, CircleY, CircleR);
    C.Style = ERenderStyle.STY_Alpha;

    // El Rey Cthulhu se reconoce por CthulhuBossVisual, que llega a todos los clientes (el
    // Tag 'ChampionMonster' solo existe en el servidor). Solo se resalta con los puntos de colores.
    if (Settings.bColoredDots)
    {
        foreach DynamicActors(class'CthulhuBossVisual', BossVisual)
        {
            Champion = BossVisual.BossOwner;
            break;
        }
    }

    foreach DynamicActors(class'Pawn', P)
    {
        // Los bots quedan tenues
        if (P.Health <= 0 || IsBot(P))
            continue;

        if (!class'InvasionRadarMath'.static.GetDotPosition(H, C, Start, ViewYaw, P.Location, X, Y, Dist))
            continue;
        // Fuera del circulo del radar no se dibuja nada (la linea de altura ya se recorta igual)
        if ((X - CircleX) * (X - CircleX) + (Y - CircleY) * (Y - CircleY) >= CircleR * CircleR)
            continue;

        // Los puntos resaltados se dibujan al final, asi quedan encima de los demas
        bSpecial = true;
        if (P == Champion)
        {
            C.DrawColor = ChampionColor;
            ChampionX = X;
            ChampionY = Y;
            bChampionOnRadar = true;
        }
        else
        {
            // Sin los puntos de colores, la linea igual usa el color del tipo de pawn
            bSpecial = false;
            C.DrawColor = DotColorFor(P);
            if (Settings.bColoredDots)
                class'InvasionRadarMath'.static.DrawDisc(C, X, Y, DotRadius);
        }

        // Linea de altura para monstruos y jugadores en otro piso (nunca para uno mismo)
        if (!Settings.bShowHeightLines || P == H.PawnOwner)
            continue;
        if (!bSpecial && Monster(P) == None && P.PlayerReplicationInfo == None)
            continue;
        DrawHeightLine(C, P, X, Y, FeetZ, DotSize, DotRadius, StemW, Settings.MinHeightDiff, CircleX, CircleY, CircleR);
    }

    if (bChampionOnRadar)
    {
        C.DrawColor = ChampionColor;
        class'InvasionRadarMath'.static.DrawDisc(C, ChampionX, ChampionY, DotSize * ChampionRadiusScale);
    }
}

// Simbolo del Skaarj y "3 - 16" debajo del reloj de arriba a la izquierda, con los mismos
// widgets que el reloj: el mismo circulo, la misma barra y los mismos numeros, y el simbolo del
// tamano del cronometro. Los dibuja el propio HUD (DrawSpriteWidget / DrawNumericWidget), asi
// escalan igual que el reloj con la resolucion y con HudScale. Los OffsetX/OffsetY de cada
// widget estan en pixeles de su textura (se multiplican por su TextureScale), y todo va una
// fila mas abajo que el reloj (unas 30 unidades). La oleada sale de InvasionGameReplicationInfo
// (empieza en 0; en el descanso ya es la que viene) y la final la manda el servidor en Settings.
simulated function DrawWave(Canvas C, HUDInvasion H)
{
    local InvasionGameReplicationInfo GRI;
    local int Wave, Digits;

    if (H.PlayerOwner == None)
        return;
    GRI = InvasionGameReplicationInfo(H.PlayerOwner.GameReplicationInfo);
    if (GRI == None)
        return;
    Wave = GRI.WaveNumber + 1;

    // Se carga por nombre la primera vez, asi el paquete no depende de la textura al compilar
    if (WaveIcon == None)
        WaveIcon = Material(DynamicLoadObject(WaveIconName, class'Material', true));

    H.DrawSpriteWidget(C, WaveBack);
    H.DrawSpriteWidget(C, WaveDisc);
    if (WaveIcon != None)
    {
        WaveSymbol.WidgetTexture = WaveIcon;
        H.DrawSpriteWidget(C, WaveSymbol);
    }

    WaveNumber.Value = Wave;
    H.DrawNumericWidget(C, WaveNumber, WaveDigits);

    // La barra y la oleada final van despues de los numeros de la actual (1 o 2 cifras)
    if (Settings.FinalWave > 0)
    {
        Digits = 1;
        if (Wave >= 10)
            Digits = 2;
        DrawSlash(C, H, WaveNumber.OffsetX + DigitAdvance * Digits);
        WaveFinal.OffsetX = WaveNumber.OffsetX + DigitAdvance * (Digits + 1);
        WaveFinal.Value = Settings.FinalWave;
        H.DrawNumericWidget(C, WaveFinal, WaveDigits);
    }
}

// Los numeros del reloj no traen "/", asi que la barra se arma con escalones: cuadraditos
// blancos (WaveSlash) que el propio HUD dibuja uno por fila, corridos un poco a la izquierda en
// cada fila. Como son widgets con el mismo TextureScale que los numeros, sus OffsetX/OffsetY
// estan en las mismas unidades y escalan igual que el reloj. Ocupa el lugar de un numero
// (DigitAdvance de ancho), con el mismo alto de los numeros, centrada en su OffsetY.
simulated function DrawSlash(Canvas C, HUDInvasion H, int CellX)
{
    local int Row;

    for (Row = 0; Row < 27; Row++)
    {
        WaveSlash.OffsetX = CellX + 26 - (Row * 16) / 26;
        WaveSlash.OffsetY = WaveNumber.OffsetY - 13 + Row;
        H.DrawSpriteWidget(C, WaveSlash);
    }
}

defaultproperties
{
    MonsterColor=(R=255,G=230,B=0,A=255)
    HumanColor=(R=40,G=255,B=40,A=255)
    OtherColor=(R=60,G=130,B=255,A=255)
    ChampionColor=(R=255,G=20,B=0,A=255)
    DotRadiusScale=0.33
    ChampionRadiusScale=0.48
    FullLengthExtra=900.0
    GroundTraceDist=3000.0
    WaveIconName="TeamSymbols_UT2004.Team.Skaarj"
    WaveDisc=(WidgetTexture=Texture'HUDContent.Generic.HUD',RenderStyle=STY_Alpha,TextureCoords=(X1=119,Y1=258,X2=173,Y2=313),TextureScale=0.53,OffsetY=57,ScaleMode=SM_Right,Scale=1.0,Tints[0]=(R=255,G=255,B=255,A=255),Tints[1]=(R=255,G=255,B=255,A=255))
    WaveBack=(WidgetTexture=Texture'HUDContent.Generic.HUD',RenderStyle=STY_Alpha,TextureCoords=(X1=168,Y1=211,X2=334,Y2=255),TextureScale=0.4,OffsetX=60,OffsetY=89,ScaleMode=SM_Right,Scale=1.0,Tints[0]=(R=0,G=0,B=0,A=150),Tints[1]=(R=0,G=0,B=0,A=150))
    WaveSymbol=(RenderStyle=STY_Alpha,TextureCoords=(X1=0,Y1=0,X2=256,Y2=256),TextureScale=0.073,OffsetX=75,OffsetY=479,ScaleMode=SM_Right,Scale=1.0,Tints[0]=(R=180,G=180,B=188,A=255),Tints[1]=(R=180,G=180,B=188,A=255))
    WaveSlash=(WidgetTexture=Texture'Engine.WhiteTexture',RenderStyle=STY_Alpha,TextureCoords=(X2=6,Y2=2),TextureScale=0.32,ScaleMode=SM_Right,Scale=1.0,Tints[0]=(R=180,G=180,B=188,A=255),Tints[1]=(R=180,G=180,B=188,A=255))
    WaveNumber=(RenderStyle=STY_Alpha,MinDigitCount=1,TextureScale=0.32,DrawPivot=DP_MiddleLeft,OffsetX=90,OffsetY=139,Tints[0]=(R=255,G=255,B=255,A=255),Tints[1]=(R=255,G=255,B=255,A=255))
    WaveFinal=(RenderStyle=STY_Alpha,MinDigitCount=1,TextureScale=0.32,DrawPivot=DP_MiddleLeft,OffsetY=139,Tints[0]=(R=255,G=255,B=255,A=255),Tints[1]=(R=255,G=255,B=255,A=255))
    WaveDigits=(DigitTexture=Texture'HUDContent.Generic.HUD',TextureCoords[0]=(X2=38,Y2=38),TextureCoords[1]=(X1=39,X2=77,Y2=38),TextureCoords[2]=(X1=78,X2=116,Y2=38),TextureCoords[3]=(X1=117,X2=155,Y2=38),TextureCoords[4]=(X1=156,X2=194,Y2=38),TextureCoords[5]=(X1=195,X2=233,Y2=38),TextureCoords[6]=(X1=234,X2=272,Y2=38),TextureCoords[7]=(X1=273,X2=311,Y2=38),TextureCoords[8]=(X1=312,X2=350,Y2=38),TextureCoords[9]=(X1=351,X2=389,Y2=38),TextureCoords[10]=(X1=390,X2=428,Y2=38))
    DigitAdvance=39
    bHidden=True
    RemoteRole=ROLE_None
}
