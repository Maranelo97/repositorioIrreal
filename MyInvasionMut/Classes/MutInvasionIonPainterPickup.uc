class MutInvasionIonPainterPickup extends PainterPickup;

// El punto especial ignora 'Weapons Stay': si ya tenes el arma, tocarlo te da
// municion (UltimatesRules lo rechaza cuando la municion esta llena).
function SetWeaponStay()
{
    bWeaponStay = false;
}

// Si los bots no pueden recogerla, que tampoco la busquen
function float BotDesireability(Pawn P)
{
    if (!class'UltimatesRules'.static.BotsCanPickup() && P != None && Bot(P.Controller) != None)
        return 0;
    return Super.BotDesireability(P);
}

// Anota quien la recogio, para la opcion de recogerla una sola vez por oleada
function AnnouncePickup(Pawn Receiver)
{
    Super.AnnouncePickup(Receiver);
    class'UltimatesRules'.static.NotePickup(self, Receiver);
}

defaultproperties
{
    bInstantRespawn=True
    RespawnTime=0.05
    RespawnEffectTime=0.0
}
