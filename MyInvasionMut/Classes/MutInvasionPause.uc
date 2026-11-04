class MutInvasionPause extends Mutator;

// Opciones de "Configurar mutadores"; quedan guardadas en el .ini del juego del host
var config int SpeedBonus;   // % de velocidad extra durante la pausa
var config int Countdown;    // segundos de cuenta regresiva despues de 'mutate nextwave'

var localized string SpeedBonusText, SpeedBonusDesc;
var localized string CountdownText, CountdownDesc;

var bool bWaitingForAdmin;
var bool bWaveWasActive;

// Jugadores con la velocidad extra de la pausa: lo que tenian antes (se devuelve al terminar)
// y la velocidad que les puso la pausa, para saber si despues otra cosa la cambio
struct BoostEntry
{
    var Pawn P;
    var float GroundSpeed, AirSpeed, WaterSpeed, AccelRate;
    var float BoostedGroundSpeed;
};
var array<BoostEntry> Boosted;

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

// Hay algun host o admin que pueda terminar la pausa con 'mutate nextwave'?
function bool HasAuthorizedPlayer()
{
    local Controller C;

    for (C = Level.ControllerList; C != None; C = C.NextController)
        if (IsHostOrAdmin(PlayerController(C)))
            return true;
    return false;
}

function int BoostIndex(Pawn P)
{
    local int i;

    for (i = 0; i < Boosted.Length; i++)
        if (Boosted[i].P == P)
            return i;
    return -1;
}

// Pone la velocidad extra a cada jugador vivo que todavia no la tiene, multiplicando su
// velocidad actual (asi se respeta lo que hayan cambiado otros mutadores o combos). Se llama
// en cada segundo de la pausa, pero solo escribe cuando hace falta: a quien acaba de
// aparecer o a quien otra cosa le cambio la velocidad (por ejemplo, al terminar un combo).
function UpdatePauseSpeed()
{
    local Controller C;
    local Pawn P;
    local float Multiplier;
    local int i;

    Multiplier = 1.0 + float(Clamp(SpeedBonus, 0, 200)) / 100.0;
    if (Multiplier == 1.0)
        return;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        if (!C.bIsPlayer || C.Pawn == None || C.Pawn.Health <= 0 || Monster(C.Pawn) != None)
            continue;
        P = C.Pawn;
        i = BoostIndex(P);
        if (i >= 0 && P.GroundSpeed == Boosted[i].BoostedGroundSpeed)
            continue;
        if (i < 0)
        {
            i = Boosted.Length;
            Boosted.Length = i + 1;
            Boosted[i].P = P;
        }
        Boosted[i].GroundSpeed = P.GroundSpeed;
        Boosted[i].AirSpeed = P.AirSpeed;
        Boosted[i].WaterSpeed = P.WaterSpeed;
        Boosted[i].AccelRate = P.AccelRate;
        P.GroundSpeed *= Multiplier;
        P.AirSpeed *= Multiplier;
        P.WaterSpeed *= Multiplier;
        P.AccelRate *= Multiplier;
        Boosted[i].BoostedGroundSpeed = P.GroundSpeed;
    }
}

// Devuelve la velocidad que cada jugador tenia antes de la pausa. Si otra cosa la cambio
// durante la pausa, se deja como esta.
function RemovePauseSpeed()
{
    local Pawn P;
    local int i;

    for (i = 0; i < Boosted.Length; i++)
    {
        P = Boosted[i].P;
        if (P == None || P.bDeleteMe || P.GroundSpeed != Boosted[i].BoostedGroundSpeed)
            continue;
        P.GroundSpeed = Boosted[i].GroundSpeed;
        P.AirSpeed = Boosted[i].AirSpeed;
        P.WaterSpeed = Boosted[i].WaterSpeed;
        P.AccelRate = Boosted[i].AccelRate;
    }
    Boosted.Length = 0;
}

// Termina la pausa y arranca la cuenta regresiva de la oleada siguiente
function EndPause(Invasion InvGame)
{
    bWaitingForAdmin = false;
    bWaveWasActive = false;
    RemovePauseSpeed();
    SendNextWaveHint(1);
    // Inicia la cuenta regresiva (5 segundos por defecto). Invasion empieza la oleada cuando
    // WaveCountDown llega a 1 o menos, asi que con 0 empieza en el siguiente segundo.
    InvGame.WaveCountDown = Clamp(Countdown, 0, 30) + 1;
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
                EndPause(InvGame);
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
            if (Boosted.Length > 0)
            {
                RemovePauseSpeed();
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
                UpdatePauseSpeed();
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
            // Si ya no queda ningun host ni admin, nadie podria terminarla: sigue sola
            if (!HasAuthorizedPlayer())
            {
                EndPause(InvGame);
                Level.Game.Broadcast(self, "No hay host ni admin: la siguiente oleada empieza sola.");
                return;
            }
            if (InvGame.WaveCountDown < 9000)
            {
                InvGame.WaveCountDown = 9999;
            }
            UpdatePauseSpeed();
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
