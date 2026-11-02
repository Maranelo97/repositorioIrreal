class MutCuidenAFerRules extends GameRules;

var MutCuidenAFer FerMutator;

function bool OverridePickupQuery(Pawn Other, Pickup Item, out byte bAllowPickup)
{
    if (FerMutator != None && Other == FerMutator.FerPawn && Item != None
        && (Item.IsA('WeaponPickup') || Item.IsA('Ammo') || Item.IsA('AdrenalinePickup')))
    {
        bAllowPickup = 0;
        return true;
    }
    return Super.OverridePickupQuery(Other, Item, bAllowPickup);
}

function bool PreventDeath(Pawn Killed, Controller Killer, class<DamageType> DamageType, vector HitLocation)
{
    return Super.PreventDeath(Killed, Killer, DamageType, HitLocation);
}

function ScoreKill(Controller Killer, Controller Killed)
{
    // Primero dejamos que Invasion procese la muerte y sus vidas.
    if (NextGameRules != None)
        NextGameRules.ScoreKill(Killer, Killed);

    // Invasion llama este hook despues de marcar al jugador muerto.
    if (FerMutator != None && Killed != None
        && Killed == FerMutator.CurrentFerController)
        FerMutator.FerDied();
}




