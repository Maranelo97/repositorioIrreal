// Al buscar donde aparece un jugador o un bot, lo ubica en su equipo (ver MutNecesitamosMasBots,
// "Jugadores contra bots")
class BotTeamRules extends GameRules;

var MutNecesitamosMasBots BotsMut;

function NavigationPoint FindPlayerStart(Controller Player, optional byte InTeam, optional string incomingName)
{
    if (BotsMut != None && Player != None)
        BotsMut.EnforceSingleControllerTeam(Player);

    if (NextGameRules != None)
        return NextGameRules.FindPlayerStart(Player, InTeam, incomingName);

    return None;
}
