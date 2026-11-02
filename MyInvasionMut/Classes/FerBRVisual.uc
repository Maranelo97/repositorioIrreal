class FerBRVisual extends Actor;

defaultproperties
{
    DrawType=DT_StaticMesh
    StaticMesh=StaticMesh'XGame_rc.BombEffectMesh'
    RemoteRole=ROLE_SimulatedProxy
    NetUpdateFrequency=20.0
    Skins(0)=Shader'XGameShaders.BRShaders.BombIconRS'
    Skins(1)=Shader'XGameShaders.BRShaders.BombIconRS'
    Skins(2)=Shader'XGameShaders.BRShaders.BombIconRS'
    bHardAttach=True
    bBlockZeroExtentTraces=False
    bBlockNonZeroExtentTraces=False
}
