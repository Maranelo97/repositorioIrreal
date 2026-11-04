class MutInvasionUltimates extends Mutator;

// Opciones de "Configurar mutadores": que armas entran en la rotacion del punto especial
var config bool bRedeemer;
var config bool bIonPainter;
var config bool bLightningGun;
var config bool bRepeatPickup;   // si se desactiva, cada jugador lo recoge una sola vez por oleada
var config bool bBotsCanPickup;  // si se desactiva, los bots no recogen ni buscan el arma del punto especial

var localized string RedeemerText, RedeemerDesc;
var localized string IonPainterText, IonPainterDesc;
var localized string LightningGunText, LightningGunDesc;
var localized string RepeatPickupText, RepeatPickupDesc;
var localized string BotsCanPickupText, BotsCanPickupDesc;

var xWeaponBase UltimateBase;
var UltimatesRules Rules;
var int CurrentWaveNum;
var bool bInitialized;

function PostBeginPlay()
{
    local UltimatesRules GR;

    Super.PostBeginPlay();
    CurrentWaveNum = -1;
    if (Invasion(Level.Game) != None)
    {
        SetTimer(1.0, false);

        // Rechaza recoger el arma del punto especial cuando ya tenes la municion llena
        GR = Spawn(class'UltimatesRules');
        if (GR != None)
        {
            GR.UltimatesMut = self;
            Rules = GR;
            if (Level.Game.GameRulesModifiers == None)
                Level.Game.GameRulesModifiers = GR;
            else
                Level.Game.GameRulesModifiers.AddGameRules(GR);
        }
    }
}

// El Target Painter ya no esta en la rotacion (necesita mucho espacio libre arriba y casi
// nunca funciona en mapas de Invasion), pero sigue aca para vaciar sus puntos si el mapa los tiene.
function bool IsSpecialWeapon(class<Weapon> WeaponClass)
{
    return WeaponClass == class'XWeapons.Redeemer'
        || WeaponClass == class'XWeapons.Painter'
        || WeaponClass == class'OnslaughtFull.ONSPainter'
        || WeaponClass == class'XWeapons.SniperRifle';
}

function xWeaponBase PickRandomWeaponBase(bool bRotationOnly)
{
    local xWeaponBase Candidate, Chosen;
    local int EligibleCount;

    foreach AllActors(class'XGame.xWeaponBase', Candidate)
    {
        if (Candidate.WeaponType == None)
            continue;

        if (bRotationOnly)
        {
            if (!IsSpecialWeapon(Candidate.WeaponType))
                continue;
        }
        else if (Candidate.WeaponType == class'XWeapons.LinkGun'
            || IsSpecialWeapon(Candidate.WeaponType))
            continue;

        EligibleCount++;
        if (Rand(EligibleCount) == 0)
            Chosen = Candidate;
    }
    return Chosen;
}

function RemoveBasePickup(xWeaponBase Base)
{
    local Pickup OldPickup;
    if (Base == None)
        return;
    OldPickup = Base.myPickUp;
    Base.myPickUp = None;
    if (OldPickup != None)
        OldPickup.Destroy();
}

function DisableOtherSpecialBases()
{
    local xWeaponBase Candidate;
    foreach AllActors(class'XGame.xWeaponBase', Candidate)
    {
        if (Candidate != UltimateBase && IsSpecialWeapon(Candidate.WeaponType))
        {
            RemoveBasePickup(Candidate);
            Candidate.WeaponType = None;
            Candidate.PowerUp = None;
        }
    }
}

function SetUltimate(int WeaponIndex)
{
    if (UltimateBase == None)
        return;

    RemoveBasePickup(UltimateBase);

    // Arma nueva en el punto: todos pueden volver a recogerla
    if (Rules != None)
        Rules.ResetPickups();

    switch (WeaponIndex)
    {
        case 0:
            UltimateBase.WeaponType = class'XWeapons.Redeemer';
            UltimateBase.PowerUp = class'MutInvasionRedeemerPickup';
            break;
        case 1:
            UltimateBase.WeaponType = class'XWeapons.Painter';
            UltimateBase.PowerUp = class'MutInvasionIonPainterPickup';
            break;
        default:
            UltimateBase.WeaponType = class'XWeapons.SniperRifle';
            UltimateBase.PowerUp = class'MutInvasionLightningGunPickup';
            break;
    }
    UltimateBase.SpawnPickup();
}

// Elige al azar entre las armas activadas (mismos indices que SetUltimate).
// Si estan todas desactivadas, usa las tres para que el punto no quede vacio.
function int PickUltimateIndex()
{
    local int Options[3];
    local int Count;

    if (bRedeemer)
    {
        Options[Count] = 0;
        Count++;
    }
    if (bIonPainter)
    {
        Options[Count] = 1;
        Count++;
    }
    if (bLightningGun)
    {
        Options[Count] = 2;
        Count++;
    }

    if (Count == 0)
        return Rand(3);
    return Options[Rand(Count)];
}

function Timer()
{
    local Invasion InvGame;

    InvGame = Invasion(Level.Game);
    if (InvGame == None)
        return;

    if (!bInitialized)
    {
        // Si ya hay una ulti o pesada en el mapa, conservar ese punto; si no, elegir un arma normal.
        UltimateBase = PickRandomWeaponBase(true);
        if (UltimateBase == None)
            UltimateBase = PickRandomWeaponBase(false);

        if (UltimateBase == None)
        {
            SetTimer(1.0, false);
            return;
        }

        DisableOtherSpecialBases();
        SetUltimate(PickUltimateIndex());
        bInitialized = true;
        SetTimer(1.0, true);
        return;
    }

    // Cada ronda elige al azar entre las activadas; se permite repetir la ronda anterior.
    // Invasion suma WaveNum apenas termina la oleada, asi que el arma cambia al empezar
    // el descanso: quien ya la uso puede recoger la nueva antes de la siguiente oleada.
    if (InvGame.WaveNum != CurrentWaveNum)
    {
        if (CurrentWaveNum >= 0)
            SetUltimate(PickUltimateIndex());
        CurrentWaveNum = InvGame.WaveNum;
    }
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
    Super.FillPlayInfo(PlayInfo);
    PlayInfo.AddSetting(default.RulesGroup, "bRedeemer", default.RedeemerText, 0, 1, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bIonPainter", default.IonPainterText, 0, 2, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bLightningGun", default.LightningGunText, 0, 3, "Check");
    // Solo se ven con "Ver opciones avanzadas" (ultimo parametro de AddSetting)
    PlayInfo.AddSetting(default.RulesGroup, "bRepeatPickup", default.RepeatPickupText, 0, 4, "Check", , , , True);
    PlayInfo.AddSetting(default.RulesGroup, "bBotsCanPickup", default.BotsCanPickupText, 0, 5, "Check", , , , True);
}

static event string GetDescriptionText(string PropName)
{
    switch (PropName)
    {
        case "bRedeemer":     return default.RedeemerDesc;
        case "bIonPainter":   return default.IonPainterDesc;
        case "bLightningGun": return default.LightningGunDesc;
        case "bRepeatPickup": return default.RepeatPickupDesc;
        case "bBotsCanPickup": return default.BotsCanPickupDesc;
    }
    return Super.GetDescriptionText(PropName);
}

defaultproperties
{
    // Manda este paquete a los jugadores que se conectan: sin esto, a ellos no les llega nada
    // de lo que se dibuja o pasa en su maquina (radar, Vision, mensajes, armas con adrenalina...)
    bAddToServerPackages=True
    bRedeemer=True
    bIonPainter=True
    bLightningGun=True
    bRepeatPickup=True
    bBotsCanPickup=False
    BotsCanPickupText="Los bots pueden recoger las armas ultimas"
    BotsCanPickupDesc="Si se desactiva, los bots no buscan el punto especial y, si pasan por encima, no recogen el arma: queda para los jugadores [por defecto: desactivada]"
    RepeatPickupText="Recogerla varias veces por oleada"
    RepeatPickupDesc="Cada jugador puede volver al punto especial para recargar el arma durante la oleada. Si se desactiva, cada uno la recoge una sola vez por oleada [por defecto: activada]"
    RedeemerText="Redeemer"
    RedeemerDesc="El Redeemer puede salir en el punto especial. Si se desactivan las tres armas, se usan todas [por defecto: activada]"
    IonPainterText="Ion Painter"
    IonPainterDesc="El Ion Painter puede salir en el punto especial. Si se desactivan las tres armas, se usan todas [por defecto: activada]"
    LightningGunText="Lightning Gun"
    LightningGunDesc="La Lightning Gun puede salir en el punto especial. Si se desactivan las tres armas, se usan todas [por defecto: activada]"
    GroupName="InvasionUltimates"
    FriendlyName="[Irreal] Invasion: Armas ultimas"
    Description="Un unico punto de arma alterna al azar entre Redeemer, Ion Painter y Lightning Gun al terminar cada oleada (asi se puede recoger durante el descanso), con respawn instantaneo. Los demas puntos de esas armas quedan vacios. En Configurar mutadores se eligen las armas de la rotacion, si cada jugador puede recogerla varias veces por oleada y si los bots pueden recogerla (por defecto no)."
}
