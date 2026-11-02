class MutLeTransmitoTodoAMiBB extends Mutator;

var int CurrentWaveNum;
var float InfectionChance;
var float InfectionRadius;
var float CureTime;
var float CureCheckInterval;

function PostBeginPlay()
{
    Super.PostBeginPlay();
    CurrentWaveNum = -1;
    if (Invasion(Level.Game) != None)
        SetTimer(CureCheckInterval, true);
}

function InfectController(Controller TargetController)
{
    local MutInfectionStatus Status;
    local Invasion InvGame;

    InvGame = Invasion(Level.Game);
    // WaveNum empieza en 0: el valor 8 es la oleada 9 que se ve en pantalla.
    if (InvGame == None || !InvGame.bWaveInProgress || InvGame.WaveNum < 8
        || TargetController == None || !TargetController.bIsPlayer
        || TargetController.Pawn == None || TargetController.Pawn.Health <= 0
        || TargetController.PlayerReplicationInfo == None)
    {
        return;
    }

    foreach AllActors(class'MutInfectionStatus', Status)
    {
        if (Status.InfectedController == TargetController)
            return;
    }

    Status = Spawn(class'MutInfectionStatus');
    if (Status != None)
        Status.Initialize(TargetController, self);
}

function bool IsBeingCured(Controller C, MutInfectionStatus Status)
{
    local Pawn Healer, Patient;
    local Weapon W;
    local vector StartTrace, EndTrace, HitLocation, HitNormal;
    local Actor HitActor;

    if (C == None || Status == None || Status.InfectedController == None)
        return false;

    Healer = C.Pawn;
    Patient = Status.InfectedController.Pawn;
    if (Healer == None || Patient == None || Healer == Patient || Healer.Health <= 0)
        return false;

    W = Healer.Weapon;
    if (W == None || !W.IsA('LinkGun') || W.GetFireMode(1) == None || !W.GetFireMode(1).bIsFiring)
        return false;
    StartTrace = Healer.Location + Healer.EyePosition();
    EndTrace = StartTrace + Vector(C.Rotation) * 1200.0;
    HitActor = Healer.Trace(HitLocation, HitNormal, EndTrace, StartTrace, true);
    return HitActor == Patient;
}

function CheckCures()
{
    local MutInfectionStatus Status;
    local Controller C, Curer;

    foreach AllActors(class'MutInfectionStatus', Status)
    {
        Curer = None;
        for (C = Level.ControllerList; C != None; C = C.NextController)
        {
            if (IsBeingCured(C, Status))
            {
                Curer = C;
                break;
            }
        }

        if (Curer == None)
        {
            Status.CureProgress = 0.0;
            Status.CuringController = None;
        }
        else if (Status.CuringController == Curer)
            Status.CureProgress += CureCheckInterval;
        else
        {
            Status.CuringController = Curer;
            Status.CureProgress = CureCheckInterval;
        }

        if (Status.CureProgress >= CureTime)
            Status.Cure();
    }
}

function SpreadInfection()
{
    local MutInfectionStatus Status;
    local Controller C;
    local Pawn InfectedPawn;

    foreach AllActors(class'MutInfectionStatus', Status)
    {
        if (Status.InfectedController == None)
            continue;

        InfectedPawn = Status.InfectedController.Pawn;
        if (InfectedPawn == None || InfectedPawn.Health <= 0)
            continue;

        for (C = Level.ControllerList; C != None; C = C.NextController)
        {
            if (C != Status.InfectedController && C.bIsPlayer && C.Pawn != None
                && C.Pawn.Health > 0 && C.PlayerReplicationInfo != None
                && VSize(C.Pawn.Location - InfectedPawn.Location) <= InfectionRadius)
            {
                InfectController(C);
            }
        }
    }
}

function CureAllInfected()
{
    local MutInfectionStatus Status;
    foreach AllActors(class'MutInfectionStatus', Status)
        Status.Cure();
}

function Monster SpawnEliteKrall(Invasion InvGame)
{
    local NavigationPoint StartSpot;
    local Controller C;
    local vector SpawnLoc;
    local MutInfectionEliteKrall NewElite;
    local int Attempt;
    local float MinDistance;

    for (Attempt = 0; Attempt < 12; Attempt++)
    {
        StartSpot = InvGame.FindPlayerStart(None, 1);
        if (StartSpot == None)
            continue;

        if (Attempt < 8)
            MinDistance = 550.0;
        else
            MinDistance = 220.0;

        for (C = Level.ControllerList; C != None; C = C.NextController)
        {
            if (C.bIsPlayer && C.Pawn != None && C.Pawn.Health > 0
                && VSize(C.Pawn.Location - StartSpot.Location) < MinDistance)
                break;
        }
        if (C != None)
            continue;

        SpawnLoc = StartSpot.Location + (class'MutInfectionEliteKrall'.Default.CollisionHeight - StartSpot.CollisionHeight) * vect(0,0,1);
        NewElite = Spawn(class'MutInfectionEliteKrall',,, SpawnLoc, StartSpot.Rotation);
        if (NewElite != None)
        {
            NewElite.PlayTeleportEffect(true, true);
            InvGame.WaveMonsters++;
            InvGame.NumMonsters++;
            return NewElite;
        }
    }
    return None;
}

function Timer()
{
    local Invasion InvGame;

    InvGame = Invasion(Level.Game);
    if (InvGame == None)
        return;

    // Limpia cualquier infeccion de la ronda anterior antes de permitir contagios en la nueva.
    if (InvGame.bWaveInProgress && InvGame.WaveNum != CurrentWaveNum)
    {
        CureAllInfected();
        CurrentWaveNum = InvGame.WaveNum;
        if (CurrentWaveNum >= 8 && FRand() < InfectionChance)
            SpawnEliteKrall(InvGame);
    }

    CheckCures();
    SpreadInfection();
}

defaultproperties
{
    InfectionChance=0.3
    InfectionRadius=180.0
    CureTime=10.0
    CureCheckInterval=0.25
    GroupName="LeTransmitoTodoAMiBB"
    FriendlyName="[Irreal] Le transmito todo a mi BB"
    Description="Desde la oleada 9, cada oleada tiene 30% de probabilidad de que aparezca un Elite Krall cuyo rayo no hace dano pero infecta (-1 HP por segundo). La infeccion se contagia por cercania y se cura apuntando 10 segundos seguidos con el disparo secundario de la Entrelazadora. Las infecciones se curan al empezar cada oleada."
}
