// Redeemer de GIGACHADrenalina: cada disparo cuesta adrenalina (ver GigaAdrenalina)
class GigaRedeemer extends Redeemer;

var int ShotCost;   // adrenalina por disparo; la decide el servidor

replication
{
    reliable if (Role == ROLE_Authority && bNetOwner)
        ShotCost;
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Role == ROLE_Authority)
        ShotCost = Clamp(class'MutGigachadrenalina'.default.RedeemerCost, 0, 100);
}

// Al agarrar el arma (si no la tenias) se llena la adrenalina, segun la opcion del mutador
function GiveTo(Pawn Other, optional Pickup Pickup)
{
    local Weapon W;
    local bool bNew;

    if (Other != None)
    {
        W = Weapon(Other.FindInventoryType(Class));
        bNew = (W == None || W.Class != Class);
    }
    Super.GiveTo(Other, Pickup);
    if (bNew && Pickup != None)
        class'GigaAdrenalina'.static.FillOnPickup(Other);
}

simulated function int AmmoAmount(int Mode)
{
    return class'GigaAdrenalina'.static.Shots(self, ShotCost);
}

simulated function bool HasAmmo()
{
    return AmmoAmount(0) > 0;
}

simulated function bool ConsumeAmmo(int Mode, float Load, optional bool bAmountNeededIsMax)
{
    return class'GigaAdrenalina'.static.Spend(self, ShotCost, Load);
}

// No hay municion para recargar: volver a agarrar el arma no da nada
simulated function bool AmmoMaxed(int Mode)
{
    return true;
}

simulated function GetAmmoCount(out float MaxAmmoPrimary, out float CurAmmoPrimary)
{
    MaxAmmoPrimary = class'GigaAdrenalina'.static.MaxShots(ShotCost);
    CurAmmoPrimary = AmmoAmount(0);
}

simulated function float AmmoStatus(optional int Mode)
{
    return FMin(1.0, float(AmmoAmount(0)) / float(class'GigaAdrenalina'.static.MaxShots(ShotCost)));
}

defaultproperties
{
    ShotCost=50
}
