// En la maquina de cada jugador: lee las teclas de combo mientras hay uno activo (el juego
// las ignora en ese momento) y le avisa al servidor que combo se marco. El servidor decide:
// si es el mismo combo activo lo corta ("Cortar el combo repitiendo las teclas") y si es otro
// cambia a ese ("Encadenar combos"). Si no hay combo activo o recien empezo, ignora el aviso.
//
// Las teclas se leen por KeyEvent: a cada tecla se le pregunta al juego a que esta asignada
// (MoveForward, MoveBackward, StrafeLeft o StrafeRight), asi funciona con cualquier
// configuracion. (aForward/aStrafe no sirven aca: el juego los vuelve a cero en cada cuadro
// antes de que corra la interaccion.) El armado de la secuencia es el de xPlayer.PlayerTick.
//
// Tambien maneja el ascenso y descenso del combo Vuelo: el modo de vuelo del juego ignora
// saltar y agacharse, asi que mientras se vuela, saltar sube y agacharse baja. Se aplica
// aca (para que responda enseguida) y se le avisa al servidor, donde ComboVuelo hace lo mismo.
class GigaComboInteraction extends Interaction;

const MinComboKeyTime = 0.05;   // como en xPlayer: mas rapido que esto es una doble pulsacion
const MaxComboKeyTime = 0.35;   // como en xPlayer: tiempo maximo entre teclas

// Direcciones de combo, como en Combo.keys
const CK_Up = 1;
const CK_Down = 2;
const CK_Right = 4;   // aStrafe > 0
const CK_Left = 8;    // aStrafe < 0

// Teclas de subir y bajar volando (saltar y agacharse)
const FLY_Up = 16;
const FLY_Down = 32;

var int InputHistory[4];
var float LastKeyTime;
var byte KeyDir[256];      // direccion de cada tecla; 255 = no es de movimiento
var byte KeyChecked[256];  // 1 si ya se pregunto a que esta asignada
var byte KeyHeld[256];     // 1 mientras la tecla esta apretada (para ignorar la repeticion automatica)
var bool bFlyUpHeld, bFlyDownHeld;
var int SentVertical;      // ultimo valor de subir/bajar avisado al servidor

// Direccion de combo de la tecla (0 si no mueve), preguntando su asignacion una sola vez
function int DirectionOf(int KeyCode, PlayerController PC)
{
    local string KeyName, Binding;

    if (KeyCode < 0 || KeyCode > 255)
        return 0;
    if (KeyChecked[KeyCode] == 0)
    {
        KeyChecked[KeyCode] = 1;
        KeyDir[KeyCode] = 255;
        KeyName = PC.ConsoleCommand("KEYNAME" @ KeyCode);
        if (KeyName != "")
        {
            Binding = Caps(PC.ConsoleCommand("KEYBINDING" @ KeyName));
            if (InStr(Binding, "MOVEFORWARD") >= 0)
                KeyDir[KeyCode] = CK_Up;
            else if (InStr(Binding, "MOVEBACKWARD") >= 0)
                KeyDir[KeyCode] = CK_Down;
            else if (InStr(Binding, "STRAFELEFT") >= 0)
                KeyDir[KeyCode] = CK_Left;
            else if (InStr(Binding, "STRAFERIGHT") >= 0)
                KeyDir[KeyCode] = CK_Right;
            else if (InStr(Binding, "JUMP") >= 0)
                KeyDir[KeyCode] = FLY_Up;
            else if (InStr(Binding, "DUCK") >= 0 || InStr(Binding, "CROUCH") >= 0)
                KeyDir[KeyCode] = FLY_Down;
        }
    }
    if (KeyDir[KeyCode] == 255)
        return 0;
    return KeyDir[KeyCode];
}

function bool KeyEvent(out EInputKey Key, out EInputAction Action, float Delta)
{
    local xPlayer PC;
    local int Dir;

    if (ViewportOwner == None || int(Key) < 0 || int(Key) > 255)
        return false;

    // Al mantener una tecla, Windows repite el evento de apretar: solo cuenta la primera vez,
    // como en xPlayer (que solo cuenta las teclas que pasan de sueltas a apretadas)
    PC = xPlayer(ViewportOwner.Actor);
    if (Action == IST_Release)
    {
        KeyHeld[int(Key)] = 0;
        if (PC != None)
        {
            Dir = DirectionOf(int(Key), PC);
            if (Dir == FLY_Up)
                bFlyUpHeld = false;
            else if (Dir == FLY_Down)
                bFlyDownHeld = false;
            UpdateVertical(PC);
        }
        return false;
    }
    if (Action != IST_Press || KeyHeld[int(Key)] != 0)
        return false;
    KeyHeld[int(Key)] = 1;
    if (PC == None || PC.Pawn == None)
        return false;

    Dir = DirectionOf(int(Key), PC);
    if (Dir == FLY_Up)
        bFlyUpHeld = true;
    else if (Dir == FLY_Down)
        bFlyDownHeld = true;
    else if (Dir != 0)
        AddKey(Dir, PC);
    UpdateVertical(PC);
    return false;   // la tecla sigue su camino normal
}

// Subir (1), bajar (-1) o nada (0) segun las teclas apretadas, solo mientras se vuela
function int VerticalInput(PlayerController PC)
{
    local int V;

    if (PC == None || PC.Pawn == None || PC.Pawn.Physics != PHYS_Flying)
        return 0;
    if (bFlyUpHeld)
        V++;
    if (bFlyDownHeld)
        V--;
    return V;
}

// Le avisa al servidor cuando cambia (ComboVuelo lo aplica alla)
function UpdateVertical(PlayerController PC)
{
    local int V;

    V = VerticalInput(PC);
    if (V == SentVertical)
        return;
    SentVertical = V;
    PC.Mutate("gigafly " $ V);
}

// Aplica el subir/bajar en esta maquina, cuadro por cuadro, para que responda enseguida
function Tick(float DeltaTime)
{
    local PlayerController PC;
    local int V;

    if (ViewportOwner == None)
        return;
    PC = ViewportOwner.Actor;
    V = VerticalInput(PC);
    if (V != SentVertical)
        UpdateVertical(PC);
    if (V != 0)
        PC.Pawn.Velocity.Z = V * class'ComboVuelo'.static.VerticalSpeed(PC.Pawn);
}

function AddKey(int DiffKey, xPlayer PC)
{
    local int c, i;
    local bool bFullBuffer, bMatch;
    local float Now;

    Now = PC.Level.TimeSeconds;
    if (Now - LastKeyTime < MinComboKeyTime)
    {
        InputHistory[0] = InputHistory[0] | DiffKey;
        return;
    }
    if (Now - LastKeyTime > MaxComboKeyTime)
    {
        InputHistory[0] = DiffKey;
        InputHistory[1] = 0;
        LastKeyTime = Now;
        return;
    }

    bFullBuffer = true;
    for (i = 3; i > 0; i--)
    {
        InputHistory[i] = InputHistory[i - 1];
        if (InputHistory[i] == 0)
            bFullBuffer = false;
    }
    InputHistory[0] = DiffKey;
    LastKeyTime = Now;
    if (!bFullBuffer)
        return;

    for (c = 0; c < 16; c++)
    {
        if (PC.ComboList[c] == None)
            break;
        bMatch = true;
        for (i = 0; i < 4; i++)
        {
            if (InputHistory[i] != PC.ComboList[c].default.keys[i])
            {
                bMatch = false;
                break;
            }
        }
        if (bMatch)
        {
            PC.Mutate("gigacombo " $ string(PC.ComboList[c]));
            InputHistory[0] = 0;
            return;
        }
    }
}

// Las interacciones sobreviven al cambio de mapa: se quita sola para no duplicarse
event NotifyLevelChange()
{
    Master.RemoveInteraction(self);
}

defaultproperties
{
    bActive=True
    bVisible=False
    bRequiresTick=True
}
