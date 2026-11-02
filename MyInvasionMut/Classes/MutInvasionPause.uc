class MutInvasionPause extends Mutator;

var bool bWaitingForAdmin;
var bool bWaveWasActive;
var bool bHappyHourSpeedActive;

function PostBeginPlay()
{
    SetTimer(1.0, true);
    Super.PostBeginPlay();
}

function bool IsHostOrAdmin(PlayerController PC)
{
    if (PC == None)
    {
        return false;
    }

    if (PC.PlayerReplicationInfo != None && PC.PlayerReplicationInfo.bAdmin)
    {
        return true;
    }

    if (Viewport(PC.Player) != None)
    {
        return true;
    }

    return false;
}

function NotifyHostOrAdmin(string Msg)
{
    local Controller C;
    local PlayerController PC;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        PC = PlayerController(C);
        if (IsHostOrAdmin(PC))
        {
            PC.ClientMessage(Msg, 'CriticalEvent');
        }
    }
}

// Cada host o admin ve la tecla que tiene asignada a 'mutate nextwave' (ver InvasionPauseMessage).
// Switch 0 muestra la linea fija y Switch 1 la saca.
function SendNextWaveHint(int Switch)
{
    local Controller C;
    local PlayerController PC;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        PC = PlayerController(C);
        if (IsHostOrAdmin(PC))
        {
            PC.ReceiveLocalizedMessage(class'InvasionPauseMessage', Switch);
        }
    }
}

function ApplyPauseSpeedBoost(bool bEnableBoost)
{
    local Controller C;
    local Pawn P;
    local float Multiplier;

    if (bEnableBoost)
    {
        Multiplier = 1.50;
    }
    else
    {
        Multiplier = 1.00;
    }

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        if (C.bIsPlayer && C.Pawn != None && C.Pawn.Health > 0 && Monster(C.Pawn) == None)
        {
            P = C.Pawn;
            P.GroundSpeed = P.Default.GroundSpeed * Multiplier;
            P.AirSpeed = P.Default.AirSpeed * Multiplier;
            P.WaterSpeed = P.Default.WaterSpeed * Multiplier;
            P.AccelRate = P.Default.AccelRate * Multiplier;
        }
    }

    bHappyHourSpeedActive = bEnableBoost;
}

function Mutate(string MutateString, PlayerController Sender)
{
    local Invasion InvGame;

    // Detecta el comando 'nextwave' ejecutado mediante 'mutate nextwave' (o asignado a la tecla Q)
    if (MutateString ~= "nextwave")
    {
        // Verifica si el jugador es el Host de la partida o Admin
        if (IsHostOrAdmin(Sender))
        {
            InvGame = Invasion(Level.Game);
            if (InvGame != None && bWaitingForAdmin)
            {
                bWaitingForAdmin = false;
                bWaveWasActive = false;
                ApplyPauseSpeedBoost(false);
                SendNextWaveHint(1);
                InvGame.WaveCountDown = 6; // Inicia cuenta regresiva de 5 segundos
                NotifyHostOrAdmin("Siguiente oleada iniciada! Velocidad normal restaurada.");
            }
        }
    }

    Super.Mutate(MutateString, Sender);
}

function Timer()
{
    local Invasion InvGame;

    InvGame = Invasion(Level.Game);

    if (InvGame != None)
    {
        // Registra cuando una oleada esta activa
        if (InvGame.bWaveInProgress)
        {
            bWaveWasActive = true;
            // Por si la oleada empezo sin 'mutate nextwave': sacar la linea fija
            if (bWaitingForAdmin)
            {
                SendNextWaveHint(1);
            }
            bWaitingForAdmin = false;
            if (bHappyHourSpeedActive)
            {
                ApplyPauseSpeedBoost(false);
            }
        }
        // Cuando la oleada termina (bWaveInProgress pasa a false y no quedan monstruos):
        // Esperamos a que WaveCountDown pase por 14 (recarga de armas) y 13 (revivir jugadores)
        // antes de congelar el temporizador en 12.
        else if (bWaveWasActive && InvGame.NumMonsters <= 0 && !bWaitingForAdmin)
        {
            if (InvGame.WaveNum >= InvGame.FinalWave)
            {
                bWaveWasActive = false;
            }
            else if (InvGame.WaveCountDown <= 12)
            {
                bWaveWasActive = false;
                bWaitingForAdmin = true;
                InvGame.WaveCountDown = 9999; // Congela el temporizador de la siguiente ronda
                ApplyPauseSpeedBoost(true);
                NotifyHostOrAdmin("Oleada limpiada! Velocidad +50%");
                SendNextWaveHint(0);
            }
        }

        // Mantiene la pausa y la super velocidad (+50%) mientras se espera la confirmacion
        if (bWaitingForAdmin)
        {
            if (InvGame.WaveCountDown < 9000)
            {
                InvGame.WaveCountDown = 9999;
            }
            ApplyPauseSpeedBoost(true);
        }
    }
}

defaultproperties
{
    GroupName="InvasionPause"
    FriendlyName="[Irreal] Control de plagas FV"
    Description="Pausa el inicio de la siguiente ola en Invasion y otorga +50% de velocidad durante la pausa para recolectar items. El host o un admin inicia la ola con el comando 'mutate nextwave' (para usar la tecla Q, escribir en la consola: set input Q mutate nextwave)."
}
