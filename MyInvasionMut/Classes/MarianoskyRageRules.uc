class MarianoskyRageRules extends GameRules;

// Recompensa por matar al Rey Cthulhu: Double Damage para los que estaban vivos, hasta que
// termina la oleada (se le da un tiempo largo y se le saca al terminar, en Tick)
var array<xPawn> RewardedPawns;
const RewardUDamageTime = 3600.0;

// Desde el principio, para que el contador ya este escondido cuando llegue la recompensa
function PostBeginPlay()
{
    Super.PostBeginPlay();
    Spawn(class'CthulhuRewardHud');
}

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
            // Un jugador sin vidas queda como espectador, y ahi ServerReStartPlayer no hace nada:
            // como hace Invasion al revivir entre oleadas, primero vuelve a "esperando para jugar".
            // WaitDelay bloquea el reinicio hasta 2 s despues de morir; se libera por si murio recien.
            PlayerController(Target).GotoState('PlayerWaiting');
            // En un cliente, el estado Spectating ignora ClientRestart: sin avisarle primero, se
            // pierde el reinicio y se queda con la camara en tercera persona de cuando miraba a otro.
            PlayerController(Target).ClientGotoState('PlayerWaiting', '');
            PlayerController(Target).WaitDelay = Level.TimeSeconds;
            PlayerController(Target).SetViewTarget(Target);
        }
        Target.ServerReStartPlayer();
    }

    return Target;
}

// Vida, escudo, municion y adrenalina al maximo, y Double Damage hasta el final de la oleada
function GiveBossReward(Controller C)
{
    local Inventory Inv;
    local Weapon W;
    local xPawn P;

    C.Pawn.Health = Max(C.Pawn.Health, int(C.Pawn.SuperHealthMax));
    C.Pawn.AddShieldStrength(int(C.Pawn.GetShieldStrengthMax()));
    if (C.bAdrenalineEnabled)
        C.Adrenaline = C.AdrenalineMax;

    // Las armas de GIGACHADrenalina gastan adrenalina, que ya quedo llena
    for (Inv = C.Pawn.Inventory; Inv != None; Inv = Inv.Inventory)
    {
        W = Weapon(Inv);
        if (W != None && !class'MutGigachadrenalina'.static.IsAdrenalineWeapon(W.Class))
            W.MaxOutAmmo();
    }

    P = xPawn(C.Pawn);
    if (P != None)
    {
        P.EnableUDamage(RewardUDamageTime);
        RewardedPawns[RewardedPawns.Length] = P;
    }
}

// Al terminar la oleada se saca el Double Damage de la recompensa
function Tick(float DeltaTime)
{
    local int i;

    Super.Tick(DeltaTime);
    if (RewardedPawns.Length == 0 || Invasion(Level.Game) == None || Invasion(Level.Game).bWaveInProgress)
        return;

    for (i = 0; i < RewardedPawns.Length; i++)
    {
        if (RewardedPawns[i] != None && !RewardedPawns[i].bDeleteMe && RewardedPawns[i].HasUDamage())
        {
            if (RewardedPawns[i].UDamageTimer != None)
                RewardedPawns[i].UDamageTimer.Destroy();
            RewardedPawns[i].DisableUDamage();
        }
    }
    RewardedPawns.Length = 0;
}

function int NetDamage(int OriginalDamage, int Damage, pawn injured, pawn instigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
    local int Reduction;

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

        // Las reducciones salen de las opciones de MutMarianoskyRage (65% y 50% por defecto).
        // Si el dano proviene de un Bot aliado, reduccion mayor
        // para que no lo liquiden los bots en segundos y el golpe de gracia dependa de los jugadores humanos
        if (instigatedBy != None && Bot(instigatedBy.Controller) != None)
        {
            Reduction = Clamp(class'MutMarianoskyRage'.default.BotDamageReduction, 0, 95);
        }
        else
        {
            // Dano general de proyectiles y ataques (humanos / ambiente)
            Reduction = Clamp(class'MutMarianoskyRage'.default.PlayerDamageReduction, 0, 95);
        }
        Damage = Max(1, int(float(Damage) * float(100 - Reduction) / 100.0 + 0.5));
    }

    return Damage;
}

function bool PreventDeath(Pawn Killed, Controller Killer, class<DamageType> damageType, vector HitLocation)
{
    local Monster M;
    local Controller C, RevivedTeammate;
    local int BonusScore;
    local PlayerReplicationInfo RevivedPRI;

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

        // Recompensa para todos los jugadores y bots aliados vivos. Va antes de revivir: el
        // companero revivido no la recibe (volver a la batalla ya es bastante premio)
        for (C = Level.ControllerList; C != None; C = C.NextController)
        {
            if (C.bIsPlayer && C.Pawn != None && C.Pawn.Health > 0 && Monster(C.Pawn) == None)
            {
                GiveBossReward(C);
            }
        }

        // Revive automaticamente a un companero (jugador o bot) caido durante la oleada
        RevivedTeammate = ReviveOneFallenTeammate();

        // Mensaje en varias lineas (titulo, recompensas y, si hubo, el companero revivido)
        if (RevivedTeammate != None)
            RevivedPRI = RevivedTeammate.PlayerReplicationInfo;
        Level.Game.BroadcastLocalizedMessage(class'CthulhuBossMessage', 2, RevivedPRI);
    }

    return false;
}
