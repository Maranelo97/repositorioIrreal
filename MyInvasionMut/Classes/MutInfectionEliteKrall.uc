class MutInfectionEliteKrall extends EliteKrall;

function SpawnShot()
{
    local vector X, Y, Z, StartPoint, EndPoint, HitLocation, HitNormal;
    local Actor HitActor;
    local Pawn HitPawn, IntendedTarget;
    local MutLeTransmitoTodoAMiBB InfectionMutator;
    local MutInfectionBeamEffect Beam;

    if (Controller == None || Controller.Enemy == None)
        return;

    IntendedTarget = Controller.Enemy;
    if (IntendedTarget == None)
        return;

    GetAxes(Rotation, X, Y, Z);
    StartPoint = GetFireStart(X, Y, Z);
    EndPoint = StartPoint + X * 9000.0;
    HitActor = Trace(HitLocation, HitNormal, EndPoint, StartPoint, true);
    if (HitActor != None)
        EndPoint = HitLocation;

    Beam = Spawn(class'MutInfectionBeamEffect', self,, StartPoint, Rotator(EndPoint - StartPoint));
    if (Beam != None)
        Beam.SetBeamPoints(StartPoint, EndPoint);

    PlaySound(FireSound, SLOT_Interact);

    // Solo contagia si el rayo del disparo alcanza al objetivo real del Krall.
    HitPawn = Pawn(HitActor);
    if (HitPawn != None && HitPawn == IntendedTarget && HitPawn.Controller != None
        && HitPawn.Controller.bIsPlayer && HitPawn.PlayerReplicationInfo != None
        && HitPawn.Health > 0)
    {
        foreach AllActors(class'MutLeTransmitoTodoAMiBB', InfectionMutator)
        {
            InfectionMutator.InfectController(HitPawn.Controller);
            break;
        }
    }
}
