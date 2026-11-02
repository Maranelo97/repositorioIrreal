class MutInstantRespawn extends Mutator;

function PostBeginPlay()
{
    local Pickup P;
    local xPickUpBase B;

    Super.PostBeginPlay();

    ForEach AllActors(class'xPickUpBase', B)
        B.bDelayedSpawn = false;

    ForEach AllActors(class'Pickup', P)
    {
        if (!P.bDropped)
        {
            P.bInstantRespawn = true;
            P.RespawnTime = 0.05;
            P.RespawnEffectTime = 0.0;
            if (P.IsInState('WaitingForMatch'))
                P.GotoState('Pickup');
        }
    }
}

function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
    local Pickup P;
    local xPickUpBase B;

    B = xPickUpBase(Other);
    if (B != None)
        B.bDelayedSpawn = false;

    P = Pickup(Other);
    if (P != None && !P.bDropped)
    {
        P.bInstantRespawn = true;
        P.RespawnTime = 0.05;
        P.RespawnEffectTime = 0.0;
    }

    return true;
}

defaultproperties
{
    GroupName="InstantRespawn"
    FriendlyName="Es todo muy irreal"
    Description="Elimina el cooldown de los items del piso (balas, salud, escudos y armas) para que se regeneren al instante. No afecta a items que los jugadores dejaron caer."
}
