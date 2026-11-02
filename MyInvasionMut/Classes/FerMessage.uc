class FerMessage extends LocalMessage;

var Font CustomFerFont;

static function string GetString(optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
    if (Switch == 1)
        return "NO CUIDARON A FER";
    if (RelatedPRI_1 != None)
        return RelatedPRI_1.PlayerName $ " AHORA ES FER";
    return "AHORA HAY UN NUEVO FER";
}

static function RenderComplexMessage(Canvas C, out float XL, out float YL, optional string MessageString, optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
    local byte CurrentAlpha;
    local float DrawX, DrawY;

    if (MessageString == "")
        MessageString = static.GetString(Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject);
    CurrentAlpha = C.DrawColor.A;
    if (default.CustomFerFont != None)
        C.Font = default.CustomFerFont;
    C.StrLen(MessageString, XL, YL);
    DrawX = (C.ClipX - XL) * 0.5;
    DrawY = (C.ClipY * default.PosY) - (YL * 0.5);
    C.SetDrawColor(0, 0, 0, CurrentAlpha);
    C.SetPos(DrawX + 2.0, DrawY + 2.0);
    C.DrawText(MessageString, false);
    if (Switch == 1)
        C.SetDrawColor(255, 255, 255, CurrentAlpha);
    else
        C.SetDrawColor(0, 255, 0, CurrentAlpha);
    C.SetPos(DrawX, DrawY);
    C.DrawText(MessageString, false);
}

defaultproperties
{
    CustomFerFont=Font'MyInvasionMut.CthulhuFont48'
    bComplexString=True
    bIsUnique=True
    bFadeMessage=True
    Lifetime=6
    DrawColor=(B=0,G=255,R=0,A=255)
    PosY=0.32
}
