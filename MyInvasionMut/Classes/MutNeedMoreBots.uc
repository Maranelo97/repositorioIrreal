class MutNeedMoreBots extends Mutator;

var int BotsPerPlayer;

function PostBeginPlay()
{
    local DeathMatch DM;

    Super.PostBeginPlay();

    // IMPORTANTE: No llamar a AddBot() ni KillBot() aqui porque PostBeginPlay() se ejecuta
    // dentro de GameInfo.InitGame() mientras Level.bStartup == true y antes de que existan
    // los equipos (Teams[0]/Teams[1]) y el GameReplicationInfo.
    DM = DeathMatch(Level.Game);
    if (DM != None)
    {
        DM.bAutoNumBots = false;
        DM.bCustomBots = false;
        DM.BotRatio = float(BotsPerPlayer);
        DM.InitialBots = BotsPerPlayer;
        DM.MinPlayers = 1 + BotsPerPlayer;
    }

    SetTimer(1.0, true);
}

function int GetRealPlayerCount()
{
    local Controller C;
    local PlayerController PC;
    local int Count;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        PC = PlayerController(C);
        if (PC != None && PC.PlayerReplicationInfo != None && !PC.PlayerReplicationInfo.bOnlySpectator)
        {
            Count++;
        }
    }

    // En partida instantanea (Standalone), asegurar base de 1 jugador (3 bots)
    if (Count == 0 && Level.NetMode == NM_Standalone)
    {
        Count = 1;
    }

    return Count;
}

function SyncPreMatchBots(DeathMatch DM)
{
    local int RealPlayers, DesiredBots;

    if (DM == None || DM.bGameEnded)
    {
        return;
    }

    RealPlayers = GetRealPlayerCount();
    DesiredBots = Clamp(RealPlayers * BotsPerPlayer, 0, 24);

    DM.bAutoNumBots = false;
    DM.bCustomBots = false;
    DM.BotRatio = float(BotsPerPlayer);
    DM.InitialBots = DesiredBots;
    DM.MinPlayers = RealPlayers + DesiredBots;

    if (Level.NetMode == NM_Standalone)
    {
        DM.RemainingBots = DesiredBots;
    }
}

function ModifyPlayer(Pawn Other)
{
    local DeathMatch DM;

    if (Level != None && !Level.bStartup && Other != None && PlayerController(Other.Controller) != None)
    {
        DM = DeathMatch(Level.Game);
        if (DM != None && DM.NumBots == 0)
        {
            SyncPreMatchBots(DM);
        }
    }

    Super.ModifyPlayer(Other);
}

function Tick(float DeltaTime)
{
    local DeathMatch DM;

    Super.Tick(DeltaTime);

    if (Level == None || Level.bStartup)
    {
        return;
    }

    DM = DeathMatch(Level.Game);
    if (DM != None && DM.bWaitingToStartMatch)
    {
        // Sobrescribe el limite de 2 bots de Invasion.OverrideInitialBots() y cualquier ?NumBots= de la URL
        // antes de que el jugador inicie la partida (StartMatch).
        SyncPreMatchBots(DM);
    }
}

function RemoveExcessBots(DeathMatch DM, int ExcessCount)
{
    local Controller C, NextC;
    local Bot B;
    local Pawn P;
    local int Removed;

    if (DM == None || ExcessCount <= 0)
    {
        return;
    }

    DM.bKillBots = true;
    C = Level.ControllerList;
    while (C != None && Removed < ExcessCount)
    {
        NextC = C.NextController;
        B = Bot(C);
        if (B != None)
        {
            if (Level.NetMode != NM_Standalone)
            {
                DM.MinPlayers = Max(DM.MinPlayers - 1, DM.NumPlayers + DM.NumBots - 1);
            }

            // Destruir el Pawn limpiamente sin usar DM.KillBot() (que llama a KilledBy() y mata al bot en el spawn restando puntos)
            P = B.Pawn;
            if (P != None)
            {
                if (Vehicle(P) != None && Vehicle(P).Driver != None)
                {
                    Vehicle(P).Driver.Destroy();
                }
                B.UnPossess();
                P.Destroy();
            }
            B.Destroy();
            Removed++;
        }
        C = NextC;
    }
    DM.bKillBots = false;
    DM.RemainingBots = 0;
}

function UpdateBotCount()
{
    local DeathMatch DM;
    local TeamGame TG;
    local int RealPlayers, DesiredBots, SafetyCounter;

    if (Level == None || Level.bStartup)
    {
        return;
    }

    DM = DeathMatch(Level.Game);
    if (DM == None || DM.bGameEnded || DM.GameReplicationInfo == None)
    {
        return;
    }

    // Asegurar que los equipos ya hayan sido creados antes de manipular bots
    TG = TeamGame(DM);
    if (TG != None && (TG.Teams[0] == None || TG.Teams[1] == None))
    {
        return;
    }

    RealPlayers = GetRealPlayerCount();
    DesiredBots = Clamp(RealPlayers * BotsPerPlayer, 0, 24);

    // Sincronizar las propiedades de DeathMatch para que el motor mantenga la escala 3:1
    DM.bAutoNumBots = false;
    DM.bCustomBots = false;
    DM.BotRatio = float(BotsPerPlayer);
    DM.InitialBots = DesiredBots;
    DM.MinPlayers = RealPlayers + DesiredBots;

    if (DM.bWaitingToStartMatch)
    {
        if (Level.NetMode == NM_Standalone)
        {
            DM.RemainingBots = DesiredBots;
        }
        return;
    }

    DM.RemainingBots = 0;

    // Agregar bots si faltan para alcanzar 3 por cada jugador real
    SafetyCounter = 0;
    while (DM.NumBots < DesiredBots && SafetyCounter < 24)
    {
        if (!DM.AddBot())
        {
            break;
        }
        SafetyCounter++;
    }

    // Eliminar bots sobrantes silenciosamente si se desconecto algun jugador o habia de mas
    if (DM.NumBots > DesiredBots)
    {
        RemoveExcessBots(DM, DM.NumBots - DesiredBots);
    }
}

function Timer()
{
    UpdateBotCount();
}

defaultproperties
{
    BotsPerPlayer=3
    GroupName="BotCountMut"
    FriendlyName="Necesitamos mas BOTS"
    Description="Ajusta dinamicamente la cantidad de bots a una escala de 3 bots por cada jugador real conectado en la partida."
}
