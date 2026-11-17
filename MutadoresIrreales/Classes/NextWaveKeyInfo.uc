// Llega a todos los clientes y le agrega NextWaveKeyInteraction al jugador local, para que la
// tecla H inicie la siguiente oleada (Control de plagas). El servidor decide si vale: solo el
// host o un admin, y solo durante la pausa.
class NextWaveKeyInfo extends ReplicationInfo;

var bool bInteractionAdded;

simulated function Tick(float DeltaTime)
{
    local PlayerController PC;

    if (Level.NetMode == NM_DedicatedServer || bInteractionAdded)
    {
        Disable('Tick');
        return;
    }

    PC = Level.GetLocalPlayerController();
    if (PC != None && PC.Player != None && PC.Player.InteractionMaster != None)
    {
        PC.Player.InteractionMaster.AddInteraction("MutadoresIrreales.NextWaveKeyInteraction", PC.Player);
        bInteractionAdded = true;
    }
}

defaultproperties
{
    bAlwaysRelevant=True
    RemoteRole=ROLE_SimulatedProxy
    NetUpdateFrequency=1.0
}
