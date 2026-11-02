class MutInfectionBeamEffect extends LinkBeamEffect;

var vector InfectionBeamStart;
var vector InfectionBeamEnd;

replication
{
    reliable if (Role == ROLE_Authority)
        InfectionBeamStart, InfectionBeamEnd;
}

function SetBeamPoints(vector StartPoint, vector EndPoint)
{
    InfectionBeamStart = StartPoint;
    InfectionBeamEnd = EndPoint;
    StartEffect = StartPoint;
    EndEffect = EndPoint;
    SetLocation(StartPoint);
    SetRotation(Rotator(EndPoint - StartPoint));
}

simulated function SetBeamLocation()
{
    StartEffect = InfectionBeamStart;
    EndEffect = InfectionBeamEnd;
    SetLocation(InfectionBeamStart);
    SetRotation(Rotator(InfectionBeamEnd - InfectionBeamStart));
}

defaultproperties
{
    bNetTemporary=True
    LifeSpan=0.35
}
