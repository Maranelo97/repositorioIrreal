class CthulhuBossVisual extends Actor;

var Pawn BossOwner;
var bool bEnraged;

replication
{
    reliable if (Role == ROLE_Authority)
        BossOwner, bEnraged;
}

function InitForBoss(Pawn InBoss)
{
    BossOwner = InBoss;
    bEnraged = false;
    NetUpdateTime = Level.TimeSeconds - 1;
}

function SetEnraged(bool bNewEnraged)
{
    if (Role == ROLE_Authority && bEnraged != bNewEnraged)
    {
        bEnraged = bNewEnraged;
        NetUpdateTime = Level.TimeSeconds - 1;
    }
}

simulated function ApplyBossVisual()
{
    local Monster BossMonster;
    local Material BossMat;

    if (BossOwner == None || BossOwner.bDeleteMe)
    {
        return;
    }

    if (Role == ROLE_Authority && (BossOwner.Health <= 0 || BossOwner.Tag == 'ChampionDead'))
    {
        return;
    }

    if (bEnraged)
    {
        BossOwner.AmbientGlow = 230;
        BossMat = Material'XGameShaders.TransPlayerCellRed';
        BossOwner.LightType = LT_Pulse;
        BossOwner.LightHue = 0;
        BossOwner.LightSaturation = 32;
        BossOwner.LightBrightness = 255.0;
        BossOwner.LightRadius = 12.0;
    }
    else
    {
        BossOwner.AmbientGlow = 80;
        BossMonster = Monster(BossOwner);
        if (BossMonster != None)
        {
            BossMat = BossMonster.UDamageWeaponMaterial;
        }
        if (BossMat == None)
        {
            BossMat = Material'XGameShaders.PlayerShaders.WeaponUDamageShader';
        }
        BossOwner.LightType = LT_Steady;
        BossOwner.LightHue = 210;
        BossOwner.LightSaturation = 64;
        BossOwner.LightBrightness = 220.0;
        BossOwner.LightRadius = 8.0;
    }

    BossOwner.HighDetailOverlay = BossMat;
    if (BossOwner.OverlayMaterial != BossMat || BossOwner.ClientOverlayCounter < 5.0)
    {
        BossOwner.SetOverlayMaterial(BossMat, 30.0, true);
    }

    BossOwner.bDynamicLight = true;
    BossOwner.LightEffect = LE_NonIncidence;
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);

    // A missing client reference can be temporary during actor replication.
    // Only the authority decides when this helper has finished its lifetime.
    if (BossOwner == None || BossOwner.bDeleteMe)
    {
        if (Role == ROLE_Authority)
        {
            Destroy();
        }
        return;
    }

    if (Role == ROLE_Authority && (BossOwner.Health <= 0 || BossOwner.Tag == 'ChampionDead'))
    {
        Destroy();
        return;
    }

    // Reassert all local appearance properties after visibility/network updates.
    // ApplyBossVisual refreshes the timed overlay only when it needs renewal.
    ApplyBossVisual();
}

defaultproperties
{
    DrawType=DT_None
    bAlwaysRelevant=True
    RemoteRole=ROLE_SimulatedProxy
    NetUpdateFrequency=10.0
}
