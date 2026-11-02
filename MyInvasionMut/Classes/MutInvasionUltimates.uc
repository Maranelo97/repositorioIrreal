class MutInvasionUltimates extends Mutator;

var xWeaponBase UltimateBase;
var int CurrentWaveNum;
var bool bInitialized;

function PostBeginPlay()
{
    Super.PostBeginPlay();
    CurrentWaveNum = -1;
    if (Invasion(Level.Game) != None)
        SetTimer(1.0, false);
}

function bool IsSpecialWeapon(class<Weapon> WeaponClass)
{
    return WeaponClass == class'XWeapons.Redeemer'
        || WeaponClass == class'XWeapons.Painter'
        || WeaponClass == class'OnslaughtFull.ONSPainter'
        || WeaponClass == class'XWeapons.SniperRifle';
}

function xWeaponBase PickRandomWeaponBase(bool bRotationOnly)
{
    local xWeaponBase Candidate, Chosen;
    local int EligibleCount;

    foreach AllActors(class'XGame.xWeaponBase', Candidate)
    {
        if (Candidate.WeaponType == None)
            continue;

        if (bRotationOnly)
        {
            if (!IsSpecialWeapon(Candidate.WeaponType))
                continue;
        }
        else if (Candidate.WeaponType == class'XWeapons.LinkGun'
            || IsSpecialWeapon(Candidate.WeaponType))
            continue;

        EligibleCount++;
        if (Rand(EligibleCount) == 0)
            Chosen = Candidate;
    }
    return Chosen;
}

function RemoveBasePickup(xWeaponBase Base)
{
    local Pickup OldPickup;
    if (Base == None)
        return;
    OldPickup = Base.myPickUp;
    Base.myPickUp = None;
    if (OldPickup != None)
        OldPickup.Destroy();
}

function DisableOtherSpecialBases()
{
    local xWeaponBase Candidate;
    foreach AllActors(class'XGame.xWeaponBase', Candidate)
    {
        if (Candidate != UltimateBase && IsSpecialWeapon(Candidate.WeaponType))
        {
            RemoveBasePickup(Candidate);
            Candidate.WeaponType = None;
            Candidate.PowerUp = None;
        }
    }
}

function SetUltimate(int WeaponIndex)
{
    if (UltimateBase == None)
        return;

    RemoveBasePickup(UltimateBase);
    switch (WeaponIndex)
    {
        case 0:
            UltimateBase.WeaponType = class'XWeapons.Redeemer';
            UltimateBase.PowerUp = class'MutInvasionRedeemerPickup';
            break;
        case 1:
            UltimateBase.WeaponType = class'OnslaughtFull.ONSPainter';
            UltimateBase.PowerUp = class'MutInvasionTargetPainterPickup';
            break;
        case 2:
            UltimateBase.WeaponType = class'XWeapons.Painter';
            UltimateBase.PowerUp = class'MutInvasionIonPainterPickup';
            break;
        default:
            UltimateBase.WeaponType = class'XWeapons.SniperRifle';
            UltimateBase.PowerUp = class'MutInvasionLightningGunPickup';
            break;
    }
    UltimateBase.SpawnPickup();
}

function Timer()
{
    local Invasion InvGame;

    InvGame = Invasion(Level.Game);
    if (InvGame == None)
        return;

    if (!bInitialized)
    {
        // Si ya hay una ulti o pesada en el mapa, conservar ese punto; si no, elegir un arma normal.
        UltimateBase = PickRandomWeaponBase(true);
        if (UltimateBase == None)
            UltimateBase = PickRandomWeaponBase(false);

        if (UltimateBase == None)
        {
            SetTimer(1.0, false);
            return;
        }

        DisableOtherSpecialBases();
        SetUltimate(Rand(4));
        bInitialized = true;
        SetTimer(1.0, true);
        return;
    }

    // Cada ronda elige al azar entre las cuatro; se permite repetir la ronda anterior.
    if (InvGame.bWaveInProgress && InvGame.WaveNum != CurrentWaveNum)
    {
        if (CurrentWaveNum >= 0)
            SetUltimate(Rand(4));
        CurrentWaveNum = InvGame.WaveNum;
    }
}

defaultproperties
{
    GroupName="InvasionUltimates"
    FriendlyName="Invasion: Armas ultimas"
    Description="Un punto de arma ulti/pesada rota al azar entre Redeemer, Target Painter, Ion Painter y Lightning Gun por ronda. Respawn instantaneo y las armas recogidas permanecen en el inventario del jugador."
}
