// Cuentas del radar de Invasion (HUDInvasion.ShowTeamScorePassC), compartidas por los
// dibujos que se agregan encima del radar, para que queden pegados a los puntos.
class InvasionRadarMath extends Object
    abstract;

// Desde donde mide el radar: el pawn del jugador o, si no hay, el jugador mismo
static function GetViewer(HUDInvasion H, out vector Start, out int ViewYaw, out float FeetZ)
{
    if (H.PawnOwner != None)
    {
        Start = H.PawnOwner.Location;
        ViewYaw = H.PawnOwner.Rotation.Yaw;
        FeetZ = Start.Z - H.PawnOwner.CollisionHeight;
    }
    else
    {
        Start = H.PlayerOwner.Location;
        ViewYaw = H.PlayerOwner.Rotation.Yaw;
        FeetZ = Start.Z;
    }
}

// Tamano del punto del radar en pantalla
static function float DotSize(HUDInvasion H, Canvas C)
{
    return 24 * C.ClipX * H.HUDScale / 1600;
}

// Centro en pantalla del punto de Target. Devuelve false si esta fuera del alcance del radar.
static function bool GetDotPosition(HUDInvasion H, Canvas C, vector Start, int ViewYaw, vector Target, out float X, out float Y, out float Dist)
{
    local float RadarWidth, OffsetY, OffsetScale, Angle;
    local rotator Dir;

    Dist = VSize(Start - Target);
    if (Dist >= 3000)
        return false;

    RadarWidth = 0.5 * H.RadarScale * C.ClipX;
    OffsetY = H.RadarPosY + RadarWidth / C.ClipY;
    Dir = rotator(Target - Start);
    OffsetScale = H.RadarScale * Dist * 0.000167;
    Angle = ((Dir.Yaw - ViewYaw) & 65535) * 6.2832 / 65536;
    X = H.RadarPosX * C.ClipX + OffsetScale * C.ClipX * sin(Angle);
    Y = OffsetY * C.ClipY - OffsetScale * C.ClipX * cos(Angle);
    return true;
}

// Centro y radio del circulo del radar en pantalla
static function GetRadarCircle(HUDInvasion H, Canvas C, out float CenterX, out float CenterY, out float Radius)
{
    Radius = 0.5 * H.RadarScale * C.ClipX;
    CenterX = H.RadarPosX * C.ClipX;
    CenterY = H.RadarPosY * C.ClipY + Radius;
}

// Mismo brillo que el pulso del radar para un punto a esa distancia
static function float PulseBrightness(HUDInvasion H, float Dist)
{
    if (Dist < 3000 * H.RadarPulse)
        return 255 - 255 * Abs(Dist * 0.00033 - H.RadarPulse);
    return 255 - 255 * Abs(Dist * 0.00033 - H.RadarPulse - 1);
}

// Circulo lleno y liso, dibujado fila por fila con una textura blanca en el color actual
// del Canvas. El punto del radar es un brillo que va de blanco a negro y, dibujado opaco,
// se ve con un aro oscuro; asi queda un circulo del color pedido que lo tapa.
static function DrawDisc(Canvas C, float CenterX, float CenterY, float Radius)
{
    local float DY, HalfW;

    for (DY = -Radius; DY <= Radius; DY += 1.0)
    {
        HalfW = Sqrt(FMax(0.0, Radius * Radius - DY * DY));
        if (HalfW < 0.5)
            continue;
        C.SetPos(CenterX - HalfW, CenterY + DY);
        C.DrawTile(Texture'Engine.WhiteTexture', 2.0 * HalfW, 1.0, 0, 0, 4, 4);
    }
}

// True solo en los cuadros en los que el propio radar se dibujo
static function bool RadarDrawnThisFrame(HUDInvasion H)
{
    return H != None && H.LastDrawRadar == H.Level.TimeSeconds;
}
