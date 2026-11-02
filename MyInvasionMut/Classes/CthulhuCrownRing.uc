class CthulhuCrownRing extends Actor;

var Pawn BossOwner;

replication
{
    reliable if (Role == ROLE_Authority)
        BossOwner;
}

simulated function UpdateCrownRingLocation()
{
    local vector X, Y, Z;

    if (BossOwner == None || BossOwner.bDeleteMe)
    {
        bHidden = true;
        if (Role == ROLE_Authority)
            Destroy();
        return;
    }

    if (Role == ROLE_Authority && (BossOwner.Health <= 0 || BossOwner.Tag == 'ChampionDead'))
    {
        Destroy();
        return;
    }

    bHidden = false;
    GetAxes(BossOwner.Rotation, X, Y, Z);
    SetLocation(BossOwner.Location + (8.0 * X) + vect(0, 0, 133.0));
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    UpdateCrownRingLocation();
}

defaultproperties
{
    DrawType=DT_StaticMesh
    StaticMesh=StaticMesh'XGame_rc.DomRing'
    bAlwaysRelevant=True
    Physics=PHYS_Rotating
    RemoteRole=ROLE_SimulatedProxy
    NetUpdateFrequency=30.0
    DrawScale=0.18
    DrawScale3D=(X=1.0,Y=1.0,Z=1.35)
    Skins(0)=Shader'XGameShaders.BRShaders.BombIconYS'
    Skins(1)=Shader'XGameShaders.BRShaders.BombIconYS'
    AmbientGlow=254
    bUnlit=True
    bBlockZeroExtentTraces=False
    bBlockNonZeroExtentTraces=False
    bFixedRotationDir=True
    RotationRate=(Pitch=0,Yaw=-28000,Roll=0)
}
