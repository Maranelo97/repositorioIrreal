// Dibuja encima del radar de Invasion (HUDInvasion):
// - un punto fijo, sin el parpadeo del pulso, por cada monstruo (amarillo) y cada jugador
//   (verde). Los bots no se tapan: quedan con el punto tenue del radar del juego, asi no
//   llenan el radar;
// - una linea vertical en cada monstruo y cada jugador que esta en otro piso;
// - el Rey Cthulhu (Marianosky's rage) como un circulo rojo mas grande, y Fer (Cuiden a
//   Fer!) en magenta aunque sea un bot, cada uno con su linea del mismo color.
// La ubicacion de cada punto sale de InvasionRadarMath, asi todo queda pegado a los puntos
// del radar aunque cambie de lugar o tamano.
class RadarMejoradoOverlay extends HudOverlay;

var RadarMejoradoReplicationInfo Settings;  // configuracion del servidor
var color MonsterColor, HumanColor;
var color OtherColor;       // pawns sin jugador (por ejemplo vehiculos vacios)
var color ChampionColor;    // punto y linea del Rey Cthulhu
var color FerColor;         // punto y linea de Fer
var float DotRadiusScale;   // radio del punto fijo respecto del tamano del punto del radar
var float ChampionRadiusScale;  // radio del punto del Rey Cthulhu (mas grande que el resto)
var float FerRadiusScale;   // radio del punto de Fer
var float FullLengthExtra;  // diferencia extra (sobre MinHeightDiff) para el largo maximo de la linea
var float GroundTraceDist;  // hasta donde se busca el piso debajo de un pawn en el aire

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
    local Pawn P, Champion, Fer;
    local CthulhuBossVisual BossVisual;
    local FerBRVisual FerVisual;
    local vector Start;
    local int ViewYaw;
    local float Dist, DotSize, DotRadius, X, Y, StemW, FeetZ;
    local float CircleX, CircleY, CircleR;
    local float ChampionX, ChampionY, FerX, FerY;
    local bool bChampionOnRadar, bFerOnRadar, bSpecial;

    H = HUDInvasion(Owner);
    if (Settings == None || !class'InvasionRadarMath'.static.RadarDrawnThisFrame(H))
        return;
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

    // El Rey Cthulhu y Fer se reconocen por actores que llegan a todos los clientes:
    // CthulhuBossVisual (el Tag 'ChampionMonster' solo existe en el servidor) y la marca que
    // Cuiden a Fer! pega en la espalda de Fer. Solo se resaltan con los puntos de colores.
    if (Settings.bColoredDots)
    {
        foreach DynamicActors(class'CthulhuBossVisual', BossVisual)
        {
            Champion = BossVisual.BossOwner;
            break;
        }
        foreach DynamicActors(class'FerBRVisual', FerVisual)
        {
            Fer = Pawn(FerVisual.Base);
            break;
        }
    }

    foreach DynamicActors(class'Pawn', P)
    {
        // Los bots quedan tenues, salvo que sean Fer
        if (P.Health <= 0 || (IsBot(P) && P != Fer))
            continue;

        if (!class'InvasionRadarMath'.static.GetDotPosition(H, C, Start, ViewYaw, P.Location, X, Y, Dist))
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
        else if (P == Fer)
        {
            C.DrawColor = FerColor;
            FerX = X;
            FerY = Y;
            bFerOnRadar = true;
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

    if (bFerOnRadar)
    {
        C.DrawColor = FerColor;
        class'InvasionRadarMath'.static.DrawDisc(C, FerX, FerY, DotSize * FerRadiusScale);
    }
    if (bChampionOnRadar)
    {
        C.DrawColor = ChampionColor;
        class'InvasionRadarMath'.static.DrawDisc(C, ChampionX, ChampionY, DotSize * ChampionRadiusScale);
    }
}

defaultproperties
{
    MonsterColor=(R=255,G=230,B=0,A=255)
    HumanColor=(R=40,G=255,B=40,A=255)
    OtherColor=(R=60,G=130,B=255,A=255)
    ChampionColor=(R=255,G=20,B=0,A=255)
    FerColor=(R=255,G=0,B=255,A=255)
    DotRadiusScale=0.33
    ChampionRadiusScale=0.48
    FerRadiusScale=0.42
    FullLengthExtra=900.0
    GroundTraceDist=3000.0
    bHidden=True
    RemoteRole=ROLE_None
}
