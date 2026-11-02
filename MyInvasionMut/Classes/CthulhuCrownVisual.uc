class CthulhuCrownVisual extends Actor;

var Pawn BossOwner;
var CthulhuCrownRing CrownRing;

replication
{
    reliable if (Role == ROLE_Authority)
        BossOwner;
}

function InitForBoss(Pawn InBoss)
{
    BossOwner = InBoss;
    UpdateCrownLocation();

    if (CrownRing == None && BossOwner != None)
    {
        CrownRing = Spawn(class'CthulhuCrownRing', self,, Location, rot(0, 0, 0));
        if (CrownRing != None)
        {
            CrownRing.BossOwner = BossOwner;
            CrownRing.UpdateCrownRingLocation();
        }
    }
}

simulated function Destroyed()
{
    if (CrownRing != None)
    {
        CrownRing.Destroy();
        CrownRing = None;
    }
    Super.Destroyed();
}

simulated function UpdateCrownLocation()
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
    SetLocation(BossOwner.Location + (8.0 * X) + vect(0, 0, 138.0));
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    UpdateCrownLocation();
}

defaultproperties
{
    LightType=LT_Steady
    LightEffect=LE_NonIncidence
    LightHue=42
    LightSaturation=32
    LightBrightness=220.0
    LightRadius=10.0
    DrawType=DT_StaticMesh
    StaticMesh=StaticMesh'XGame_rc.BombEffectMesh'
    bDynamicLight=True
    bAlwaysRelevant=True
    Physics=PHYS_Rotating
    RemoteRole=ROLE_SimulatedProxy
    NetUpdateFrequency=30.0
    DrawScale=0.58
    DrawScale3D=(X=1.1,Y=1.1,Z=0.48)
    Skins(0)=Shader'XGameShaders.BRShaders.BombIconYS'
    Skins(1)=Shader'XGameShaders.BRShaders.BombIconYS'
    Skins(2)=Shader'XGameShaders.BRShaders.BombIconYS'
    AmbientGlow=254
    bUnlit=True
    bBlockZeroExtentTraces=False
    bBlockNonZeroExtentTraces=False
    bFixedRotationDir=True
    RotationRate=(Pitch=0,Yaw=28000,Roll=0)
}
