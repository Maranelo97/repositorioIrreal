// Al buscar donde aparece un jugador o un bot, lo ubica en su equipo (ver MutNeedMoreBots,
// "Jugadores contra bots")
class BotTeamRules extends GameRules;

var MutNeedMoreBots BotsMut;

function NavigationPoint FindPlayerStart(Controller Player, optional byte InTeam, optional string incomingName)
{
    if (BotsMut != None && Player != None)
        BotsMut.EnforceSingleControllerTeam(Player);

    if (NextGameRules != None)
        return NextGameRules.FindPlayerStart(Player, InTeam, incomingName);

    return None;
}
