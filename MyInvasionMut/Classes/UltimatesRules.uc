class UltimatesRules extends GameRules;

// Como el punto especial ignora 'Weapons Stay', quien ya tiene el arma puede
// volver a tocarlo para recargar. Si la municion ya esta llena se rechaza la
// recogida, asi no se repite sin parar mientras alguien esta parado encima.
function bool OverridePickupQuery(Pawn Other, Pickup item, out byte bAllowPickup)
{
    local Weapon W;

    if (Other != None && item != None && IsUltimatePickup(item))
    {
        W = Weapon(Other.FindInventoryType(item.InventoryType));
        if (W != None && W.AmmoMaxed(0))
        {
            bAllowPickup = 0;
            return true;
        }
    }

    if (NextGameRules != None)
    {
        return NextGameRules.OverridePickupQuery(Other, item, bAllowPickup);
    }

    return false;
}

function bool IsUltimatePickup(Pickup item)
{
    return MutInvasionRedeemerPickup(item) != None
        || MutInvasionIonPainterPickup(item) != None
        || MutInvasionLightningGunPickup(item) != None;
}
