class MutMurioUnaBandaDeGente extends Mutator;

// Opciones de "Configurar mutadores": que armas entran en la rotacion del punto especial
var config bool bRedeemer;
var config bool bIonPainter;
var config bool bLightningGun;
var config bool bRepeatPickup;   // si se desactiva, cada jugador lo recoge una sola vez por oleada
var config bool bBotsCanPickup;  // si se desactiva, los bots no recogen ni buscan el arma del punto especial
var config bool bRotateLocation; // el punto especial cambia de lugar al terminar cada oleada
var config bool bAdrenalineUltimates;   // las armas ultimas usan adrenalina en vez de municion (Giga*)
var config int RedeemerCost;       // adrenalina por disparo de cada arma ultima
var config int IonPainterCost;
var config int LightningGunCost;
var config bool bFillAdrenalineOnPickup;   // llenar la adrenalina al agarrar un arma ultima que no tenias
var config bool bChainLightning; // la Lightning Gun salta a monstruos cercanos (UltiLightningFire)
var config int ChainJumps;       // cuantos saltos
var config int ChainDamageReduction; // cuanto menos dano hace cada salto que el anterior, en %

var localized string RedeemerText, RedeemerDesc;
var localized string IonPainterText, IonPainterDesc;
var localized string LightningGunText, LightningGunDesc;
var localized string RepeatPickupText, RepeatPickupDesc;
var localized string BotsCanPickupText, BotsCanPickupDesc;
var localized string RotateLocationText, RotateLocationDesc;
var localized string AdrenalineUltimatesText, AdrenalineUltimatesDesc;
var localized string RedeemerCostText, RedeemerCostDesc;
var localized string IonPainterCostText, IonPainterCostDesc;
var localized string LightningGunCostText, LightningGunCostDesc;
var localized string FillAdrenalineOnPickupText, FillAdrenalineOnPickupDesc;
var localized string ChainLightningText, ChainLightningDesc;
var localized string ChainJumpsText, ChainJumpsDesc;
var localized string ChainDamageReductionText, ChainDamageReductionDesc;

var xWeaponBase UltimateBase;
var UltimatesRules Rules;
var int CurrentWaveNum;
var bool bInitialized;

// Para que el punto cambie de lugar: los puntos de armas comunes del mapa y el arma que le
// devuelven a cada uno al dejar de ser el especial
var array<xWeaponBase> RotationBases;
var array< class<Weapon> > RotationWeapons;

// Armas ultimas que el mapa ya trae en sus propios puntos (mismos indices que SetUltimate).
// Esos puntos se quedan con su arma, que funciona como la del punto especial, y el punto
// especial solo reparte las que faltan. Si el mapa ya tiene todas, no hay punto especial.
var byte bMapHas[3];      // 1 si el mapa la trae (no se permiten arreglos de bool)
var bool bNoSpecialSpot;

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

// Version que gasta adrenalina de cada arma ultima (None si no es una de ellas)
static function class<Inventory> GigaWeaponFor(class<Inventory> WeaponClass)
{
    if (WeaponClass == class'XWeapons.Redeemer')
        return class'GigaRedeemer';
    if (WeaponClass == class'XWeapons.Painter')
        return class'GigaIonPainter';
    if (WeaponClass == class'XWeapons.SniperRifle' || WeaponClass == class'UltiLightningGun')
        return class'GigaLightningGun';
    return None;
}

// Las armas ultimas que gastan adrenalina en vez de municion
static function bool IsAdrenalineWeapon(class<Inventory> InvClass)
{
    return ClassIsChildOf(InvClass, class'GigaRedeemer')
        || ClassIsChildOf(InvClass, class'GigaIonPainter')
        || ClassIsChildOf(InvClass, class'GigaLightningGun');
}

// Version de Murio una banda de gente de un arma ultima: la Lightning Gun pasa a ser la del rayo
// en cadena y, con "Armas ultimas con adrenalina", las tres pasan a la version que gasta
// adrenalina (que tambien tiene el rayo en cadena). Las demas armas quedan igual.
function class<Inventory> UltimateVersionOf(class<Inventory> WeaponClass)
{
    local class<Inventory> Giga;

    if (WeaponClass == class'XWeapons.SniperRifle')
        WeaponClass = class'UltiLightningGun';
    if (bAdrenalineUltimates)
    {
        Giga = GigaWeaponFor(WeaponClass);
        if (Giga != None)
            WeaponClass = Giga;
    }
    return WeaponClass;
}

// Toda arma ultima que aparece en el mapa pasa a la version de Murio una banda de gente: las de
// los puntos, las sueltas, las tiradas y las de los armarios de armas (WeaponLocker). Asi el rayo
// en cadena y la adrenalina valen igual en los mapas que ya traen sus armas ultimas.
function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
    local WeaponPickup P;
    local WeaponLocker L;
    local int i;

    P = WeaponPickup(Other);
    if (P != None)
    {
        P.InventoryType = UltimateVersionOf(P.InventoryType);
        return true;
    }

    L = WeaponLocker(Other);
    if (L != None)
        for (i = 0; i < L.Weapons.Length; i++)
            L.Weapons[i].WeaponClass = class<Weapon>(UltimateVersionOf(L.Weapons[i].WeaponClass));
    return true;
}

// Indice de arma ultima (como en SetUltimate) del arma de un punto del mapa, o -1
function int UltimateIndexOf(class<Weapon> WeaponClass)
{
    if (WeaponClass == class'XWeapons.Redeemer')
        return 0;
    if (WeaponClass == class'XWeapons.Painter')
        return 1;
    if (WeaponClass == class'XWeapons.SniperRifle')
        return 2;
    return -1;
}

// Puntos que no pueden ser el punto especial: los de armas ultimas del mapa y los del Target
// Painter (que no esta en la rotacion y queda como en el juego)
function bool IsSpecialWeapon(class<Weapon> WeaponClass)
{
    return UltimateIndexOf(WeaponClass) >= 0 || WeaponClass == class'OnslaughtFull.ONSPainter';
}

// Un punto de arma comun al azar (para el punto especial)
function xWeaponBase PickRandomWeaponBase()
{
    local xWeaponBase Candidate, Chosen;
    local int EligibleCount;

    foreach AllActors(class'XGame.xWeaponBase', Candidate)
    {
        if (Candidate.WeaponType == None || IsSpecialWeapon(Candidate.WeaponType))
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

// Pone en un punto el arma ultima de ese indice, con el pickup de Murio una banda de gente
// (respawn instantaneo, recarga al volver a tocarlo, rayo en cadena en la Lightning Gun)
function SetBaseUltimate(xWeaponBase Base, int WeaponIndex)
{
    RemoveBasePickup(Base);
    switch (WeaponIndex)
    {
        case 0:
            Base.WeaponType = class'XWeapons.Redeemer';
            Base.PowerUp = class'MutInvasionRedeemerPickup';
            break;
        case 1:
            Base.WeaponType = class'XWeapons.Painter';
            Base.PowerUp = class'MutInvasionIonPainterPickup';
            break;
        default:
            Base.WeaponType = class'XWeapons.SniperRifle';
            Base.PowerUp = class'MutInvasionLightningGunPickup';
            break;
    }
    Base.SpawnPickup();
}

// Los puntos de Redeemer, Ion Painter y Lightning Gun que trae el mapa se quedan con su arma,
// pero con el pickup de Murio una banda de gente, y se anota cuales hay
function ConvertMapUltimates()
{
    local xWeaponBase Candidate;
    local int i;

    foreach AllActors(class'XGame.xWeaponBase', Candidate)
    {
        i = UltimateIndexOf(Candidate.WeaponType);
        if (i < 0)
            continue;
        bMapHas[i] = 1;
        SetBaseUltimate(Candidate, i);
    }
}

function SetUltimate(int WeaponIndex)
{
    if (UltimateBase == None || WeaponIndex < 0)
        return;

    // Arma nueva en el punto: todos pueden volver a recogerla
    if (Rules != None)
        Rules.ResetPickups();
    SetBaseUltimate(UltimateBase, WeaponIndex);
}

// Anota los puntos de armas comunes del mapa (los que pueden ser el punto especial)
function BuildRotationBases()
{
    local xWeaponBase Candidate;
    local int i;

    RotationBases.Length = 0;
    RotationWeapons.Length = 0;
    foreach AllActors(class'XGame.xWeaponBase', Candidate)
    {
        if (Candidate.WeaponType == None || IsSpecialWeapon(Candidate.WeaponType))
            continue;

        i = RotationBases.Length;
        RotationBases[i] = Candidate;
        RotationWeapons[i] = Candidate.WeaponType;
    }
}

// Elige un punto al azar, distinto del actual si hay mas de uno
function xWeaponBase PickRotationBase()
{
    local xWeaponBase Chosen;
    local int i, EligibleCount;

    for (i = 0; i < RotationBases.Length; i++)
    {
        if (RotationBases[i] == UltimateBase && RotationBases.Length > 1)
            continue;

        EligibleCount++;
        if (Rand(EligibleCount) == 0)
            Chosen = RotationBases[i];
    }
    return Chosen;
}

// Le devuelve su arma normal al punto actual y pasa a otro. SetUltimate pone el arma en el nuevo.
function MoveUltimate()
{
    local xWeaponBase NewBase;
    local int i;

    NewBase = PickRotationBase();
    if (NewBase == None || NewBase == UltimateBase)
        return;

    RemoveBasePickup(UltimateBase);
    for (i = 0; i < RotationBases.Length; i++)
    {
        if (RotationBases[i] == UltimateBase)
        {
            UltimateBase.WeaponType = RotationWeapons[i];
            if (RotationWeapons[i] != None)
            {
                UltimateBase.PowerUp = RotationWeapons[i].default.PickupClass;
                UltimateBase.SpawnPickup();
            }
            else
                UltimateBase.PowerUp = None;
            break;
        }
    }
    UltimateBase = NewBase;
}

// Elige al azar entre las armas activadas que el mapa no trae (mismos indices que
// SetUltimate). Si estan todas desactivadas, usa las tres. -1 si no queda ninguna.
function int PickUltimateIndex()
{
    local int Options[3];
    local int Count, i;
    local byte bEnabled[3];
    local bool bAny;

    bEnabled[0] = byte(bRedeemer);
    bEnabled[1] = byte(bIonPainter);
    bEnabled[2] = byte(bLightningGun);
    bAny = bRedeemer || bIonPainter || bLightningGun;

    for (i = 0; i < 3; i++)
    {
        if ((bEnabled[i] != 0 || !bAny) && bMapHas[i] == 0)
        {
            Options[Count] = i;
            Count++;
        }
    }
    if (Count == 0)
        return -1;
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
        // Las armas ultimas del mapa se quedan; el punto especial reparte las que faltan, en un
        // punto de arma comun (con el punto que cambia de lugar, en cualquiera de ellos)
        ConvertMapUltimates();
        bInitialized = true;
        SetTimer(1.0, true);
        if (PickUltimateIndex() < 0)
        {
            bNoSpecialSpot = true;
            return;
        }

        if (bRotateLocation)
        {
            BuildRotationBases();
            UltimateBase = PickRotationBase();
        }
        else
            UltimateBase = PickRandomWeaponBase();
        if (UltimateBase == None)
        {
            bNoSpecialSpot = true;
            return;
        }
        SetUltimate(PickUltimateIndex());
        return;
    }

    // Cada ronda elige al azar entre las activadas; se permite repetir la ronda anterior.
    // Invasion suma WaveNum apenas termina la oleada, asi que el arma cambia al empezar
    // el descanso: quien ya la uso puede recoger la nueva antes de la siguiente oleada.
    if (InvGame.WaveNum != CurrentWaveNum)
    {
        if (CurrentWaveNum >= 0)
        {
            // Oleada nueva: todos pueden volver a recoger las armas ultimas
            if (Rules != None)
                Rules.ResetPickups();
            if (!bNoSpecialSpot)
            {
                if (bRotateLocation)
                    MoveUltimate();
                SetUltimate(PickUltimateIndex());
            }
        }
        CurrentWaveNum = InvGame.WaveNum;
    }
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
    Super.FillPlayInfo(PlayInfo);
    PlayInfo.AddSetting(default.RulesGroup, "bRedeemer", default.RedeemerText, 0, 1, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bIonPainter", default.IonPainterText, 0, 2, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bLightningGun", default.LightningGunText, 0, 3, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bChainLightning", default.ChainLightningText, 0, 4, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bAdrenalineUltimates", default.AdrenalineUltimatesText, 0, 7, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bRotateLocation", default.RotateLocationText, 0, 12, "Check", , , , True);
    // Solo se ven con "Ver opciones avanzadas" (ultimo parametro de AddSetting)
    PlayInfo.AddSetting(default.RulesGroup, "bRepeatPickup", default.RepeatPickupText, 0, 13, "Check", , , , True);
    PlayInfo.AddSetting(default.RulesGroup, "bBotsCanPickup", default.BotsCanPickupText, 0, 14, "Check", , , , True);
    PlayInfo.AddSetting(default.RulesGroup, "ChainJumps", default.ChainJumpsText, 0, 5, "Text", "1;1:5", , , True);
    PlayInfo.AddSetting(default.RulesGroup, "ChainDamageReduction", default.ChainDamageReductionText, 0, 6, "Text", "2;0:99", , , True);
    PlayInfo.AddSetting(default.RulesGroup, "RedeemerCost", default.RedeemerCostText, 0, 8, "Text", "3;0:100", , , True);
    PlayInfo.AddSetting(default.RulesGroup, "IonPainterCost", default.IonPainterCostText, 0, 9, "Text", "3;0:100", , , True);
    PlayInfo.AddSetting(default.RulesGroup, "LightningGunCost", default.LightningGunCostText, 0, 10, "Text", "3;0:100", , , True);
    PlayInfo.AddSetting(default.RulesGroup, "bFillAdrenalineOnPickup", default.FillAdrenalineOnPickupText, 0, 11, "Check", , , , True);
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
        case "bRotateLocation": return default.RotateLocationDesc;
        case "bChainLightning": return default.ChainLightningDesc;
        case "bAdrenalineUltimates": return default.AdrenalineUltimatesDesc;
        case "RedeemerCost":     return default.RedeemerCostDesc;
        case "IonPainterCost":   return default.IonPainterCostDesc;
        case "LightningGunCost": return default.LightningGunCostDesc;
        case "bFillAdrenalineOnPickup": return default.FillAdrenalineOnPickupDesc;
        case "ChainJumps": return default.ChainJumpsDesc;
        case "ChainDamageReduction": return default.ChainDamageReductionDesc;
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
    bRotateLocation=True
    bAdrenalineUltimates=True
    AdrenalineUltimatesText="Armas ultimas con adrenalina"
    AdrenalineUltimatesDesc="El Redeemer, el Ion Painter y la Lightning Gun gastan adrenalina en vez de municion. Si se desactiva, usan municion normal [por defecto: activada]"
    RedeemerCost=50
    IonPainterCost=25
    LightningGunCost=5
    RedeemerCostText="Adrenalina por disparo: Redeemer"
    RedeemerCostDesc="Adrenalina que cuesta cada disparo del Redeemer (de 0 a 100, 0 = gratis) [por defecto: 50]"
    IonPainterCostText="Adrenalina por disparo: Ion Painter"
    IonPainterCostDesc="Adrenalina que cuesta cada disparo del Ion Painter (de 0 a 100, 0 = gratis) [por defecto: 25]"
    LightningGunCostText="Adrenalina por disparo: Lightning Gun"
    LightningGunCostDesc="Adrenalina que cuesta cada disparo de la Lightning Gun (de 0 a 100, 0 = gratis) [por defecto: 5]"
    bFillAdrenalineOnPickup=True
    FillAdrenalineOnPickupText="Llenar la adrenalina al agarrar un arma ultima"
    FillAdrenalineOnPickupDesc="Al agarrar un arma ultima que no tenias, la adrenalina se llena. Volver a tocar el punto mientras la tenes no da nada. Solo funciona si usan adrenalina [por defecto: activada]"
    bChainLightning=True
    ChainJumps=3
    ChainDamageReduction=50
    ChainLightningText="Rayo en cadena"
    ChainLightningDesc="Cuando la Lightning Gun del punto especial le pega a un monstruo, el rayo salta a otros monstruos cercanos, cada vez con menos dano [por defecto: activada]"
    ChainJumpsText="Saltos del rayo"
    ChainJumpsDesc="A cuantos monstruos mas salta el rayo despues del primero (de 1 a 5) [por defecto: 3]"
    ChainDamageReductionText="Reduccion de dano de cada salto (%)"
    ChainDamageReductionDesc="Cuanto menos dano hace cada salto que el golpe anterior: con 50, el primer salto hace la mitad y el siguiente la mitad de eso; con 0, todos hacen lo mismo (de 0 a 99) [por defecto: 50]"
    RotateLocationText="El punto cambia de lugar en cada oleada"
    RotateLocationDesc="Al terminar cada oleada, el arma pasa a otro punto de arma del mapa elegido al azar, y el punto anterior vuelve a tener su arma normal. Los puntos de armas ultimas del mapa no cambian [por defecto: activada]"
    BotsCanPickupText="Los bots pueden recoger las armas ultimas"
    BotsCanPickupDesc="Si se desactiva, los bots no buscan el punto especial y, si pasan por encima, no recogen el arma: queda para los jugadores [por defecto: desactivada]"
    RepeatPickupText="Recogerla varias veces por oleada"
    RepeatPickupDesc="Cada jugador puede volver al punto especial para recargar el arma durante la oleada. Si se desactiva, cada uno la recoge una sola vez por oleada [por defecto: activada]"
    RedeemerText="Redeemer"
    RedeemerDesc="El Redeemer puede salir en el punto especial, salvo que el mapa ya la tenga. Si se desactivan las tres armas, se usan todas [por defecto: activada]"
    IonPainterText="Ion Painter"
    IonPainterDesc="El Ion Painter puede salir en el punto especial, salvo que el mapa ya la tenga. Si se desactivan las tres armas, se usan todas [por defecto: activada]"
    LightningGunText="Lightning Gun"
    LightningGunDesc="La Lightning Gun puede salir en el punto especial, salvo que el mapa ya la tenga. Si se desactivan las tres armas, se usan todas [por defecto: activada]"
    GroupName="InvasionUltimates"
    FriendlyName="[Irreal] Murio una banda de gente"
    Description="Un punto de arma especial alterna al azar entre Redeemer, Ion Painter y Lightning Gun al terminar cada oleada (asi se puede recoger durante el descanso), con respawn instantaneo. Si el mapa ya trae alguna de esas armas, se queda en su lugar (funcionando igual que la del punto especial) y el punto especial solo reparte las que faltan; si trae las tres, no hay punto especial. En Configurar mutadores se eligen las armas de la rotacion, si cada jugador puede recogerla varias veces por oleada y si los bots pueden recogerla (por defecto no). Por defecto el punto cambia de lugar en cada oleada, el rayo de la Lightning Gun salta a otros monstruos cercanos y las tres armas usan adrenalina en vez de municion: cada disparo cuesta adrenalina (50, 25 y 5) y al agarrar una se llena la adrenalina. (Ver 2.0)"
}
