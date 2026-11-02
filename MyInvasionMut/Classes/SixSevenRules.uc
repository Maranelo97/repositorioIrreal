class SixSevenRules extends GameRules;

var MutSixSeven SixSevenMut;

function NavigationPoint FindPlayerStart(Controller Player, optional byte InTeam, optional string incomingName)
{
    if (SixSevenMut != None && Player != None)
    {
        SixSevenMut.EnforceSingleControllerTeam(Player);
    }

    if (NextGameRules != None)
    {
        return NextGameRules.FindPlayerStart(Player, InTeam, incomingName);
    }

    return None;
}
