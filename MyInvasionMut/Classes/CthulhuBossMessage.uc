class CthulhuBossMessage extends LocalMessage;

#exec new TrueTypeFontFactory PACKAGE="MyInvasionMut" Name="CthulhuFont48" FontName="Unreal Tournament" Height=48 AntiAlias=1

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
    if (Switch == 1)
        return "EL REY CTHULHU HA ENTRADO EN FURIA";
    return "EL REY CTHULHU HA APARECIDO";
}

static function RenderComplexMessage(Canvas C, out float XL, out float YL, optional string MessageString, optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
    local byte CurrentAlpha;
    local float DrawX, DrawY;

    if (MessageString == "")
        MessageString = static.GetString(Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject);
    CurrentAlpha = C.DrawColor.A;
    if (default.CustomBossFont != None)
        C.Font = default.CustomBossFont;
    C.StrLen(MessageString, XL, YL);
    DrawX = (C.ClipX - XL) * 0.5;
    DrawY = (C.ClipY * default.PosY) - (YL * 0.5);
    C.SetDrawColor(0, 0, 0, CurrentAlpha);
    C.SetPos(DrawX + 2.0, DrawY + 2.0);
    C.DrawText(MessageString, false);
    C.SetDrawColor(255, 0, 0, CurrentAlpha);
    C.SetPos(DrawX, DrawY);
    C.DrawText(MessageString, false);
}

defaultproperties
{
    CustomBossFont=Font'MyInvasionMut.CthulhuFont48'
    IntroRoarSound=Sound'MyInvasionMut.Sounds.CthulhuIntroRoar'
    bComplexString=True
    bIsUnique=True
    bFadeMessage=True
    Lifetime=6
    DrawColor=(B=0,G=0,R=255,A=255)
    PosY=0.32
}
