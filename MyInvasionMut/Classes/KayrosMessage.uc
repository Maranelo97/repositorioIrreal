class KayrosMessage extends LocalMessage;

var Font CustomKayrosFont;

static function string GetString(
    optional int Switch,
    optional PlayerReplicationInfo RelatedPRI_1,
    optional PlayerReplicationInfo RelatedPRI_2,
    optional Object OptionalObject
)
{
    if (Switch == 1)
    {
        // Chr(201) = E con tilde (los .uc se guardan en UTF-8 y el compilador lee Latin-1)
        return "TEN" $ Chr(201) $ "S MUCHO KAYROS";
    }
    return "TEN" $ Chr(201) $ "S POCO KAYROS";
}

static function RenderComplexMessage(
    Canvas C,
    out float XL,
    out float YL,
    optional string MessageString,
    optional int Switch,
    optional PlayerReplicationInfo RelatedPRI_1,
    optional PlayerReplicationInfo RelatedPRI_2,
    optional Object OptionalObject
)
{
    local byte CurrentAlpha;
    local float DrawX, DrawY;

    if (MessageString == "")
    {
        MessageString = static.GetString(Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject);
    }

    CurrentAlpha = C.DrawColor.A;

    if (default.CustomKayrosFont != None)
    {
        C.Font = default.CustomKayrosFont;
    }

    C.StrLen(MessageString, XL, YL);
    DrawX = (C.ClipX - XL) * 0.5;
    DrawY = (C.ClipY * default.PosY) - (YL * 0.5);

    // Sombra negra para que resalte perfectamente sobre cualquier fondo
    C.SetDrawColor(0, 0, 0, CurrentAlpha);
    C.SetPos(DrawX + 2.0, DrawY + 2.0);
    C.DrawText(MessageString, false);

    if (Switch == 1)
    {
        // Mucho Kayros (Buff +20%): Verde esmeralda / dorado brillante
        C.SetDrawColor(60, 255, 90, CurrentAlpha);
    }
    else
    {
        // Poco Kayros (Debuff -20%): Violeta / purpura intenso
        C.SetDrawColor(215, 75, 255, CurrentAlpha);
    }

    C.SetPos(DrawX, DrawY);
    C.DrawText(MessageString, false);
}

defaultproperties
{
    CustomKayrosFont=Font'UT2003Fonts.FontEurostile29'
    bComplexString=True
    bIsUnique=True
    bFadeMessage=True
    Lifetime=6
    DrawColor=(B=90,G=255,R=60,A=255)
    PosY=0.44
}
