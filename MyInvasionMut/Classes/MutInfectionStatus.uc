class MutInfectionStatus extends Info;

var MutLeTransmitoTodoAMiBB InfectionMutator;
var Controller InfectedController;
var Controller CuringController;
var MutInfectionBRVisual BRVisual;
var float NextDamageTime;
var float CureProgress;

function Initialize(Controller TargetController, MutLeTransmitoTodoAMiBB MutatorOwner)
{
    InfectedController = TargetController;
    InfectionMutator = MutatorOwner;
    NextDamageTime = Level.TimeSeconds + 1.0;
    SetTimer(0.25, true);
}

function AttachVisual(Pawn P)
{
    if (P == None)
    {
        return;
    }

    if (BRVisual != None && BRVisual.Base != P)
    {
        BRVisual.Destroy();
        BRVisual = None;
    }

    if (BRVisual == None)
    {
        BRVisual = Spawn(class'MutInfectionBRVisual', self,, P.Location, P.Rotation);
        if (BRVisual != None)
        {
            P.AttachToBone(BRVisual, 'spine');
        }
    }
}

function Timer()
{
    local Pawn P;

    if (InfectedController == None || InfectionMutator == None)
    {
        Cure();
        return;
    }

    P = InfectedController.Pawn;
    if (P == None || P.Health <= 0)
    {
        if (BRVisual != None)
        {
            BRVisual.Destroy();
            BRVisual = None;
        }
        return;
    }

    AttachVisual(P);
    if (Level.TimeSeconds >= NextDamageTime)
    {
        P.TakeDamage(1, None, P.Location, vect(0,0,0), class'MutInfectionDamageType');
        NextDamageTime = Level.TimeSeconds + 1.0;
    }
}

function Cure()
{
    if (BRVisual != None)
    {
        BRVisual.Destroy();
        BRVisual = None;
    }
    SetTimer(0.0, false);
    Destroy();
}

