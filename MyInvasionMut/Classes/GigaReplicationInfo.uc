// Llega a todos los clientes y, si el servidor tiene activada la opcion de cortar o de
// encadenar combos, le agrega GigaComboInteraction al jugador local.
class GigaReplicationInfo extends ReplicationInfo;

var bool bComboKeys;   // cortar o encadenar combos con las teclas
var bool bInteractionAdded;

replication
{
    reliable if (Role == ROLE_Authority)
        bComboKeys;
}

simulated function Tick(float DeltaTime)
{
    local PlayerController PC;

    if (Level.NetMode == NM_DedicatedServer || bInteractionAdded)
    {
        Disable('Tick');
        return;
    }
    if (!bComboKeys)
        return;

    PC = Level.GetLocalPlayerController();
    if (PC != None && PC.Player != None && PC.Player.InteractionMaster != None)
    {
        PC.Player.InteractionMaster.AddInteraction("MyInvasionMut.GigaComboInteraction", PC.Player);
        bInteractionAdded = true;
    }
}

defaultproperties
{
    bAlwaysRelevant=True
    RemoteRole=ROLE_SimulatedProxy
    NetUpdateFrequency=1.0
}
