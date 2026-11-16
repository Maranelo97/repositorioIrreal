// Dibuja un marco sobre cada monstruo y cada otro jugador humano, aunque haya paredes en el
// medio (combo Vision). Los colores son los del radar de Sigan viendo: amarillo para los
// monstruos, verde para los jugadores y rojo para el Rey Cthulhu, que ademas lleva un marco
// doble, mas grande y mas grueso. Los pickups importantes que se pueden agarrar llevan un
// rombo blanco. Los marcos se llenan de abajo hacia arriba segun la vida que le queda a
// cada uno; el de los jugadores se divide en dos: vida a la izquierda (con un relleno mas
// claro para lo que pasa de 100) y escudo a la derecha. Las marcas son mas chicas cuanto
// mas lejos estan.
class GigaVisionOverlay extends HudOverlay;

// Mismos tipos de marca que GigaVisionInfo
const MARK_None = -1;
const MARK_Human = 1;
const MARK_Champion = 2;
const MARK_Pickup = 3;

var GigaVisionInfo Info;
var color MonsterColor, HumanColor, ChampionColor, PickupColor;
var color OverhealColor;  // vida de los jugadores por encima de 100
var color ShieldColor;    // escudo de los jugadores
var float MarkSize;       // tamano del marco a MarkRefDist unidades, en una pantalla de 1600 de ancho
var float MarkRefDist;
var float MinMarkSize, MaxMarkSize;
var float ChampionScale;  // cuanto mas grande es el marco del Rey Cthulhu
var byte FillAlpha;       // transparencia del relleno que muestra la vida

simulated function Render(Canvas C)
{
    local PlayerController PC;
    local Pawn P;
    local vector CamLoc, ViewDir;
    local float Line;
    local int i, Type;

    PC = Level.GetLocalPlayerController();
    if (Info == None || PC == None)
        return;

    CamLoc = PC.CalcViewLocation;
    ViewDir = vector(PC.CalcViewRotation);
    C.Style = ERenderStyle.STY_Alpha;
    Line = FMax(1.0, C.ClipX / 800.0);

    // En el host (o jugando solo) estan todos los pawns: se usan directamente, cuadro por cuadro
    if (Level.NetMode != NM_Client)
    {
        foreach DynamicActors(class'Pawn', P)
        {
            Type = class'GigaVisionInfo'.static.MarkTypeFor(P, PC);
            if (Type != MARK_None)
                DrawMark(C, P.Location, Type, class'GigaVisionInfo'.static.HealthFraction(P),
                    class'GigaVisionInfo'.static.ShieldFraction(P), CamLoc, ViewDir, Line);
        }
        // Los pickups no se mueven: salen de la lista que arma GigaVisionInfo
        for (i = 0; i < Info.NumMarks; i++)
            if (Info.GetType(i) == MARK_Pickup)
                DrawMark(C, Info.GetPos(i), MARK_Pickup, 0, 0, CamLoc, ViewDir, Line);
        return;
    }

    for (i = 0; i < Info.NumMarks; i++)
        DrawMark(C, Info.GetPos(i), Info.GetType(i), Info.GetHealth(i), Info.GetShield(i), CamLoc, ViewDir, Line);
}

simulated function DrawMark(Canvas C, vector Pos, int Type, float Health, float Shield, vector CamLoc, vector ViewDir, float Line)
{
    local vector Screen;
    local float Dist, Size;

    // Solo lo que esta delante de la camara
    if ((Pos - CamLoc) Dot ViewDir <= 0)
        return;

    Screen = C.WorldToScreen(Pos);
    Dist = FMax(1.0, VSize(Pos - CamLoc));
    Size = FClamp(MarkSize * MarkRefDist / Dist, MinMarkSize, MaxMarkSize) * C.ClipX / 1600.0;

    if (Type == MARK_Champion)
    {
        C.DrawColor = ChampionColor;
        Size *= ChampionScale;
        DrawHealthFill(C, Screen.X, Screen.Y, Size, Health);
        DrawFrame(C, Screen.X, Screen.Y, Size, Line * 2.0);
        DrawFrame(C, Screen.X, Screen.Y, Size * 0.7, Line * 2.0);
        return;
    }

    if (Type == MARK_Pickup)
    {
        C.DrawColor = PickupColor;
        DrawDiamond(C, Screen.X, Screen.Y, Size * 0.8, Line);
        return;
    }

    if (Type == MARK_Human)
    {
        DrawPlayerBars(C, Screen.X, Screen.Y, Size, Health, Shield, Line);
        return;
    }

    C.DrawColor = MonsterColor;
    DrawHealthFill(C, Screen.X, Screen.Y, Size, Health);
    DrawFrame(C, Screen.X, Screen.Y, Size, Line);
}

// Marco de un jugador partido al medio: vida a la izquierda (Health de 0 a 2; lo que pasa de
// 100 va con un relleno mas claro y opaco encima) y escudo a la derecha (Shield de 0 a 1)
simulated function DrawPlayerBars(Canvas C, float X, float Y, float Size, float Health, float Shield, float Line)
{
    local float Half, Bottom;

    Half = Size * 0.5;
    Bottom = Y + Half;

    C.DrawColor = HumanColor;
    C.DrawColor.A = FillAlpha;
    DrawBarFill(C, X - Half, Bottom, Half, Size * FMin(Health, 1.0));
    if (Health > 1.0)
    {
        C.DrawColor = OverhealColor;
        DrawBarFill(C, X - Half, Bottom, Half, Size * FMin(Health - 1.0, 1.0));
    }

    C.DrawColor = ShieldColor;
    DrawBarFill(C, X, Bottom, Half, Size * Shield);

    C.DrawColor = HumanColor;
    DrawFrame(C, X, Y, Size, Line);
    C.SetPos(X - Line * 0.5, Y - Half);
    C.DrawTile(Texture'Engine.WhiteTexture', Line, Size, 0, 0, 4, 4);
}

// Rectangulo de ancho W que sube Height desde Bottom, en el color actual del Canvas
simulated function DrawBarFill(Canvas C, float Left, float Bottom, float W, float Height)
{
    if (Height < 1.0)
        return;
    C.SetPos(Left, Bottom - Height);
    C.DrawTile(Texture'Engine.WhiteTexture', W, Height, 0, 0, 4, 4);
}

// Relleno transparente del color actual, de abajo hacia arriba segun la vida (0 a 1)
simulated function DrawHealthFill(Canvas C, float X, float Y, float Size, float Health)
{
    local byte OldAlpha;
    local float FillH;

    FillH = Size * FClamp(Health, 0.0, 1.0);
    if (FillH < 1.0)
        return;
    OldAlpha = C.DrawColor.A;
    C.DrawColor.A = FillAlpha;
    C.SetPos(X - Size * 0.5, Y + Size * 0.5 - FillH);
    C.DrawTile(Texture'Engine.WhiteTexture', Size, FillH, 0, 0, 4, 4);
    C.DrawColor.A = OldAlpha;
}

// Marco cuadrado hueco centrado en (X, Y)
simulated function DrawFrame(Canvas C, float X, float Y, float Size, float Line)
{
    local float H;

    H = Size * 0.5;
    C.SetPos(X - H, Y - H);
    C.DrawTile(Texture'Engine.WhiteTexture', Size, Line, 0, 0, 4, 4);
    C.SetPos(X - H, Y + H - Line);
    C.DrawTile(Texture'Engine.WhiteTexture', Size, Line, 0, 0, 4, 4);
    C.SetPos(X - H, Y - H);
    C.DrawTile(Texture'Engine.WhiteTexture', Line, Size, 0, 0, 4, 4);
    C.SetPos(X + H - Line, Y - H);
    C.DrawTile(Texture'Engine.WhiteTexture', Line, Size, 0, 0, 4, 4);
}

// Rombo hueco centrado en (X, Y), dibujado fila por fila
simulated function DrawDiamond(Canvas C, float X, float Y, float Size, float Line)
{
    local float H, DY, W;

    H = Size * 0.5;
    for (DY = -H; DY <= H; DY += 1.0)
    {
        W = H - Abs(DY);
        C.SetPos(X - W - Line * 0.5, Y + DY);
        C.DrawTile(Texture'Engine.WhiteTexture', Line, 1.0, 0, 0, 4, 4);
        C.SetPos(X + W - Line * 0.5, Y + DY);
        C.DrawTile(Texture'Engine.WhiteTexture', Line, 1.0, 0, 0, 4, 4);
    }
}

defaultproperties
{
    MonsterColor=(R=255,G=230,B=0,A=255)
    HumanColor=(R=40,G=255,B=40,A=255)
    ChampionColor=(R=255,G=20,B=0,A=255)
    PickupColor=(R=255,G=255,B=255,A=255)
    OverhealColor=(R=190,G=255,B=190,A=170)
    ShieldColor=(R=70,G=170,B=255,A=110)
    MarkSize=60.0
    MarkRefDist=1000.0
    MinMarkSize=16.0
    MaxMarkSize=120.0
    ChampionScale=1.6
    FillAlpha=90
}
