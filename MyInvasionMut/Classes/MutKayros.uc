class MutKayros extends Mutator;

// En cada oleada elige a un jugador humano al azar y le da Mucho Kayros (hace mas dano y
// recibe menos) o Poco Kayros (hace menos dano y recibe mas). El dano se cambia en
// KayrosRules.NetDamage, con los porcentajes de las opciones.

var int CurrentWaveNum;
var PlayerController ChosenPlayer;
var PlayerController PreviousChosenPlayer;
var int KayrosState; // 0 = Ninguno, 1 = Mucho Kayros, 2 = Poco Kayros

// Opciones de "Configurar mutadores"; quedan guardadas en el .ini del juego del host
var config int DamageDealtPercent;      // cuanto cambia el dano que hace el elegido
var config int DamageReceivedPercent;   // cuanto cambia el dano que recibe el elegido

var localized string DamageDealtText, DamageDealtDesc;
var localized string DamageReceivedText, DamageReceivedDesc;

function PostBeginPlay()
{
    local KayrosRules GR;

    Super.PostBeginPlay();

    CurrentWaveNum = -1;

    GR = Spawn(class'KayrosRules');
    if (Level.Game != None && GR != None)
    {
        GR.KayrosMut = self;
        if (Level.Game.GameRulesModifiers == None)
        {
            Level.Game.GameRulesModifiers = GR;
        }
        else
        {
            Level.Game.GameRulesModifiers.AddGameRules(GR);
        }
    }

    SetTimer(0.5, true);
}

// Nunca afecta a bots, solo al unico jugador humano elegido en esta oleada (tambien si va en
// un vehiculo, porque lo controla el mismo jugador)
function bool IsChosenPawn(Pawn P)
{
    return P != None && ChosenPlayer != None && KayrosState != 0 && P.Controller == ChosenPlayer;
}

// Mucho Kayros: hace mas dano. Poco Kayros: hace menos
function float GetDealtFactor()
{
    if (KayrosState == 1)
        return 1.0 + Clamp(DamageDealtPercent, 0, 90) / 100.0;
    if (KayrosState == 2)
        return 1.0 - Clamp(DamageDealtPercent, 0, 90) / 100.0;
    return 1.0;
}

// Mucho Kayros: recibe menos dano. Poco Kayros: recibe mas
function float GetReceivedFactor()
{
    if (KayrosState == 1)
        return 1.0 - Clamp(DamageReceivedPercent, 0, 90) / 100.0;
    if (KayrosState == 2)
        return 1.0 + Clamp(DamageReceivedPercent, 0, 90) / 100.0;
    return 1.0;
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
    Super.FillPlayInfo(PlayInfo);
    PlayInfo.AddSetting(default.RulesGroup, "DamageDealtPercent", default.DamageDealtText, 0, 1, "Text", "2;0:90");
    PlayInfo.AddSetting(default.RulesGroup, "DamageReceivedPercent", default.DamageReceivedText, 0, 2, "Text", "2;0:90");
}

static event string GetDescriptionText(string PropName)
{
    switch (PropName)
    {
        case "DamageDealtPercent":    return default.DamageDealtDesc;
        case "DamageReceivedPercent": return default.DamageReceivedDesc;
    }
    return Super.GetDescriptionText(PropName);
}

function RollKayrosForWave()
{
    local Controller C;
    local PlayerController PC;
    local PlayerController Humans[32];
    local PlayerController OtherHumans[32];
    local int HumanCount, OtherCount, i;
    local float RotateChance;
    local bool bPreviousStillPresent, bForceDifferentPlayer;
    local Sound KayrosSound;
    local MutChatDokaBots ChatMut;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        PC = PlayerController(C);
        if (PC != None && PC.PlayerReplicationInfo != None && !PC.PlayerReplicationInfo.bOnlySpectator)
        {
            if (HumanCount < 32)
            {
                Humans[HumanCount] = PC;
                HumanCount++;
                if (PC == PreviousChosenPlayer)
                {
                    bPreviousStillPresent = true;
                }
            }
        }
    }

    if (HumanCount == 0)
    {
        ChosenPlayer = None;
        KayrosState = 0;
        return;
    }

    // Porcentaje de rotacion a otro jugador distinto segun cantidad de jugadores humanos (Opcion A):
    // - Hasta 3 jugadores: 80% de probabilidad de pasar a otro jugador distinto (20% de poder repetir)
    // - 4 jugadores: 90% de probabilidad de pasar a otro jugador distinto (10% de poder repetir)
    // - 5 o mas jugadores: 100% garantizado que pasa a otro jugador distinto sin repetir al anterior
    if (HumanCount <= 3)
    {
        RotateChance = 0.80;
    }
    else if (HumanCount == 4)
    {
        RotateChance = 0.90;
    }
    else
    {
        RotateChance = 1.00;
    }

    if (HumanCount == 1 || PreviousChosenPlayer == None || !bPreviousStillPresent)
    {
        ChosenPlayer = Humans[Rand(HumanCount)];
    }
    else
    {
        bForceDifferentPlayer = (FRand() < RotateChance);
        if (bForceDifferentPlayer)
        {
            for (i = 0; i < HumanCount; i++)
            {
                if (Humans[i] != PreviousChosenPlayer)
                {
                    OtherHumans[OtherCount] = Humans[i];
                    OtherCount++;
                }
            }

            if (OtherCount > 0)
            {
                ChosenPlayer = OtherHumans[Rand(OtherCount)];
            }
            else
            {
                ChosenPlayer = Humans[Rand(HumanCount)];
            }
        }
        else
        {
            // Cayo en el porcentaje de repeticion (20% con 3 jugadores, 10% con 4 jugadores)
            ChosenPlayer = PreviousChosenPlayer;
        }
    }

    PreviousChosenPlayer = ChosenPlayer;

    // 50% Mucho Kayros / 50% Poco Kayros
    if (FRand() < 0.50)
    {
        KayrosState = 1; // TENES MUCHO KAYROS
    }
    else
    {
        KayrosState = 2; // TENES POCO KAYROS
    }

    // Mostrar cartel tamano 48 con la fuente personalizada UNICAMENTE al jugador elegido
    if (ChosenPlayer != None)
    {
        ChosenPlayer.ReceiveLocalizedMessage(class'KayrosMessage', KayrosState);

        if (KayrosState == 1)
        {
            KayrosSound = class'XPickups.UDamagePack'.Default.PickupSound;
        }
        else
        {
            KayrosSound = class'SkaarjPack.GasBag'.Default.ChallengeSound[0];
        }

        if (KayrosSound != None)
        {
            ChosenPlayer.ClientPlaySound(KayrosSound, true, 2.0, SLOT_Talk);
        }

        // Opcion B (Bot buchon): Si Chat-doka Bots esta activo, un bot lo manda al frente en el chat
        ForEach DynamicActors(class'MutChatDokaBots', ChatMut)
        {
            ChatMut.TriggerKayrosSnitchChat(ChosenPlayer, (KayrosState == 1));
            break;
        }
    }
}

function Timer()
{
    local Invasion InvGame;

    InvGame = Invasion(Level.Game);
    if (InvGame == None)
    {
        return;
    }

    // Al comenzar cada nueva oleada, se realiza el sorteo de Kayros
    if (InvGame.bWaveInProgress && InvGame.WaveNum != CurrentWaveNum)
    {
        CurrentWaveNum = InvGame.WaveNum;
        RollKayrosForWave();
    }
}

defaultproperties
{
    // Manda este paquete a los jugadores que se conectan: sin esto, a ellos no les llega nada
    // de lo que se dibuja o pasa en su maquina (radar, Vision, mensajes, armas con adrenalina...)
    bAddToServerPackages=True
    CurrentWaveNum=-1
    DamageDealtPercent=30
    DamageReceivedPercent=30
    DamageDealtText="Cambio del dano que hace"
    DamageDealtDesc="Cuanto mas dano hace el jugador con Mucho Kayros, y cuanto menos con Poco Kayros, en porcentaje (de 0 a 90) [por defecto: 30]"
    DamageReceivedText="Cambio del dano que recibe"
    DamageReceivedDesc="Cuanto menos dano recibe el jugador con Mucho Kayros, y cuanto mas con Poco Kayros, en porcentaje (de 0 a 90) [por defecto: 30]"
    GroupName="KayrosMut"
    FriendlyName="[Irreal] Poco o mucho Kayros?"
    Description="En cada oleada elige a 1 jugador humano al azar y le da Mucho Kayros (hace 30% mas de dano y recibe 30% menos) o Poco Kayros (hace 30% menos de dano y recibe 30% mas). Los porcentajes se cambian en Configurar mutadores. (Ver 1.4.1)"
}
