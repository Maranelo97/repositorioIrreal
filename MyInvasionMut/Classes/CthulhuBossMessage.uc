class CthulhuBossMessage extends LocalMessage;

// Switch: 0 = aparece, 1 = entra en furia, 2 = fue abatido (RelatedPRI_1 = companero revivido, si hubo)

var Font CustomBossFont;
var Sound IntroRoarSound;

static function ClientReceive(PlayerController P, optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
    local Actor SoundActor;
    local Sound EventSound, SecondarySound;
    local float ShakeDuration;

    Super.ClientReceive(P, Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject);
    if (P == None)
        return;

    // La muerte del jefe no tiene rugido ni sacudida
    if (Switch == 2)
        return;

    SoundActor = P.ViewTarget;
    if (SoundActor == None)
        SoundActor = P.Pawn;
    if (SoundActor == None)
        SoundActor = P;

    if (Switch == 0)
    {
        EventSound = default.IntroRoarSound;
        ShakeDuration = 2.0;
    }
    else
    {
        EventSound = class'Brute'.Default.ChallengeSound[0];
        SecondarySound = class'WarLord'.Default.ChallengeSound[0];
        ShakeDuration = 1.2;
    }

    if (EventSound != None)
        SoundActor.PlaySound(EventSound, SLOT_None, 2.0, false, 8000.0, 1.0, false);
    if (SecondarySound != None)
        SoundActor.PlaySound(SecondarySound, SLOT_Interact, 2.0, false, 8000.0, 1.0, false);

    if (P.Level != None)
        P.SetAmbientShake(P.Level.TimeSeconds, ShakeDuration, vect(32, 32, 44), 24.0, rot(2200, 2200, 2600), 20.0);
    P.StopViewShaking();
    P.ShakeView(vect(1100, 1100, 1100), vect(18000, 18000, 18000), 6.0, vect(38, 38, 48), vect(3600, 3600, 4200), 6.0);
}

static function string GetString(optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
    if (Switch == 2)
        return "EL REY CTHULHU FUE ABATIDO!";
    if (Switch == 1)
        return "EL REY CTHULHU HA ENTRADO EN FURIA";
    return "EL REY CTHULHU HA APARECIDO";
}

// Dibuja una linea centrada con sombra y devuelve su ancho
static function float DrawCenteredLine(Canvas C, string Text, float CenterY, byte R, byte G, byte B, byte Alpha, out float LineHeight)
{
    local float W, DrawX, DrawY;

    C.StrLen(Text, W, LineHeight);
    DrawX = (C.ClipX - W) * 0.5;
    DrawY = CenterY - (LineHeight * 0.5);
    C.SetDrawColor(0, 0, 0, Alpha);
    C.SetPos(DrawX + 2.0, DrawY + 2.0);
    C.DrawText(Text, false);
    C.SetDrawColor(R, G, B, Alpha);
    C.SetPos(DrawX, DrawY);
    C.DrawText(Text, false);
    return W;
}

static function RenderComplexMessage(Canvas C, out float XL, out float YL, optional string MessageString, optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
    local byte CurrentAlpha;
    local float CenterY, LineH, W;

    CurrentAlpha = C.DrawColor.A;
    if (default.CustomBossFont != None)
        C.Font = default.CustomBossFont;
    CenterY = C.ClipY * default.PosY;

    if (Switch == 2)
    {
        // Muerte del jefe: titulo en rojo y las recompensas debajo, una por linea
        XL = DrawCenteredLine(C, static.GetString(Switch), CenterY, 255, 0, 0, CurrentAlpha, LineH);
        YL = LineH;
        W = DrawCenteredLine(C, class'MutChatDokaBots'.static.FixAccents("Vida, escudo, munición y adrenalina al máximo"), CenterY + YL, 255, 255, 255, CurrentAlpha, LineH);
        XL = FMax(XL, W);
        YL += LineH;
        W = DrawCenteredLine(C, class'MutChatDokaBots'.static.FixAccents("¡y Double Damage hasta el final de la oleada!"), CenterY + YL, 255, 255, 255, CurrentAlpha, LineH);
        XL = FMax(XL, W);
        YL += LineH;
        if (RelatedPRI_1 != None)
        {
            W = DrawCenteredLine(C, RelatedPRI_1.PlayerName $ " ha vuelto a la batalla!", CenterY + YL, 255, 255, 255, CurrentAlpha, LineH);
            XL = FMax(XL, W);
            YL += LineH;
        }
        return;
    }

    if (MessageString == "")
        MessageString = static.GetString(Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject);
    XL = DrawCenteredLine(C, MessageString, CenterY, 255, 0, 0, CurrentAlpha, YL);
}

defaultproperties
{
    CustomBossFont=Font'UT2003Fonts.FontEurostile29'
    IntroRoarSound=Sound'SkaarjPack_rc.WarLord.laugh1WL'
    bComplexString=True
    bIsUnique=True
    bFadeMessage=True
    Lifetime=6
    DrawColor=(B=0,G=0,R=255,A=255)
    PosY=0.32
}
