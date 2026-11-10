class MutInvasionPause extends Mutator;

// Opciones de "Configurar mutadores"; quedan guardadas en el .ini del juego del host
var config int SpeedBonus;   // % de velocidad extra durante la pausa
var config int Countdown;    // segundos de cuenta regresiva despues de 'mutate nextwave'
var config bool bLateBoost;  // desde la oleada LateBoostWave, maximos mas altos (y todo lleno al empezar)
var config int LateBoostWave;    // primera oleada con los maximos mas altos
var config int LateBoostPercent; // cuanto suben los maximos (100 = el doble)

var localized string SpeedBonusText, SpeedBonusDesc;
var localized string CountdownText, CountdownDesc;
var localized string LateBoostText, LateBoostDesc;
var localized string LateBoostWaveText, LateBoostWaveDesc;
var localized string LateBoostPercentText, LateBoostPercentDesc;

// Maximos mas altos en las ultimas oleadas. La municion maxima es de la clase de municion (igual
// para todos), asi que se cambia el valor por defecto de cada clase y se devuelve al cambiar de mapa.
var bool bLateBoostActive;
var array< class<Ammunition> > BoostedAmmo;
var array<int> BoostedAmmoOriginal;

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

// ---- Maximos mas altos en las ultimas oleadas ----

function float LateBoostFactor()
{
    return 1.0 + float(Clamp(LateBoostPercent, 1, 300)) / 100.0;
}

// Sube la municion maxima de una clase una sola vez (se anota el valor original)
function BoostAmmoClass(class<Ammunition> A)
{
    local int i;

    if (A == None)
        return;
    for (i = 0; i < BoostedAmmo.Length; i++)
        if (BoostedAmmo[i] == A)
            return;
    i = BoostedAmmo.Length;
    BoostedAmmo[i] = A;
    BoostedAmmoOriginal[i] = A.default.MaxAmmo;
    A.default.MaxAmmo = int(float(A.default.MaxAmmo) * LateBoostFactor() + 0.5);
}

// Sube la municion maxima de las armas que tiene este pawn. Las de GIGACHADrenalina gastan
// adrenalina, asi que no se tocan.
function BoostPawnAmmo(Pawn P, bool bFill)
{
    local Inventory Inv;
    local Weapon W;

    for (Inv = P.Inventory; Inv != None; Inv = Inv.Inventory)
    {
        W = Weapon(Inv);
        if (W == None || class'MutGigachadrenalina'.static.IsAdrenalineWeapon(W.Class))
            continue;
        BoostAmmoClass(W.AmmoClass[0]);
        BoostAmmoClass(W.AmmoClass[1]);
        if (bFill)
            W.MaxOutAmmo();
    }
}

// Vida, escudo y adrenalina maximos mas altos para este jugador o bot. Con bFill tambien se los
// llena (al empezar la oleada y al aparecer).
function BoostPawn(Pawn P, bool bFill)
{
    local float F;

    if (P == None || P.Controller == None || !P.Controller.bIsPlayer || Monster(P) != None)
        return;

    F = LateBoostFactor();
    P.HealthMax = P.default.HealthMax * F;
    P.SuperHealthMax = P.default.SuperHealthMax * F;
    if (xPawn(P) != None)
        xPawn(P).ShieldStrengthMax = xPawn(P).default.ShieldStrengthMax * F;
    P.Controller.AdrenalineMax = P.Controller.default.AdrenalineMax * F;

    if (bFill)
    {
        // La vida va al maximo posible (el de las pastillas y el Super Keg), no solo al normal
        P.Health = Max(P.Health, int(P.SuperHealthMax));
        P.AddShieldStrength(int(P.GetShieldStrengthMax()));
        if (P.Controller.bAdrenalineEnabled)
            P.Controller.Adrenaline = P.Controller.AdrenalineMax;
    }
    BoostPawnAmmo(P, bFill);
}

// Al empezar el descanso antes de la oleada elegida: a todos los vivos, y todo lleno
function StartLateBoost()
{
    local Controller C;
    local string Amount;

    bLateBoostActive = true;
    for (C = Level.ControllerList; C != None; C = C.NextController)
        if (C.bIsPlayer && C.Pawn != None && C.Pawn.Health > 0)
            BoostPawn(C.Pawn, true);

    if (Clamp(LateBoostPercent, 1, 300) == 100)
        Amount = "el doble";
    else
        Amount = "+" $ Clamp(LateBoostPercent, 1, 300) $ "%";
    Level.Game.Broadcast(self, class'MutChatDokaBots'.static.FixAccents("¡Últimas oleadas! Vida, escudo, munición y adrenalina máximas: ") $ Amount);
}

// Los que aparecen despues (al revivir o entre oleadas) tambien tienen los maximos mas altos y
// empiezan con la vida llena
function ModifyPlayer(Pawn Other)
{
    if (bLateBoostActive)
        BoostPawn(Other, false);
    if (bLateBoostActive && Other != None && Other.Health > 0 && Monster(Other) == None)
        Other.Health = Max(Other.Health, int(Other.HealthMax));
    Super.ModifyPlayer(Other);
}

function BoostAllAmmo()
{
    local Controller C;

    for (C = Level.ControllerList; C != None; C = C.NextController)
        if (C.bIsPlayer && C.Pawn != None && Monster(C.Pawn) == None)
            BoostPawnAmmo(C.Pawn, false);
}

function RestoreAmmoClasses()
{
    local int i;

    for (i = 0; i < BoostedAmmo.Length; i++)
        if (BoostedAmmo[i] != None)
            BoostedAmmo[i].default.MaxAmmo = BoostedAmmoOriginal[i];
    BoostedAmmo.Length = 0;
    BoostedAmmoOriginal.Length = 0;
}

// Al cambiar de mapa se devuelven los maximos de municion originales (los valores por defecto de
// las clases duran hasta cerrar el juego)
function ServerTraveling(string URL, bool bItems)
{
    RestoreAmmoClasses();
    Super.ServerTraveling(URL, bItems);
}

function Destroyed()
{
    RestoreAmmoClasses();
    Super.Destroyed();
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
        // Maximos mas altos desde el descanso antes de la oleada elegida: al terminar una oleada,
        // WaveNum (que empieza en 0) ya es la que viene. Despues, las armas que alguien levante
        // tambien suben su municion maxima.
        if (bLateBoost && !bLateBoostActive && InvGame.WaveNum + 1 >= Clamp(LateBoostWave, 1, 99))
            StartLateBoost();
        else if (bLateBoostActive)
            BoostAllAmmo();

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
    PlayInfo.AddSetting(default.RulesGroup, "bLateBoost", default.LateBoostText, 0, 3, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "LateBoostWave", default.LateBoostWaveText, 0, 4, "Text", "2;1:99", , , True);
    PlayInfo.AddSetting(default.RulesGroup, "LateBoostPercent", default.LateBoostPercentText, 0, 5, "Text", "3;1:300", , , True);
}

static event string GetDescriptionText(string PropName)
{
    switch (PropName)
    {
        case "SpeedBonus": return default.SpeedBonusDesc;
        case "Countdown":  return default.CountdownDesc;
        case "bLateBoost": return default.LateBoostDesc;
        case "LateBoostWave": return default.LateBoostWaveDesc;
        case "LateBoostPercent": return default.LateBoostPercentDesc;
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
    bLateBoost=True
    LateBoostWave=15
    LateBoostPercent=100
    LateBoostText="Maximos mas altos en las ultimas oleadas"
    LateBoostDesc="Desde la oleada elegida (15 por defecto), la vida, el escudo, la municion y la adrenalina maximas de los jugadores y los bots suben (al doble por defecto), y en el descanso antes de esa oleada se llenan [por defecto: activada]"
    LateBoostWaveText="Oleada de los maximos mas altos"
    LateBoostWaveDesc="Primera oleada en la que suben los maximos (de 1 a 99) [por defecto: 15]"
    LateBoostPercentText="Aumento de los maximos (%)"
    LateBoostPercentDesc="Cuanto suben la vida, el escudo, la municion y la adrenalina maximas: 100 es el doble (de 1 a 300) [por defecto: 100]"
    SpeedBonusText="Velocidad extra en la pausa (%)"
    SpeedBonusDesc="Cuanto mas rapido se mueven los jugadores mientras esperan la siguiente oleada (de 0 a 200, 0 = sin velocidad extra) [por defecto: 50]"
    CountdownText="Cuenta regresiva (segundos)"
    CountdownDesc="Segundos que tarda en empezar la oleada despues de usar 'mutate nextwave' (de 0 a 30, 0 = enseguida) [por defecto: 5]"
    GroupName="InvasionPause"
    FriendlyName="[Irreal] Control de plagas FV"
    Description="Pausa el inicio de la siguiente ola en Invasion y otorga +50% de velocidad durante la pausa para recolectar items. El host o un admin inicia la ola con el comando 'mutate nextwave' (para usar la tecla Q, escribir en la consola: set input Q mutate nextwave). Desde el descanso antes de la oleada 15, la vida, el escudo, la municion y la adrenalina maximas son el doble, y en ese momento se llenan. Todo se puede cambiar en Configurar mutadores. (Ver 1.4.2)"
}
