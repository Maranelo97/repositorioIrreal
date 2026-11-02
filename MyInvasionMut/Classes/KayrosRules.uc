class KayrosRules extends GameRules;

var MutKayros KayrosMut;

function bool OverridePickupQuery(Pawn Other, Pickup item, out byte bAllowPickup)
{
    if (KayrosMut != None && Other != None && item != None)
    {
        KayrosMut.PreparePickupForPawn(Other, item);
    }

    if (NextGameRules != None)
    {
        return NextGameRules.OverridePickupQuery(Other, item, bAllowPickup);
    }

    return false;
}
