class MutMarianoskyRage extends Mutator;

var float ChampionChance;
var int CurrentWaveNum;
var bool bWaveHasChampion;
var bool bChampionSpawnedThisWave;
var bool bChampionEnraged;
var int EnrageTickCounter;
var int TargetMonsterIndex;
var CthulhuFlameEffect BossFlames[4];
var CthulhuCrownVisual BossCrown;
var CthulhuBossVisual BossVisual;

function PostBeginPlay()
{
    local MarianoskyRageRules GR;

    Super.PostBeginPlay();

    GR = Spawn(class'MarianoskyRageRules');
    if (Level.Game != None && GR != None)
    {
        if (Level.Game.GameRulesModifiers == None)
        {
            Level.Game.GameRulesModifiers = GR;
        }
        else
        {
            Level.Game.GameRulesModifiers.AddGameRules(GR);
        }
    }

    if (Level != None)
    {
        Level.AddPrecacheMaterial(Material'XGameShaders.PlayerShaders.WeaponUDamageShader');
        Level.AddPrecacheMaterial(Material'XGameShaders.TransPlayerCellRed');
        Level.AddPrecacheMaterial(Shader'XGameShaders.BRShaders.BombIconYS');
        Level.AddPrecacheMaterial(Texture'EmitterTextures.MultiFrame.LargeFlames');
        Level.AddPrecacheStaticMesh(StaticMesh'E_Pickups.Udamage');
        Level.AddPrecacheStaticMesh(StaticMesh'XGame_RC.BombEffectMesh');
        Level.AddPrecacheStaticMesh(StaticMesh'XGame_rc.DomRing');
    }

    SetTimer(0.25, true);
}

function int CountActiveHumanPlayers()
{
    local Controller C;
    local int HumanCount;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        if (PlayerController(C) != None && C.PlayerReplicationInfo != None && !C.PlayerReplicationInfo.bOnlySpectator)
        {
            HumanCount++;
        }
    }

    return HumanCount;
}


function CleanupBossAttachments()
{
    local int i;

    for (i = 0; i < 4; i++)
    {
        if (BossFlames[i] != None)
        {
            BossFlames[i].Destroy();
            BossFlames[i] = None;
        }
    }

    if (BossCrown != None)
    {
        BossCrown.Destroy();
        BossCrown = None;
    }

    if (BossVisual != None)
    {
        BossVisual.Destroy();
        BossVisual = None;
    }
}

function EnsureBossAttachments(Monster M)
{
    local int i;

    if (M == None || M.Health <= 0)
    {
        return;
    }

    // 4 efectos permanentes de llamas: 0 = Ala Izq, 1 = Ala Der, 2 = Pie Izq, 3 = Pie Der
    for (i = 0; i < 4; i++)
    {
        if (BossFlames[i] == None || BossFlames[i].bDeleteMe || BossFlames[i].BossOwner != M)
        {
            if (BossFlames[i] != None && !BossFlames[i].bDeleteMe)
            {
                BossFlames[i].Destroy();
            }
            BossFlames[i] = Spawn(class'CthulhuFlameEffect', self,, M.Location, M.Rotation);
            if (BossFlames[i] != None)
            {
                BossFlames[i].InitForBoss(M, i);
            }
        }
    }

    // Corona brillante giratoria flotando sobre su cabeza
    if (BossCrown == None || BossCrown.bDeleteMe || BossCrown.BossOwner != M)
    {
        if (BossCrown != None && !BossCrown.bDeleteMe)
        {
            BossCrown.Destroy();
        }
        BossCrown = Spawn(class'CthulhuCrownVisual', self,, M.Location + vect(0, 0, 138.0), rot(0, 0, 0));
        if (BossCrown != None)
        {
            BossCrown.InitForBoss(M);
        }
    }

    // Skin/overlay changes are local-only actor properties. This replicated
    // helper reapplies them on every client after the boss and its state arrive.
    if (BossVisual == None || BossVisual.bDeleteMe || BossVisual.BossOwner != M)
    {
        if (BossVisual != None && !BossVisual.bDeleteMe)
        {
            BossVisual.Destroy();
        }
        BossVisual = Spawn(class'CthulhuBossVisual', self,, M.Location, M.Rotation);
        if (BossVisual != None)
        {
            BossVisual.InitForBoss(M);
            if (bChampionEnraged)
            {
                BossVisual.SetEnraged(true);
            }
        }
    }
}

function ApplyUDamageVisual(Monster M)
{
    local Material UDamageMat;

    if (M == None || M.Health <= 0)
    {
        return;
    }

    // Brillo violeta sobre la piel original del WarLord en estado normal
    M.AmbientGlow = 80;

    UDamageMat = M.UDamageWeaponMaterial;
    if (UDamageMat == None)
    {
        UDamageMat = Material'XGameShaders.PlayerShaders.WeaponUDamageShader';
    }

    // Efecto visual del Double Damage sobre el modelo 3D (sin activar el doble dano real)
    M.HighDetailOverlay = UDamageMat;
    if (M.OverlayMaterial != UDamageMat || M.ClientOverlayCounter < 5.0)
    {
        M.SetOverlayMaterial(UDamageMat, 30.0, true);
    }

    M.bDynamicLight = true;
    M.LightType = LT_Steady;
    M.LightEffect = LE_NonIncidence;
    M.LightHue = 210;
    M.LightSaturation = 64;
    M.LightBrightness = 220.0;
    M.LightRadius = 8.0;
}

function ApplyEnrageVisual(Monster M)
{
    local Material EnrageMat;

    if (M == None || M.Health <= 0)
    {
        return;
    }

    // Brillo rojo incandescente sobre la piel original al entrar en Furia (<= 35% HP)
    M.AmbientGlow = 230;

    EnrageMat = Material'XGameShaders.TransPlayerCellRed';

    // Destello y aura roja intensa durante la fase de furia (Enrage)
    M.HighDetailOverlay = EnrageMat;
    if (M.OverlayMaterial != EnrageMat || M.ClientOverlayCounter < 5.0)
    {
        M.SetOverlayMaterial(EnrageMat, 30.0, true);
    }

    M.bDynamicLight = true;
    M.LightType = LT_Pulse;
    M.LightEffect = LE_NonIncidence;
    M.LightHue = 0;
    M.LightSaturation = 32;
    M.LightBrightness = 255.0;
    M.LightRadius = 12.0;
}

function ApplyStrongShakePulseToAllPlayers(float AmbientDuration)
{
    local Controller C;
    local PlayerController PC;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        PC = PlayerController(C);
        if (PC != None)
        {
            if (AmbientDuration > 0.0)
            {
                PC.SetAmbientShake(Level.TimeSeconds, AmbientDuration, vect(32, 32, 44), 24.0, rot(2200, 2200, 2600), 20.0);
            }
            PC.StopViewShaking();
            PC.ShakeView(vect(1100, 1100, 1100), vect(18000, 18000, 18000), 6.0, vect(38, 38, 48), vect(3600, 3600, 4200), 6.0);
        }
    }
}

function StopShakeOnAllPlayers()
{
    local Controller C;
    local PlayerController PC;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        PC = PlayerController(C);
        if (PC != None)
        {
            PC.StopViewShaking();
        }
    }
}

function BroadcastBossEvent(int EventType)
{
    if (Level != None && Level.Game != None)
        Level.Game.BroadcastLocalizedMessage(class'CthulhuBossMessage', EventType);
}

function TriggerEnrage(Monster M)
{
    if (M == None || M.Health <= 0 || bChampionEnraged)
    {
        return;
    }

    bChampionEnraged = true;
    EnrageTickCounter = 0;

    // En furia prioriza ataques de cohetes y aumenta moderadamente su velocidad
    M.bMeleeFighter = false;
    M.GroundSpeed = M.Default.GroundSpeed * 1.35;
    M.AirSpeed = M.Default.AirSpeed * 1.35;
    M.WaterSpeed = M.Default.WaterSpeed * 1.35;
    M.AccelRate = M.Default.AccelRate * 1.35;

    if (BossVisual != None && !BossVisual.bDeleteMe)
    {
        BossVisual.SetEnraged(true);
    }

    ApplyEnrageVisual(M);
    BroadcastBossEvent(1);
}

function PromoteToChampion(Monster M)
{
    local MonsterController MC;
    local int HumanPlayers;

    if (M == None || M.Health <= 0)
    {
        return;
    }

    M.Tag = 'ChampionMonster';
    // Keep this single boss on every client's actor channel even off-screen.
    // Its visual helpers must never outlive the replicated Pawn reference.
    M.bAlwaysRelevant = true;
    M.NetUpdateTime = Level.TimeSeconds - 1;
    bChampionEnraged = false;
    EnrageTickCounter = 0;

    // +30% de tamano (1.30x, ajustando PrePivot y HeadScale sin deformar el cilindro de colision)
    M.SetDrawScale(M.Default.DrawScale * 1.30);
    M.PrePivot = M.Default.PrePivot + vect(0, 0, 1) * (M.CollisionHeight * 0.30 / M.DrawScale);
    M.HeadScale = M.Default.HeadScale * 1.30;

    // Velocidad moderada en tierra, agua y vuelo.
    M.GroundSpeed = M.Default.GroundSpeed * 1.20;
    M.AirSpeed = M.Default.AirSpeed * 1.20;
    M.WaterSpeed = M.Default.WaterSpeed * 1.20;
    M.AccelRate = M.Default.AccelRate * 1.20;

    // Vida base 2000, +500 por cada jugador humano; escudo 300.
    HumanPlayers = CountActiveHumanPlayers();
    M.Health = 2000 + (HumanPlayers * 500);
    M.HealthMax = M.Health;
    M.ShieldStrengthMax = 300.0;
    M.ShieldStrength = 300.0;
    M.bBoss = true;

    // Mejor punteria y reflejos agiles
    MC = MonsterController(M.Controller);
    if (MC != None)
    {
        MC.InitializeSkill(FMin(7.0, MC.Skill + 3.0));
        MC.Accuracy = 1.0;
        MC.bLeadTarget = true;
        MC.ReactionTime = 0.5;
    }

    // Brillo violeta + Overlay y accesorios visuales (llamas en alas/pies + corona giratoria)
    ApplyUDamageVisual(M);
    EnsureBossAttachments(M);

    // El mensaje se distribuye a todos los clientes y ejecuta alli sonido y sacudida.
    BroadcastBossEvent(0);
}

function KeepChampionAtLowerAltitude(Monster M)
{
    local vector HitLocation, HitNormal;
    local Actor FloorActor;

    if (M == None || M.Physics != PHYS_Flying)
        return;

    // Limita el vuelo a unos 420 uu sobre el suelo mas cercano para que el jefe siga siendo accesible.
    FloorActor = Trace(HitLocation, HitNormal, M.Location - vect(0, 0, 4000), M.Location, false);
    if (FloorActor != None && M.Location.Z - HitLocation.Z > 420.0)
        M.Velocity.Z = FMin(M.Velocity.Z, -180.0);
}

function bool IsSafeBossSpawnSpot(NavigationPoint N, float MinSafeDist)
{
    local Controller C;

    if (N == None)
    {
        return false;
    }

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        if (C.bIsPlayer && C.Pawn != None && C.Pawn.Health > 0 && Monster(C.Pawn) == None)
        {
            if (VSize(C.Pawn.Location - N.Location) < MinSafeDist)
            {
                return false;
            }
        }
    }

    return true;
}

function Monster SpawnChampionWarLord(Invasion InvGame)
{
    local NavigationPoint StartSpot;
    local NavigationPoint Candidate;
    local array<NavigationPoint> SafeStarts;
    local vector SpawnLoc;
    local WarLord NewBoss;
    local Controller NewController;
    local int Pass;
    local int StartIndex;
    local float RequiredDist;

    if (InvGame == None)
    {
        return None;
    }

    // Elige entre puntos distintos y seguros. Repite con menor distancia solo
    // cuando no haya puntos disponibles suficientemente alejados.
    for (Pass = 0; Pass < 2; Pass++)
    {
        if (Pass == 0)
            RequiredDist = 550.0;
        else
            RequiredDist = 220.0;

        SafeStarts.Length = 0;
        foreach AllActors(class'NavigationPoint', Candidate)
        {
            if (IsSafeBossSpawnSpot(Candidate, RequiredDist))
            {
                SafeStarts[SafeStarts.Length] = Candidate;
            }
        }

        while (SafeStarts.Length > 0)
        {
            StartIndex = Rand(SafeStarts.Length);
            StartSpot = SafeStarts[StartIndex];
            SafeStarts.Remove(StartIndex, 1);

            SpawnLoc = StartSpot.Location + (class'WarLord'.Default.CollisionHeight - StartSpot.CollisionHeight) * vect(0, 0, 1);
            NewBoss = Spawn(class'WarLord',,, SpawnLoc, StartSpot.Rotation);
            if (NewBoss != None)
            {
                if (NewBoss.Controller == None)
                {
                    NewController = Spawn(NewBoss.ControllerClass,,, NewBoss.Location, NewBoss.Rotation);
                    if (NewController != None)
                    {
                        NewController.Possess(NewBoss);
                    }
                }

                if (NewBoss.Controller == None)
                {
                    NewBoss.Destroy();
                    continue;
                }

                NewBoss.PlayTeleportEffect(true, true);
                InvGame.WaveMonsters++;
                InvGame.NumMonsters++;
                return NewBoss;
            }
        }
    }

    return None;
}

function Timer()
{
    local Invasion InvGame;
    local Controller C;
    local Monster M, NewBoss;
    local bool bFoundLiveChampion;

    InvGame = Invasion(Level.Game);
    if (InvGame == None)
    {
        return;
    }

    // Al comenzar una nueva oleada, se sortea una sola vez el 25% de probabilidad para toda la ronda
    if (InvGame.bWaveInProgress && InvGame.WaveNum != CurrentWaveNum)
    {
        CurrentWaveNum = InvGame.WaveNum;
        bChampionSpawnedThisWave = false;
        bChampionEnraged = false;
        EnrageTickCounter = 0;
        CleanupBossAttachments();
        bWaveHasChampion = (FRand() < ChampionChance);

        if (bWaveHasChampion)
        {
            // Elige en que momento de la primera mitad de la oleada aparecera el unico Mini-Jefe WarLord
            TargetMonsterIndex = 1 + Rand(Max(1, InvGame.MaxMonsters / 2));
        }
    }


    // Controla el estado del Mini-Jefe vivo (efecto visual normal o fase de Furia al <= 35% de vida)
    bFoundLiveChampion = false;
    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        M = Monster(C.Pawn);
        if (M != None && M.Health > 0 && M.Tag == 'ChampionMonster')
        {
            bFoundLiveChampion = true;
            EnsureBossAttachments(M);
            KeepChampionAtLowerAltitude(M);

            if (!bChampionEnraged && M.Health <= int(M.HealthMax * 0.35))
            {
                TriggerEnrage(M);
            }

            if (bChampionEnraged)
            {
                ApplyEnrageVisual(M);
                EnrageTickCounter++;

                // Dispara cohetes adicionales mucho mas rapido mientras esta en furia y tiene linea de vision
                if (EnrageTickCounter % 2 == 0 && WarLord(M) != None && M.Controller != None && M.Controller.Enemy != None)
                {
                    if (M.Controller.LineOfSightTo(M.Controller.Enemy))
                    {
                        WarLord(M).FireProjectile();
                    }
                }
            }
            else
            {
                ApplyUDamageVisual(M);
            }
        }
    }

    if (bChampionSpawnedThisWave && !bFoundLiveChampion)
    {
        CleanupBossAttachments();
    }

    // Spawnea 1 unico Senor de la Guerra (WarLord) como Mini-Jefe cuando la oleada alcanza el momento elegido
    if (InvGame.bWaveInProgress && bWaveHasChampion && !bChampionSpawnedThisWave && InvGame.WaveMonsters >= TargetMonsterIndex)
    {
        NewBoss = SpawnChampionWarLord(InvGame);
        if (NewBoss != None)
        {
            bChampionSpawnedThisWave = true;
            PromoteToChampion(NewBoss);
        }
    }
}

defaultproperties
{
    ChampionChance=0.25
    CurrentWaveNum=-1
    GroupName="MarianoskyRage"
    FriendlyName="[Irreal] Marianosky's rage"
    Description="25% de probabilidad por oleada de que aparezca el Rey Cthulhu (WarLord con +30% de tamano, brillo violeta, llamas en alas y pies y corona giratoria; 2000 HP base + 500 por jugador humano, 300 de escudo y +20% de velocidad; recibe 50% menos dano, o 65% menos si lo atacan bots, y 50% menos retroceso). Al 35% de vida entra en furia: brillo rojo, +35% de velocidad y mas cohetes. Al morir da doble puntaje, suelta un Double Damage, otorga +25 de escudo al equipo y revive a un companero caido."
}
