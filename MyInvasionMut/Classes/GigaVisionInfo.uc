// Lo crea el combo Vision. Solo le llega al jugador que hizo el combo (su duenio) con la
// posicion, la velocidad y el tipo de cada marca (monstruo, otro jugador humano, el Rey
// Cthulhu o un pickup importante que puede agarrar), y en su maquina agrega GigaVisionOverlay
// al HUD. Entre actualizaciones, cada
// posicion se mueve segun su velocidad para que los marcos no salten. (En el host el
// overlay usa directamente los pawns, con la misma clasificacion de MarkTypeFor.)
class GigaVisionInfo extends Info;

const MaxMarks = 48;

// Tipos de marca
const MARK_None = -1;
const MARK_Monster = 0;
const MARK_Human = 1;
const MARK_Champion = 2;
const MARK_Pickup = 3;

const PillClusterRadius = 400.0;   // pastillas de adrenalina a esta distancia cuentan como un grupo
const PillClusterMin = 4;          // pastillas necesarias para marcar el grupo

var vector MarkPos[MaxMarks];
var vector MarkVel[MaxMarks];
var byte MarkType[MaxMarks];
var byte MarkHealth[MaxMarks];   // vida de 0 a 2 (ver HealthFraction) guardada de 0 a 255
var byte MarkShield[MaxMarks];   // escudo de 0 a 1 (ver ShieldFraction) guardado de 0 a 255
var byte NumMarks;
var float ReceivedTime;   // cuando llego la ultima actualizacion
var GigaVisionOverlay Overlay;

replication
{
    reliable if (Role == ROLE_Authority)
        MarkPos, MarkVel, MarkType, MarkHealth, MarkShield, NumMarks;
}

// Que marca lleva P para quien hizo el combo (Viewer). Solo sirve en el servidor: el Tag
// del Rey Cthulhu no llega a los clientes.
static function int MarkTypeFor(Pawn P, Controller Viewer)
{
    if (P == None || P.Health <= 0)
        return MARK_None;
    if (Monster(P) != None)
    {
        if (P.Tag == 'ChampionMonster')
            return MARK_Champion;
        return MARK_Monster;
    }
    // Otros jugadores humanos (ni bots ni uno mismo)
    if (P.PlayerReplicationInfo != None && !P.PlayerReplicationInfo.bBot && P.Controller != Viewer)
        return MARK_Human;
    return MARK_None;
}

// Pickups que vale la pena marcar, y solo si Viewer los puede agarrar ahora: el barril de
// vida, los escudos, el Double Damage y las armas ultimas (si no la tiene ya, ni la uso esta
// oleada con Murio una banda de gente). Los que estan esperando reaparecer quedan ocultos (bHidden).
// Las pastillas de adrenalina se marcan aparte, por grupos (ver UpdateMarks).
static function bool PickupMarked(Pickup PU, Pawn Viewer)
{
    if (PU == None || PU.bHidden || Viewer == None || Viewer.Health <= 0)
        return false;
    if (SuperHealthPack(PU) != None)
        return Viewer.Health < Viewer.SuperHealthMax;
    if (ShieldPickup(PU) != None)
        return Viewer.CanUseShield(ShieldPickup(PU).ShieldAmount) > 0;
    if (UDamagePack(PU) != None)
        return true;
    if (WeaponPickup(PU) != None && IsUltimateWeapon(PU.InventoryType))
        return Viewer.FindInventoryType(PU.InventoryType) == None && !UsedUltimateThisWave(PU, Viewer);
    return false;
}

static function bool IsUltimateWeapon(class<Inventory> InvClass)
{
    return ClassIsChildOf(InvClass, class'XWeapons.Redeemer')
        || ClassIsChildOf(InvClass, class'XWeapons.Painter')
        || ClassIsChildOf(InvClass, class'XWeapons.SniperRifle');
}

// Murio una banda de gente con "Recogerla varias veces por oleada" desactivada: ya la agarro esta oleada
static function bool UsedUltimateThisWave(Pickup PU, Pawn Viewer)
{
    local GameRules G;
    local UltimatesRules R;

    for (G = PU.Level.Game.GameRulesModifiers; G != None; G = G.NextGameRules)
    {
        R = UltimatesRules(G);
        if (R != None)
            return R.IsUltimatePickup(PU) && R.UltimatesMut != None && !R.UltimatesMut.bRepeatPickup
                && R.HasPickedUp(Viewer.Controller);
    }
    return false;
}

// Vida de P como porcentaje de su vida maxima: de 0 a 1 para los monstruos y de 0 a 2 para
// los jugadores (pasan de 100 con el barril o las pastillas de vida, hasta 199). Los
// monstruos no cambian HealthMax (queda en 100 para todos), asi que se usa la vida con la que
// aparece cada uno. El Rey Cthulhu si recibe su HealthMax al aparecer, y los jugadores usan el
// suyo. (El Tag del Rey Cthulhu solo existe en el servidor, que es donde se calcula.)
static function float HealthFraction(Pawn P)
{
    local float MaxHealth;

    if (Monster(P) != None)
    {
        if (P.Tag == 'ChampionMonster')
            MaxHealth = P.HealthMax;
        else
            MaxHealth = P.default.Health;
        if (MaxHealth <= 0)
            return 1.0;
        return FClamp(float(P.Health) / MaxHealth, 0.0, 1.0);
    }
    if (P.HealthMax <= 0)
        return 1.0;
    return FClamp(float(P.Health) / P.HealthMax, 0.0, 2.0);
}

// Escudo de P como porcentaje del maximo (de 0 a 1)
static function float ShieldFraction(Pawn P)
{
    local xPawn X;

    X = xPawn(P);
    if (X == None || X.ShieldStrengthMax <= 0)
        return 0.0;
    return FClamp(X.ShieldStrength / X.ShieldStrengthMax, 0.0, 1.0);
}

function PostBeginPlay()
{
    Super.PostBeginPlay();
    UpdateMarks();
    SetTimer(0.1, true);
}

function Timer()
{
    UpdateMarks();
}

function UpdateMarks()
{
    local Pawn P, Viewer;
    local Pickup PU;
    local array<vector> Pills;
    local array<byte> Grouped;
    local vector Center;
    local int N, Type, i, j, Count;

    foreach DynamicActors(class'Pawn', P)
    {
        Type = MarkTypeFor(P, Controller(Owner));
        if (Type == MARK_None)
            continue;
        MarkPos[N] = P.Location;
        MarkVel[N] = P.Velocity;
        MarkType[N] = Type;
        MarkHealth[N] = byte(HealthFraction(P) * 127.5);
        MarkShield[N] = byte(ShieldFraction(P) * 255.0);
        N++;
        if (N >= MaxMarks)
            break;
    }

    // Pickups que puede agarrar quien hizo el combo
    if (Controller(Owner) != None)
        Viewer = Controller(Owner).Pawn;
    if (Viewer != None)
    {
        foreach DynamicActors(class'Pickup', PU)
        {
            if (N >= MaxMarks)
                break;
            if (AdrenalinePickup(PU) != None)
            {
                if (!PU.bHidden && Viewer.Controller.NeedsAdrenaline())
                    Pills[Pills.Length] = PU.Location;
                continue;
            }
            if (!PickupMarked(PU, Viewer))
                continue;
            MarkPos[N] = PU.Location;
            MarkVel[N] = vect(0, 0, 0);
            MarkType[N] = MARK_Pickup;
            N++;
        }

        // Pastillas de adrenalina: una marca en el centro de cada grupo de varias juntas
        Grouped.Length = Pills.Length;
        for (i = 0; i < Pills.Length && N < MaxMarks; i++)
        {
            if (Grouped[i] != 0)
                continue;
            Count = 0;
            Center = vect(0, 0, 0);
            for (j = 0; j < Pills.Length; j++)
            {
                if (Grouped[j] == 0 && VSize(Pills[j] - Pills[i]) <= PillClusterRadius)
                {
                    Count++;
                    Center += Pills[j];
                }
            }
            if (Count < PillClusterMin)
                continue;
            for (j = 0; j < Pills.Length; j++)
                if (Grouped[j] == 0 && VSize(Pills[j] - Pills[i]) <= PillClusterRadius)
                    Grouped[j] = 1;
            MarkPos[N] = Center / Count;
            MarkVel[N] = vect(0, 0, 0);
            MarkType[N] = MARK_Pickup;
            N++;
        }
    }
    NumMarks = N;
    ReceivedTime = Level.TimeSeconds;
    NetUpdateTime = Level.TimeSeconds - 1;
}

simulated event PostNetReceive()
{
    ReceivedTime = Level.TimeSeconds;
}

// El overlay no puede leer los arreglos enteros desde afuera (son muy grandes para el
// compilador), asi que los lee de a uno con estas funciones.
// Posicion estimada ahora: la ultima recibida mas lo que se movio desde entonces
simulated function vector GetPos(int i)
{
    return MarkPos[i] + MarkVel[i] * FClamp(Level.TimeSeconds - ReceivedTime, 0.0, 0.3);
}

simulated function int GetType(int i)
{
    return MarkType[i];
}

simulated function float GetHealth(int i)
{
    return float(MarkHealth[i]) / 127.5;
}

simulated function float GetShield(int i)
{
    return float(MarkShield[i]) / 255.0;
}

simulated function Tick(float DeltaTime)
{
    local PlayerController PC;

    if (Level.NetMode == NM_DedicatedServer)
    {
        Disable('Tick');
        return;
    }

    // En el host tambien existe la de los demas jugadores: solo dibuja la propia. A un
    // cliente solo le llega la suya (bOnlyRelevantToOwner), asi que ahi no se mira Owner: en
    // los Info no se replica (bSkipActorPropertyReplication) y en el cliente queda en None.
    PC = Level.GetLocalPlayerController();
    if (PC == None || PC.myHUD == None)
        return;
    if (Level.NetMode != NM_Client && PC != Owner)
        return;

    if (Overlay != None && !Overlay.bDeleteMe && Overlay.Owner == PC.myHUD)
        return;

    if (Overlay != None)
        Overlay.Destroy();

    Overlay = Spawn(class'GigaVisionOverlay', PC.myHUD);
    if (Overlay != None)
    {
        Overlay.Info = self;
        PC.myHUD.AddHudOverlay(Overlay);
    }
}

simulated function Destroyed()
{
    if (Overlay != None)
        Overlay.Destroy();
    Super.Destroyed();
}

defaultproperties
{
    bOnlyRelevantToOwner=True
    bNetNotify=True
    bAlwaysRelevant=False
    RemoteRole=ROLE_SimulatedProxy
    NetUpdateFrequency=10.0
}
