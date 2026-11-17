class CthulhuFlameEffect extends xEmitter;

var Pawn BossOwner;
var int AttachmentSlot; // 0 = Ala Izq, 1 = Ala Der, 2 = Pie Izq, 3 = Pie Der
var bool bAttachmentSettingsApplied;
var int ConfiguredAttachmentSlot;

replication
{
    reliable if (Role == ROLE_Authority)
        BossOwner, AttachmentSlot;
}

function InitForBoss(Pawn InBoss, int InSlot)
{
    BossOwner = InBoss;
    AttachmentSlot = InSlot;
    ConfigureAttachment();
    UpdateAttachmentLocation();
}

simulated function ConfigureAttachment()
{
    if (bAttachmentSettingsApplied && ConfiguredAttachmentSlot == AttachmentSlot)
        return;

    // Configura particulas localmente en cada cliente cuando llega el slot replicado.
    if (AttachmentSlot == 0 || AttachmentSlot == 1)
    {
        mSizeRange[0] = 18.0;
        mSizeRange[1] = 27.0;
        mRegenRange[0] = 135.0;
        mRegenRange[1] = 135.0;
    }
    else
    {
        mSizeRange[0] = 12.0;
        mSizeRange[1] = 19.0;
        mRegenRange[0] = 95.0;
        mRegenRange[1] = 95.0;
    }
    bAttachmentSettingsApplied = true;
    ConfiguredAttachmentSlot = AttachmentSlot;
}

simulated function UpdateAttachmentLocation()
{
    local vector X, Y, Z, TargetLoc;
    local float FlapZ, FlapY;

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
    if (AttachmentSlot == 0 || AttachmentSlot == 1)
    {
        if (BossOwner.Physics == PHYS_Flying)
        {
            FlapZ = Sin(Level.TimeSeconds * 10.0) * 14.0;
            FlapY = Cos(Level.TimeSeconds * 10.0) * 6.0;
        }
        if (AttachmentSlot == 0)
            TargetLoc = BossOwner.Location - (20.0 * X) - ((52.0 + FlapY) * Y) + vect(0, 0, 1) * (72.0 + FlapZ);
        else
            TargetLoc = BossOwner.Location - (20.0 * X) + ((52.0 + FlapY) * Y) + vect(0, 0, 1) * (72.0 + FlapZ);
    }
    else if (AttachmentSlot == 2)
        TargetLoc = BossOwner.Location - (19.0 * Y) + vect(0, 0, -50.0);
    else
        TargetLoc = BossOwner.Location + (19.0 * Y) + vect(0, 0, -50.0);

    SetLocation(TargetLoc);
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (!bAttachmentSettingsApplied || ConfiguredAttachmentSlot != AttachmentSlot)
        ConfigureAttachment();
    UpdateAttachmentLocation();
}

defaultproperties
{
    ConfiguredAttachmentSlot=-1
    mStartParticles=0
    mMaxParticles=150
    mLifeRange(0)=0.3
    mLifeRange(1)=0.48
    mRegenRange(0)=135.0
    mRegenRange(1)=135.0
    mPosDev=(X=4.0,Y=4.0,Z=4.0)
    mSpeedRange(0)=0.0
    mSpeedRange(1)=8.0
    mMassRange(0)=-1.1
    mMassRange(1)=-1.4
    mSizeRange(0)=18.0
    mSizeRange(1)=28.0
    mGrowthRate=-14.0
    mAttenKa=0.45
    mNumTileColumns=4
    mNumTileRows=4
    bNetTemporary=False
    bAlwaysRelevant=True
    RemoteRole=ROLE_SimulatedProxy
    NetUpdateFrequency=30.0
    Skins(0)=Texture'EmitterTextures.MultiFrame.LargeFlames'
    Style=STY_Translucent
}
