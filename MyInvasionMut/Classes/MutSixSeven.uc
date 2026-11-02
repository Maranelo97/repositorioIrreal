class MutSixSeven extends Mutator;

function bool IsTeamBattleGame()
{
    // Activo en todos los modos por equipos (Team DeathMatch, CTF, Bombing Run, Double Domination, Onslaught, Assault),
    // excluyendo Invasion donde humanos y bots cooperan en el mismo equipo contra monstruos.
    return (TeamGame(Level.Game) != None && !Level.Game.IsA('Invasion'));
}

function ConfigureTeamFlags(TeamGame TG)
{
    if (TG == None)
    {
        return;
    }

    // Desactivar el autobalanceo para evitar que el juego destruya bots del equipo rojo
    // o fuerce a jugadores reales al equipo rojo cuando hay desbalance numerico.
    TG.bBalanceTeams = false;
    TG.bPlayersBalanceTeams = false;

    if (TG.GameReplicationInfo != None)
    {
        TG.GameReplicationInfo.bNoTeamChanges = true;
    }
}

function PostBeginPlay()
{
    local SixSevenRules GR;
    local TeamGame TG;

    Super.PostBeginPlay();

    if (!IsTeamBattleGame())
    {
        return;
    }

    TG = TeamGame(Level.Game);
    ConfigureTeamFlags(TG);

    GR = Spawn(class'SixSevenRules');
    if (GR != None)
    {
        GR.SixSevenMut = self;
        if (Level.Game.GameRulesModifiers == None)
        {
            Level.Game.GameRulesModifiers = GR;
        }
        else
        {
            Level.Game.GameRulesModifiers.AddGameRules(GR);
        }
    }

    SetTimer(1.0, true);
}

function ModifyLogin(out string Portal, out string Options)
{
    local TeamGame TG;

    if (IsTeamBattleGame())
    {
        TG = TeamGame(Level.Game);
        ConfigureTeamFlags(TG);

        // Prepend ?Team=1 para que todo jugador real entre directamente al Equipo Azul (1)
        Options = "?Team=1" $ Options;
    }

    if (NextMutator != None)
    {
        NextMutator.ModifyLogin(Portal, Options);
    }
}

function EnforceSingleControllerTeam(Controller C)
{
    local TeamGame TG;
    local UnrealTeamInfo TargetTeam;
    local byte TargetTeamIdx;

    if (Level == None || Level.bStartup || !IsTeamBattleGame() || C == None || C.PlayerReplicationInfo == None)
    {
        return;
    }

    if (C.PlayerReplicationInfo.bOnlySpectator)
    {
        return;
    }

    TG = TeamGame(Level.Game);
    if (TG == None)
    {
        return;
    }

    ConfigureTeamFlags(TG);

    // Bots siempre al Equipo Rojo (0); Jugadores reales siempre al Equipo Azul (1)
    if (Bot(C) != None)
    {
        TargetTeamIdx = 0;
    }
    else if (PlayerController(C) != None)
    {
        TargetTeamIdx = 1;
    }
    else
    {
        return;
    }

    TargetTeam = TG.Teams[TargetTeamIdx];
    if (TargetTeam == None || C.PlayerReplicationInfo.Team == TargetTeam)
    {
        return;
    }

    if (C.PlayerReplicationInfo.Team != None)
    {
        C.PlayerReplicationInfo.Team.RemoveFromTeam(C);
    }

    if (TargetTeam.AddToTeam(C))
    {
        if (Bot(C) != None)
        {
            TargetTeam.SetBotOrders(Bot(C), None);
        }
    }
}

function EnforceAllTeams()
{
    local Controller C;

    if (!IsTeamBattleGame())
    {
        return;
    }

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        EnforceSingleControllerTeam(C);
    }
}

function ModifyPlayer(Pawn Other)
{
    if (Other != None && Other.Controller != None)
    {
        EnforceSingleControllerTeam(Other.Controller);
    }

    Super.ModifyPlayer(Other);
}

function Timer()
{
    EnforceAllTeams();
}

defaultproperties
{
    GroupName="SixSevenTeams"
    FriendlyName="Six Seven"
    Description="En batallas por equipos (excepto Invasion), ubica siempre a todos los jugadores reales en el Equipo Azul y a todos los bots en el Equipo Rojo. Desactiva el balanceo automatico de equipos."
}
