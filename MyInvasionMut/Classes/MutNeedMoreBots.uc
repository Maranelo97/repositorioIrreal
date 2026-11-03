class MutNeedMoreBots extends Mutator;

// Opciones de "Configurar mutadores"; quedan guardadas en el .ini del juego del host
var config int BotsPerPlayer;   // bots por cada jugador real
var config int MaxBots;         // tope de bots en la partida

var localized string BotsPerPlayerText, BotsPerPlayerDesc;
var localized string MaxBotsText, MaxBotsDesc;

// Cantidad de bots para esa cantidad de jugadores, dentro de los limites de las opciones
function int DesiredBotCount(int RealPlayers)
{
    return Clamp(RealPlayers * Clamp(BotsPerPlayer, 0, 8), 0, Clamp(MaxBots, 0, 32));
}

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
        DM.BotRatio = float(Clamp(BotsPerPlayer, 0, 8));
        DM.InitialBots = DesiredBotCount(1);
        DM.MinPlayers = 1 + DesiredBotCount(1);
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

    // En partida instantanea (Standalone), asegurar base de 1 jugador
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
    DesiredBots = DesiredBotCount(RealPlayers);

    DM.bAutoNumBots = false;
    DM.bCustomBots = false;
    DM.BotRatio = float(Clamp(BotsPerPlayer, 0, 8));
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
    DesiredBots = DesiredBotCount(RealPlayers);

    // Sincronizar las propiedades de DeathMatch para que el motor mantenga la proporcion
    DM.bAutoNumBots = false;
    DM.bCustomBots = false;
    DM.BotRatio = float(Clamp(BotsPerPlayer, 0, 8));
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

    // Agregar bots si faltan para alcanzar la cantidad por jugador real
    SafetyCounter = 0;
    while (DM.NumBots < DesiredBots && SafetyCounter < 32)
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

static function FillPlayInfo(PlayInfo PlayInfo)
{
    Super.FillPlayInfo(PlayInfo);
    PlayInfo.AddSetting(default.RulesGroup, "BotsPerPlayer", default.BotsPerPlayerText, 0, 1, "Text", "1;0:8");
    PlayInfo.AddSetting(default.RulesGroup, "MaxBots", default.MaxBotsText, 0, 2, "Text", "2;0:32");
}

static event string GetDescriptionText(string PropName)
{
    switch (PropName)
    {
        case "BotsPerPlayer": return default.BotsPerPlayerDesc;
        case "MaxBots":       return default.MaxBotsDesc;
    }
    return Super.GetDescriptionText(PropName);
}

defaultproperties
{
    BotsPerPlayer=3
    MaxBots=24
    BotsPerPlayerText="Bots por jugador"
    BotsPerPlayerDesc="Cantidad de bots que se agregan por cada jugador real conectado (de 0 a 8) [por defecto: 3]"
    MaxBotsText="Maximo de bots"
    MaxBotsDesc="Tope de bots en la partida, sin importar cuantos jugadores haya (de 0 a 32) [por defecto: 24]"
    GroupName="BotCountMut"
    FriendlyName="[Irreal] Necesitamos mas BOTS"
    Description="Ajusta dinamicamente la cantidad de bots segun los jugadores reales conectados: una cantidad de bots por cada jugador (3 por defecto) con un maximo (24 por defecto). Las dos se pueden cambiar en Configurar mutadores."
}
