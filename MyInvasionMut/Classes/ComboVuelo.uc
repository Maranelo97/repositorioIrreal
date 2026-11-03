// Combo de GIGACHADrenalina: el jugador vuela libremente mientras dura (cuatro veces
// derecha). Usa el mismo modo de vuelo que el truco "fly" del juego: el estado
// PlayerFlying, en el servidor y en la maquina del jugador. Al terminar, vuelve a caminar
// (y cae si estaba en el aire).
// El modo de vuelo del juego ignora saltar y agacharse: GigaComboInteraction los lee en la
// maquina del jugador y avisa con "mutate gigafly 1/0/-1"; aca se aplica en el servidor.
class ComboVuelo extends Combo;

var int VerticalInput;   // 1 sube, -1 baja, 0 nada

// Velocidad para subir y bajar: tres cuartos de la velocidad de vuelo
static function float VerticalSpeed(Pawn P)
{
    return P.AirSpeed * 0.75;
}

simulated function Tick(float DeltaTime)
{
    local Pawn P;

    Super.Tick(DeltaTime);
    P = Pawn(Owner);
    if (!bDeleteMe && P != None && VerticalInput != 0 && P.Physics == PHYS_Flying)
        P.Velocity.Z = VerticalInput * VerticalSpeed(P);
}

function StartEffect(xPawn P)
{
    local PlayerController PC;

    PC = PlayerController(P.Controller);
    if (PC == None)
        return;

    PC.GotoState('PlayerFlying');
    if (Viewport(PC.Player) == None)
        PC.ClientGotoState('PlayerFlying', '');
}

function StopEffect(xPawn P)
{
    local PlayerController PC;

    PC = PlayerController(P.Controller);
    if (PC == None || P.Health <= 0)
        return;

    if (P.Physics == PHYS_Flying)
        P.SetPhysics(PHYS_Falling);

    if (PC.IsInState('PlayerFlying'))
    {
        PC.GotoState('PlayerWalking');
        if (Viewport(PC.Player) == None)
            PC.ClientGotoState('PlayerWalking', '');
    }
}

defaultproperties
{
    ExecMessage="Vuelo!"
    Duration=20.000000
    keys(0)=4
    keys(1)=4
    keys(2)=4
    keys(3)=4
}
