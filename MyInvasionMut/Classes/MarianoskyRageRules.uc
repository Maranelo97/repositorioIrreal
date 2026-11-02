class MarianoskyRageRules extends GameRules;

function Controller ReviveOneFallenTeammate()
{
    local Controller C, ChosenHuman, ChosenBot, Target;

    if (Invasion(Level.Game) == None)
    {
        return None;
    }

    // Busca un companero caido en esta oleada (priorizando primero a un jugador humano, luego a un bot)
    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        if (C.bIsPlayer && C.PlayerReplicationInfo != None && !C.PlayerReplicationInfo.bOnlySpectator)
        {
            if ((C.Pawn == None || C.Pawn.Health <= 0) && C.PlayerReplicationInfo.bOutOfLives)
            {
                if (PlayerController(C) != None && ChosenHuman == None)
                {
                    ChosenHuman = C;
                }
                else if (Bot(C) != None && ChosenBot == None)
                {
                    ChosenBot = C;
                }
            }
        }
    }

    if (ChosenHuman != None)
    {
        Target = ChosenHuman;
    }
    else
    {
        Target = ChosenBot;
    }

    if (Target != None)
    {
        Target.PlayerReplicationInfo.bOutOfLives = false;
        Target.PlayerReplicationInfo.NumLives = 0;
        if (PlayerController(Target) != None)
        {
            PlayerController(Target).SetViewTarget(Target);
        }
        Target.ServerReStartPlayer();
    }

    return Target;
}

function DropDoubleDamageLoot(Monster M)
{
    local UDamagePack DroppedUDamage;

    if (M == None)
    {
        return;
    }

    DroppedUDamage = Spawn(class'XPickups.UDamagePack',,, M.Location);
    if (DroppedUDamage != None)
    {
        DroppedUDamage.InitDroppedPickupFor(None);
        DroppedUDamage.Velocity = vect(0, 0, 180);
        DroppedUDamage.bInstantRespawn = false;
        DroppedUDamage.RespawnTime = 0.0;
        DroppedUDamage.LifeSpan = 45.0;
    }
}

function int NetDamage(int OriginalDamage, int Damage, pawn injured, pawn instigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
    if (NextGameRules != None)
    {
        Damage = NextGameRules.NetDamage(OriginalDamage, Damage, injured, instigatedBy, HitLocation, Momentum, DamageType);
    }

    // No conviertas impactos nulos o curativos en daño al jefe.
    if (Damage <= 0)
    {
        return Damage;
    }

    if (injured != None && injured.Health > 0 && injured.Tag == 'ChampionMonster')
    {
        // Resistencia pasiva de jefe de raid:
        // Reduce a la mitad el retroceso para que las armas no lo dejen inmovilizado o suspendido en el aire
        Momentum *= 0.50;

        // Si el dano proviene de un Bot aliado, reduccion pasiva del 65% (recibe solo el 35% de dano)
        // para que no lo liquiden los bots en segundos y el golpe de gracia dependa de los jugadores humanos
        if (instigatedBy != None && Bot(instigatedBy.Controller) != None)
        {
            Damage = Max(1, int(float(Damage) * 0.35 + 0.5));
        }
        else
        {
            // Dano general de proyectiles y ataques (humanos / ambiente): 50% de reduccion pasiva
            Damage = Max(1, int(float(Damage) * 0.50 + 0.5));
        }
    }

    return Damage;
}

function bool PreventDeath(Pawn Killed, Controller Killer, class<DamageType> damageType, vector HitLocation)
{
    local Monster M;
    local Controller C, RevivedTeammate;
    local int BonusScore;
    local string BroadcastMsg;

    if (NextGameRules != None && NextGameRules.PreventDeath(Killed, Killer, damageType, HitLocation))
    {
        return true;
    }

    M = Monster(Killed);
    if (M != None && M.Tag == 'ChampionMonster')
    {
        M.Tag = 'ChampionDead';
        M.HighDetailOverlay = None;
        M.SetOverlayMaterial(None, 0.0, true);
        M.AmbientGlow = M.Default.AmbientGlow;
        M.LightType = LT_None;
        M.bDynamicLight = false;

        // Otorga el doble de puntos al jugador que lo elimino (sumando otro tanto igual al puntaje base)
        BonusScore = Max(1, M.Default.ScoringValue);
        if (Killer != None && Killer.bIsPlayer && Killer.PlayerReplicationInfo != None)
        {
            Killer.PlayerReplicationInfo.Score += BonusScore;
            if (Killer.PlayerReplicationInfo.Team != None)
            {
                Killer.PlayerReplicationInfo.Team.Score += BonusScore;
                Killer.PlayerReplicationInfo.Team.NetUpdateTime = Level.TimeSeconds - 1;
            }
            Killer.AwardAdrenaline(BonusScore);
            Killer.PlayerReplicationInfo.NetUpdateTime = Level.TimeSeconds - 1;
        }

        // Recarga +25 de escudo a todos los jugadores y bots aliados vivos
        for (C = Level.ControllerList; C != None; C = C.NextController)
        {
            if (C.bIsPlayer && C.Pawn != None && C.Pawn.Health > 0 && Monster(C.Pawn) == None)
            {
                C.Pawn.AddShieldStrength(25);
            }
        }

        // Suelta un Double Damage como botin en el lugar donde murio el Rey Cthulhu
        DropDoubleDamageLoot(M);

        // Revive automaticamente a un companero (jugador o bot) caido durante la oleada
        RevivedTeammate = ReviveOneFallenTeammate();

        BroadcastMsg = "EL REY CTHULHU FUE ABATIDO! Suelta Double Damage y +25 de Escudo para el equipo!";
        if (RevivedTeammate != None && RevivedTeammate.PlayerReplicationInfo != None)
        {
            BroadcastMsg = BroadcastMsg $ " (" $ RevivedTeammate.PlayerReplicationInfo.PlayerName $ " ha vuelto a la batalla!)";
        }
        Level.Game.Broadcast(None, BroadcastMsg, 'CriticalEvent');
    }

    return false;
}
