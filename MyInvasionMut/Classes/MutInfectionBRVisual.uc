class MutInfectionBRVisual extends Actor;

defaultproperties
{
    LightType=LT_Pulse
    LightSaturation=255
    LightBrightness=96.0
    LightRadius=12.0
    DrawType=DT_StaticMesh
    StaticMesh=StaticMesh'XGame_rc.BombEffectMesh'
    bDynamicLight=True
    RemoteRole=ROLE_SimulatedProxy
    NetUpdateFrequency=20.0
    Skins(0)=Shader'XGameShaders.BRShaders.BombIconRS'
    Skins(1)=Shader'XGameShaders.BRShaders.BombIconRS'
    Skins(2)=Shader'XGameShaders.BRShaders.BombIconRS'
    bHardAttach=True
    bBlockZeroExtentTraces=False
    bBlockNonZeroExtentTraces=False
}
