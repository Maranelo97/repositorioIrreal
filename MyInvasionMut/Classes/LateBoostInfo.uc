// Maximos mas altos de Control de plagas en la maquina de cada jugador. El servidor ya sube el
// escudo y la adrenalina, pero ShieldStrengthMax y AdrenalineMax no se mandan por la red, y el
// HUD de cada jugador recorta lo que muestra a esos maximos (150 y 100). Este actor llega a todos
// con el factor y los sube tambien en cada computadora: en los pawns que se ven y en el
// controlador del jugador local.
class LateBoostInfo extends ReplicationInfo;

var float Factor;   // 2.0 = el doble

replication
{
    reliable if (Role == ROLE_Authority)
        Factor;
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
        SetTimer(0.5, true);
}

simulated function Timer()
{
    local PlayerController PC;
    local xPawn P;

    if (Factor <= 1.0)
        return;

    PC = Level.GetLocalPlayerController();
    if (PC != None)
        PC.AdrenalineMax = PC.default.AdrenalineMax * Factor;

    foreach DynamicActors(class'xPawn', P)
        P.ShieldStrengthMax = P.default.ShieldStrengthMax * Factor;
}

defaultproperties
{
    Factor=1.0
    bAlwaysRelevant=True
    RemoteRole=ROLE_SimulatedProxy
    NetUpdateFrequency=1.0
}
