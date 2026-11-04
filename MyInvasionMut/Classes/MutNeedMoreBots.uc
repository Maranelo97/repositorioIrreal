// Necesitamos mas BOTS: ajusta la cantidad de bots segun los jugadores reales y, en las
// partidas por equipos (menos Invasion), pone a los jugadores contra los bots. Lo segundo era
// el mutador Six Seven.
class MutNeedMoreBots extends Mutator;

// Opciones de "Configurar mutadores"; quedan guardadas en el .ini del juego del host
var config int BotsPerPlayer;   // bots por cada jugador real
var config int MaxBots;         // tope de bots en la partida
var config bool bHumansVsBots;    // en partidas por equipos: jugadores en el Azul y bots en el Rojo

var localized string BotsPerPlayerText, BotsPerPlayerDesc;
var localized string MaxBotsText, MaxBotsDesc;
var localized string HumansVsBotsText, HumansVsBotsDesc;

// Cantidad de bots para esa cantidad de jugadores, dentro de los limites de las opciones
function int DesiredBotCount(int RealPlayers)
{
    return Clamp(RealPlayers * Clamp(BotsPerPlayer, 0, 8), 0, Clamp(MaxBots, 0, 32));
}

function PostBeginPlay()
{
    local DeathMatch DM;
    local BotTeamRules GR;

    Super.PostBeginPlay();

    // Jugadores contra bots: sin balanceo automatico y con una regla que ubica a cada uno
    // en su equipo al aparecer
    if (IsTeamBattleGame())
    {
        ConfigureTeamFlags(TeamGame(Level.Game));
        GR = Spawn(class'BotTeamRules');
        if (GR != None)
        {
            GR.BotsMut = self;
            if (Level.Game.GameRulesModifiers == None)
                Level.Game.GameRulesModifiers = GR;
            else
                Level.Game.GameRulesModifiers.AddGameRules(GR);
        }
    }

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

    if (Other != None && Other.Controller != None)
        EnforceSingleControllerTeam(Other.Controller);

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
    EnforceAllTeams();
}

// ---- Jugadores contra bots (antes Six Seven) ----

// Solo en los modos por equipos (Team DeathMatch, CTF, Bombing Run, Double Domination,
// Onslaught, Assault) y no en Invasion, donde jugadores y bots juegan juntos contra los monstruos
function bool IsTeamBattleGame()
{
    return bHumansVsBots && TeamGame(Level.Game) != None && !Level.Game.IsA('Invasion');
}

function ConfigureTeamFlags(TeamGame TG)
{
    if (TG == None)
        return;

    // Sin autobalanceo, para que el juego no destruya bots del equipo rojo ni pase jugadores
    // reales al rojo cuando hay mas de un lado que del otro
    TG.bBalanceTeams = false;
    TG.bPlayersBalanceTeams = false;
    if (TG.GameReplicationInfo != None)
        TG.GameReplicationInfo.bNoTeamChanges = true;
}

function ModifyLogin(out string Portal, out string Options)
{
    if (IsTeamBattleGame())
    {
        ConfigureTeamFlags(TeamGame(Level.Game));

        // ?Team=1 va adelante para que el jugador entre directo al Equipo Azul: el motor se
        // queda con la primera aparicion de Team. Si alguna vez no alcanza, la correccion real
        // la hace EnforceSingleControllerTeam (al aparecer y cada segundo).
        Options = "?Team=1" $ Options;
    }

    if (NextMutator != None)
        NextMutator.ModifyLogin(Portal, Options);
}

// Bots al Equipo Rojo (0) y jugadores reales al Azul (1)
function EnforceSingleControllerTeam(Controller C)
{
    local TeamGame TG;
    local UnrealTeamInfo TargetTeam;
    local byte TargetTeamIdx;

    if (Level == None || Level.bStartup || !IsTeamBattleGame() || C == None || C.PlayerReplicationInfo == None)
        return;
    if (C.PlayerReplicationInfo.bOnlySpectator)
        return;

    TG = TeamGame(Level.Game);
    if (TG == None)
        return;

    ConfigureTeamFlags(TG);

    if (Bot(C) != None)
        TargetTeamIdx = 0;
    else if (PlayerController(C) != None)
        TargetTeamIdx = 1;
    else
        return;

    TargetTeam = TG.Teams[TargetTeamIdx];
    if (TargetTeam == None || C.PlayerReplicationInfo.Team == TargetTeam)
        return;

    if (C.PlayerReplicationInfo.Team != None)
        C.PlayerReplicationInfo.Team.RemoveFromTeam(C);

    if (TargetTeam.AddToTeam(C) && Bot(C) != None)
        TargetTeam.SetBotOrders(Bot(C), None);
}

function EnforceAllTeams()
{
    local Controller C;

    if (!IsTeamBattleGame())
        return;

    for (C = Level.ControllerList; C != None; C = C.NextController)
        EnforceSingleControllerTeam(C);
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
    Super.FillPlayInfo(PlayInfo);
    PlayInfo.AddSetting(default.RulesGroup, "BotsPerPlayer", default.BotsPerPlayerText, 0, 1, "Text", "1;0:8");
    PlayInfo.AddSetting(default.RulesGroup, "MaxBots", default.MaxBotsText, 0, 2, "Text", "2;0:32");
    PlayInfo.AddSetting(default.RulesGroup, "bHumansVsBots", default.HumansVsBotsText, 0, 3, "Check");
}

static event string GetDescriptionText(string PropName)
{
    switch (PropName)
    {
        case "BotsPerPlayer": return default.BotsPerPlayerDesc;
        case "bHumansVsBots": return default.HumansVsBotsDesc;
        case "MaxBots":       return default.MaxBotsDesc;
    }
    return Super.GetDescriptionText(PropName);
}

defaultproperties
{
    // Manda este paquete a los jugadores que se conectan: sin esto, a ellos no les llega nada
    // de lo que se dibuja o pasa en su maquina (radar, Vision, mensajes, armas con adrenalina...)
    bAddToServerPackages=True
    BotsPerPlayer=3
    MaxBots=24
    bHumansVsBots=True
    HumansVsBotsText="Jugadores contra bots"
    HumansVsBotsDesc="En las partidas por equipos (menos Invasion), todos los jugadores reales van al Equipo Azul y todos los bots al Rojo, sin balanceo automatico [por defecto: activada]"
    BotsPerPlayerText="Bots por jugador"
    BotsPerPlayerDesc="Cantidad de bots que se agregan por cada jugador real conectado (de 0 a 8) [por defecto: 3]"
    MaxBotsText="Maximo de bots"
    MaxBotsDesc="Tope de bots en la partida, sin importar cuantos jugadores haya (de 0 a 32) [por defecto: 24]"
    GroupName="BotCountMut"
    FriendlyName="[Irreal] Necesitamos mas BOTS"
    Description="Ajusta dinamicamente la cantidad de bots segun los jugadores reales conectados: una cantidad de bots por cada jugador (3 por defecto) con un maximo (24 por defecto). En las partidas por equipos (menos Invasion) pone a todos los jugadores reales en el Equipo Azul y a todos los bots en el Rojo, sin balanceo automatico. Todo se cambia en Configurar mutadores."
}
