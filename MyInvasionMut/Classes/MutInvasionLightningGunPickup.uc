class MutInvasionLightningGunPickup extends SniperRiflePickup;

// El punto especial ignora 'Weapons Stay': si ya tenes el arma, tocarlo te da
// municion (UltimatesRules lo rechaza cuando la municion esta llena).
function SetWeaponStay()
{
    bWeaponStay = false;
}

defaultproperties
{
    bInstantRespawn=True
    RespawnTime=0.05
    RespawnEffectTime=0.0
}
