// Llega a todos los clientes con la configuracion del servidor y le agrega
// RadarMejoradoOverlay al HUD del jugador local. Si el HUD cambia (por ejemplo al
// reconectar), vuelve a agregarlo.
class RadarMejoradoReplicationInfo extends ReplicationInfo;

var bool bColoredDots, bShowHeightLines, bShowWave;
var byte FinalWave;   // Invasion no se la manda a los jugadores; la oleada actual si
var float MinHeightDiff;
var RadarMejoradoOverlay Overlay;

replication
{
    reliable if (Role == ROLE_Authority)
        bColoredDots, bShowHeightLines, MinHeightDiff, bShowWave, FinalWave;
}

simulated function Tick(float DeltaTime)
{
    local PlayerController PC;

    if (Level.NetMode == NM_DedicatedServer)
    {
        Disable('Tick');
        return;
    }

    PC = Level.GetLocalPlayerController();
    if (PC == None || PC.myHUD == None)
        return;

    if (Overlay != None && !Overlay.bDeleteMe && Overlay.Owner == PC.myHUD)
        return;

    if (Overlay != None)
        Overlay.Destroy();

    Overlay = Spawn(class'RadarMejoradoOverlay', PC.myHUD);
    if (Overlay != None)
    {
        Overlay.Settings = self;
        PC.myHUD.AddHudOverlay(Overlay);
    }
}

simulated function Destroyed()
{
    if (Overlay != None)
        Overlay.Destroy();
    Super.Destroyed();
}

defaultproperties
{
    bColoredDots=True
    bShowHeightLines=True
    bShowWave=True
    MinHeightDiff=200.0
    bAlwaysRelevant=True
    RemoteRole=ROLE_SimulatedProxy
    NetUpdateFrequency=1.0
}
