class MutInvasionPause extends Mutator;

// Opciones de "Configurar mutadores"; quedan guardadas en el .ini del juego del host
var config int SpeedBonus;   // % de velocidad extra durante la pausa
var config int Countdown;    // segundos de cuenta regresiva despues de 'mutate nextwave'

var localized string SpeedBonusText, SpeedBonusDesc;
var localized string CountdownText, CountdownDesc;

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
        Multiplier = 1.0 + float(Clamp(SpeedBonus, 0, 200)) / 100.0;
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

    // Detecta el comando 'nextwave' ejecutado mediante 'mutate nextwave' (o asignado a una tecla)
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
                // Inicia la cuenta regresiva (5 segundos por defecto). Invasion empieza la oleada cuando
                // WaveCountDown llega a 1 o menos, asi que con 0 empieza en el siguiente segundo.
                InvGame.WaveCountDown = Clamp(Countdown, 0, 30) + 1;
                if (Clamp(SpeedBonus, 0, 200) > 0)
                    NotifyHostOrAdmin("Siguiente oleada iniciada! Velocidad normal restaurada.");
                else
                    NotifyHostOrAdmin("Siguiente oleada iniciada!");
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
                if (Clamp(SpeedBonus, 0, 200) > 0)
                    NotifyHostOrAdmin("Oleada limpiada! Velocidad +" $ Clamp(SpeedBonus, 0, 200) $ "%");
                else
                    NotifyHostOrAdmin("Oleada limpiada!");
                SendNextWaveHint(0);
            }
        }

        // Mantiene la pausa y la velocidad extra mientras se espera la confirmacion
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

static function FillPlayInfo(PlayInfo PlayInfo)
{
    Super.FillPlayInfo(PlayInfo);
    PlayInfo.AddSetting(default.RulesGroup, "SpeedBonus", default.SpeedBonusText, 0, 1, "Text", "3;0:200");
    // Solo se ve con "Ver opciones avanzadas" (ultimo parametro de AddSetting)
    PlayInfo.AddSetting(default.RulesGroup, "Countdown", default.CountdownText, 0, 2, "Text", "2;0:30", , , True);
}

static event string GetDescriptionText(string PropName)
{
    switch (PropName)
    {
        case "SpeedBonus": return default.SpeedBonusDesc;
        case "Countdown":  return default.CountdownDesc;
    }
    return Super.GetDescriptionText(PropName);
}

defaultproperties
{
    // Manda este paquete a los jugadores que se conectan: sin esto, a ellos no les llega nada
    // de lo que se dibuja o pasa en su maquina (radar, Vision, mensajes, armas con adrenalina...)
    bAddToServerPackages=True
    SpeedBonus=50
    Countdown=5
    SpeedBonusText="Velocidad extra en la pausa (%)"
    SpeedBonusDesc="Cuanto mas rapido se mueven los jugadores mientras esperan la siguiente oleada (de 0 a 200, 0 = sin velocidad extra) [por defecto: 50]"
    CountdownText="Cuenta regresiva (segundos)"
    CountdownDesc="Segundos que tarda en empezar la oleada despues de usar 'mutate nextwave' (de 0 a 30, 0 = enseguida) [por defecto: 5]"
    GroupName="InvasionPause"
    FriendlyName="[Irreal] Control de plagas FV"
    Description="Pausa el inicio de la siguiente ola en Invasion y otorga +50% de velocidad durante la pausa para recolectar items. El host o un admin inicia la ola con el comando 'mutate nextwave' (para usar la tecla Q, escribir en la consola: set input Q mutate nextwave). La velocidad extra y la cuenta regresiva (5 segundos) se pueden cambiar en Configurar mutadores."
}
