class MutGigachadrenalina extends Mutator;

// Opciones de "Configurar mutadores"; quedan guardadas en el .ini del juego del host
var config bool bAdrenalineUltimates;   // las armas ultimas usan adrenalina en vez de municion
var config int RedeemerCost;       // adrenalina por disparo de cada arma ultima
var config int IonPainterCost;
var config int LightningGunCost;
var config bool bFillAdrenalineOnPickup;   // llenar la adrenalina al agarrar un arma ultima que no tenias
var config bool bFlightCombo;             // combo Vuelo
var config bool bVisionCombo;             // combo Vision
var config bool bCancelCombos;            // cortar el combo activo repitiendo sus teclas
var config bool bChainCombos;             // con un combo activo, marcar otro cambia a ese
var config bool bInfiniteAdrenaline;      // la adrenalina de los jugadores siempre esta llena
var config int ComboDrainPercent;         // que tan rapido gastan adrenalina los combos (100 = normal)
var config int AdrenalinePillAmount;      // adrenalina que da cada pastilla (2 en el juego)

var localized string AdrenalineUltimatesText, AdrenalineUltimatesDesc;
var localized string RedeemerCostText, RedeemerCostDesc;
var localized string IonPainterCostText, IonPainterCostDesc;
var localized string LightningGunCostText, LightningGunCostDesc;
var localized string FillAdrenalineOnPickupText, FillAdrenalineOnPickupDesc;
var localized string FlightComboText, FlightComboDesc;
var localized string VisionComboText, VisionComboDesc;
var localized string CancelCombosText, CancelCombosDesc;
var localized string ChainCombosText, ChainCombosDesc;
var localized string InfiniteAdrenalineText, InfiniteAdrenalineDesc;
var localized string ComboDrainPercentText, ComboDrainPercentDesc;
var localized string AdrenalinePillAmountText, AdrenalinePillAmountDesc;

// Valor original de AdrenalinePickup.AdrenalineAmount, para devolverlo al cambiar de mapa
var float OriginalPillAmount;
var bool bPillAmountChanged;

// Combos activos y cuando empezaron, para no cortar uno que recien arranca: el pedido de
// cortarlo puede llegar justo despues del que lo inicio, con las mismas teclas
var array<Combo> TrackedCombos;
var array<float> TrackedTimes;
const MinComboAgeToCancel = 1.0;

// Al cortar un combo con la adrenalina en 100 (por ejemplo con adrenalina infinita), el juego
// tambien lee esas teclas y lo vuelve a iniciar enseguida. Para evitarlo, la adrenalina queda
// apenas por debajo de lo que cuesta un combo durante un momento y despues se devuelve.
var array<Controller> HeldControllers;
var array<float> HeldUntil;
var array<float> HeldAdrenaline;
const ComboRestartBlockTime = 0.5;
const HeldAdrenalineCap = 99.0;
const CancelSoundPitch = 0.75;     // tono del sonido al cortar un combo (el de activacion, mas grave)
const InfiniteComboMargin = 0.5;   // ver Tick (adrenalina infinita durante un combo)

function PostBeginPlay()
{
    local GigaReplicationInfo RI;
    local AdrenalinePickup AP;

    Super.PostBeginPlay();

    // Adrenalina por pastilla: se cambia el valor por defecto de la clase (Poco o mucho Kayros
    // calcula cada pastilla a partir de ese valor, asi las dos cosas se combinan) y el de las
    // pastillas que ya estan en el mapa. Se devuelve el original en ServerTraveling.
    if (float(Clamp(AdrenalinePillAmount, 1, 100)) != class'XPickups.AdrenalinePickup'.default.AdrenalineAmount)
    {
        OriginalPillAmount = class'XPickups.AdrenalinePickup'.default.AdrenalineAmount;
        bPillAmountChanged = true;
        class'XPickups.AdrenalinePickup'.default.AdrenalineAmount = float(Clamp(AdrenalinePillAmount, 1, 100));
        foreach AllActors(class'XPickups.AdrenalinePickup', AP)
            AP.AdrenalineAmount = class'XPickups.AdrenalinePickup'.default.AdrenalineAmount;
    }
    RI = Spawn(class'GigaReplicationInfo');
    if (RI != None)
        RI.bComboKeys = bCancelCombos || bChainCombos || bFlightCombo;
}

// Al cambiar de mapa se devuelve el valor original de las pastillas, por si la proxima partida
// no usa este mutador (los valores por defecto de las clases duran hasta cerrar el juego)
function ServerTraveling(string URL, bool bItems)
{
    RestorePillAmount();
    Super.ServerTraveling(URL, bItems);
}

function Destroyed()
{
    RestorePillAmount();
    Super.Destroyed();
}

function RestorePillAmount()
{
    if (!bPillAmountChanged)
        return;
    class'XPickups.AdrenalinePickup'.default.AdrenalineAmount = OriginalPillAmount;
    bPillAmountChanged = false;
}

function Tick(float DeltaTime)
{
    local Controller C;
    local xPawn P;
    local int i;

    Super.Tick(DeltaTime);

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        // Adrenalina infinita: solo para los jugadores humanos (los bots harian combos sin parar).
        // Durante un combo queda un poco por encima del maximo: el combo gasta un poquito en
        // cada cuadro despues de esto, y si no el HUD mostraria 99.
        if (bInfiniteAdrenaline && PlayerController(C) != None && C.bAdrenalineEnabled && C.Pawn != None
            && HeldIndex(C) < 0)
        {
            C.Adrenaline = C.AdrenalineMax;
            if (xPawn(C.Pawn) != None && xPawn(C.Pawn).CurrentCombo != None)
                C.Adrenaline += InfiniteComboMargin;
        }

        P = xPawn(C.Pawn);
        if (P != None && P.CurrentCombo != None && !P.CurrentCombo.bDeleteMe)
            AdjustComboDrain(C, P.CurrentCombo, DeltaTime);

        if ((bCancelCombos || bChainCombos) && P != None && P.CurrentCombo != None && ComboIndex(P.CurrentCombo) < 0)
        {
            TrackedCombos[TrackedCombos.Length] = P.CurrentCombo;
            TrackedTimes[TrackedTimes.Length] = Level.TimeSeconds;
        }
    }

    for (i = TrackedCombos.Length - 1; i >= 0; i--)
    {
        if (TrackedCombos[i] == None || TrackedCombos[i].bDeleteMe)
        {
            TrackedCombos.Remove(i, 1);
            TrackedTimes.Remove(i, 1);
        }
    }

    // Adrenalina retenida despues de cortar un combo: se mantiene debajo de 100 y al terminar
    // el momento se devuelve lo que habia (con adrenalina infinita, el Tick siguiente la llena)
    for (i = HeldControllers.Length - 1; i >= 0; i--)
    {
        C = HeldControllers[i];
        if (C == None || C.bDeleteMe)
        {
            RemoveHeld(i);
            continue;
        }
        if (Level.TimeSeconds >= HeldUntil[i])
        {
            C.Adrenaline = FClamp(FMax(C.Adrenaline, HeldAdrenaline[i]), 0, C.AdrenalineMax);
            RemoveHeld(i);
        }
        else if (C.Adrenaline > HeldAdrenalineCap)
            C.Adrenaline = HeldAdrenalineCap;
    }
}

function int HeldIndex(Controller C)
{
    local int i;

    for (i = 0; i < HeldControllers.Length; i++)
        if (HeldControllers[i] == C)
            return i;
    return -1;
}

function RemoveHeld(int i)
{
    HeldControllers.Remove(i, 1);
    HeldUntil.Remove(i, 1);
    HeldAdrenaline.Remove(i, 1);
}

// Deja la adrenalina apenas debajo del costo de un combo por un momento (ver HeldControllers)
function HoldAdrenaline(Controller C)
{
    local int i;

    i = HeldIndex(C);
    if (i < 0)
    {
        i = HeldControllers.Length;
        HeldControllers[i] = C;
        HeldAdrenaline[i] = C.Adrenaline;
    }
    HeldUntil[i] = Level.TimeSeconds + ComboRestartBlockTime;
    if (C.Adrenaline > HeldAdrenalineCap)
        C.Adrenaline = HeldAdrenalineCap;
}

// Cada combo gasta su costo a lo largo de su duracion (ver Combo.Tick). Como no se pueden
// cambiar los combos del juego, aca se devuelve (o se quita) la parte que corresponde segun
// ComboDrainPercent: con 50 se devuelve la mitad de lo que gasto y el combo dura el doble.
function AdjustComboDrain(Controller C, Combo Cmb, float DeltaTime)
{
    local float Drain, Pct;

    Pct = float(Clamp(ComboDrainPercent, 0, 400)) / 100.0;
    if (Pct == 1.0 || Cmb.Duration <= 0)
        return;
    Drain = Cmb.AdrenalineCost * DeltaTime / Cmb.Duration;
    if (C.PlayerReplicationInfo != None && C.PlayerReplicationInfo.HasFlag != None)
        Drain *= 2;   // como en Combo.Tick
    C.Adrenaline = FClamp(C.Adrenaline + Drain * (1.0 - Pct), 0, C.AdrenalineMax);
}

function int ComboIndex(Combo Cmb)
{
    local int i;

    for (i = 0; i < TrackedCombos.Length; i++)
        if (TrackedCombos[i] == Cmb)
            return i;
    return -1;
}

// Combos que se pueden pedir con "mutate gigacombo": los del juego y los de este paquete
// (si su opcion esta activada). Asi un cliente no puede pedir cualquier clase.
function bool AllowedCombo(class<Combo> ComboClass)
{
    local string Pkg;

    if (ComboClass == None)
        return false;
    if (ComboClass == class'ComboVuelo')
        return bFlightCombo;
    if (ComboClass == class'ComboVision')
        return bVisionCombo;
    Pkg = string(ComboClass);
    return Left(Pkg, 6) ~= "XGame.";
}

// "mutate gigacombo <clase>": lo manda GigaComboInteraction cuando el jugador marca las teclas
// de un combo mientras tiene uno activo (que no recien empezo). Si es el mismo combo, se corta
// y la adrenalina que quedaba no se pierde. Si es otro, se cambia a ese y sigue gastando la
// adrenalina que quedaba.
function Mutate(string MutateString, PlayerController Sender)
{
    local xPawn P;
    local class<Combo> ComboClass;
    local int i;

    // "mutate gigafly 1/0/-1": subir o bajar volando (lo manda GigaComboInteraction)
    if (Sender != None && Left(MutateString, 8) ~= "gigafly " && xPawn(Sender.Pawn) != None
        && ComboVuelo(xPawn(Sender.Pawn).CurrentCombo) != None)
        ComboVuelo(xPawn(Sender.Pawn).CurrentCombo).VerticalInput = Clamp(int(Mid(MutateString, 8)), -1, 1);

    if (Sender != None && Left(MutateString, 10) ~= "gigacombo ")
    {
        P = xPawn(Sender.Pawn);
        if (P != None && P.CurrentCombo != None)
        {
            ComboClass = class<Combo>(DynamicLoadObject(Mid(MutateString, 10), class'Class', true));
            i = ComboIndex(P.CurrentCombo);
            if (AllowedCombo(ComboClass) && i >= 0 && Level.TimeSeconds - TrackedTimes[i] >= MinComboAgeToCancel)
            {
                if (P.CurrentCombo.Class == ComboClass)
                {
                    if (bCancelCombos)
                    {
                        // El juego no tiene sonido de fin de combo: el de activacion, mas grave
                        if (P.CurrentCombo.ActivateSound != None)
                            P.PlaySound(P.CurrentCombo.ActivateSound, SLOT_None, 2 * P.TransientSoundVolume, , , CancelSoundPitch);
                        P.CurrentCombo.Destroy();
                        HoldAdrenaline(Sender);
                    }
                }
                else if (bChainCombos)
                {
                    P.CurrentCombo.Destroy();
                    if (P.CurrentCombo == None)
                    {
                        if (ComboClass.default.ExecMessage != "")
                            Sender.ReceiveLocalizedMessage(class'ComboMessage', , , , ComboClass);
                        P.DoCombo(ComboClass);
                    }
                }
            }
        }
    }
    Super.Mutate(MutateString, Sender);
}

// Version de GIGACHADrenalina de cada arma ultima (None si no es una de ellas)
static function class<Inventory> GigaWeaponFor(class<Inventory> WeaponClass)
{
    if (WeaponClass == class'XWeapons.Redeemer')
        return class'GigaRedeemer';
    if (WeaponClass == class'XWeapons.Painter')
        return class'GigaIonPainter';
    if (WeaponClass == class'XWeapons.SniperRifle')
        return class'GigaLightningGun';
    return None;
}

// Cada vez que aparece un arma ultima en el piso (puntos del mapa, Armas ultimas o un arma
// tirada), se cambia lo que entrega por la version que usa adrenalina
function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
    local WeaponPickup P;
    local class<Inventory> Giga;

    // Pastillas que aparecen despues (las del mapa ya se cambiaron en PostBeginPlay)
    if (bPillAmountChanged && AdrenalinePickup(Other) != None)
        AdrenalinePickup(Other).AdrenalineAmount = class'XPickups.AdrenalinePickup'.default.AdrenalineAmount;

    if (!bAdrenalineUltimates)
        return true;

    P = WeaponPickup(Other);
    if (P != None)
    {
        Giga = GigaWeaponFor(P.InventoryType);
        if (Giga != None)
            P.InventoryType = Giga;
    }
    return true;
}

// Los combos nuevos se le agregan a cada jugador cuando aparece (si ya los tiene, no pasa nada)
function ModifyPlayer(Pawn Other)
{
    local xPlayer PC;

    PC = xPlayer(Other.Controller);
    if (PC != None)
    {
        if (bFlightCombo)
            PC.ClientReceiveCombo("MyInvasionMut.ComboVuelo");
        if (bVisionCombo)
            PC.ClientReceiveCombo("MyInvasionMut.ComboVision");
    }
    Super.ModifyPlayer(Other);
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
    Super.FillPlayInfo(PlayInfo);
    PlayInfo.AddSetting(default.RulesGroup, "bInfiniteAdrenaline", default.InfiniteAdrenalineText, 0, 1, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "AdrenalinePillAmount", default.AdrenalinePillAmountText, 0, 2, "Text", "3;1:100", , , True);
    PlayInfo.AddSetting(default.RulesGroup, "bAdrenalineUltimates", default.AdrenalineUltimatesText, 0, 3, "Check");
    // Las pastillas, los costos, el llenado de adrenalina y el gasto de los combos solo se ven con "Ver opciones avanzadas" (ultimo parametro de AddSetting)
    PlayInfo.AddSetting(default.RulesGroup, "RedeemerCost", default.RedeemerCostText, 0, 4, "Text", "3;0:100", , , True);
    PlayInfo.AddSetting(default.RulesGroup, "IonPainterCost", default.IonPainterCostText, 0, 5, "Text", "3;0:100", , , True);
    PlayInfo.AddSetting(default.RulesGroup, "LightningGunCost", default.LightningGunCostText, 0, 6, "Text", "3;0:100", , , True);
    PlayInfo.AddSetting(default.RulesGroup, "bFillAdrenalineOnPickup", default.FillAdrenalineOnPickupText, 0, 7, "Check", , , , True);
    PlayInfo.AddSetting(default.RulesGroup, "bFlightCombo", default.FlightComboText, 0, 8, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bVisionCombo", default.VisionComboText, 0, 9, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "ComboDrainPercent", default.ComboDrainPercentText, 0, 10, "Text", "3;0:400", , , True);
    PlayInfo.AddSetting(default.RulesGroup, "bCancelCombos", default.CancelCombosText, 0, 11, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bChainCombos", default.ChainCombosText, 0, 12, "Check");
}

static event string GetDescriptionText(string PropName)
{
    switch (PropName)
    {
        case "bAdrenalineUltimates": return default.AdrenalineUltimatesDesc;
        case "RedeemerCost":     return default.RedeemerCostDesc;
        case "IonPainterCost":   return default.IonPainterCostDesc;
        case "LightningGunCost": return default.LightningGunCostDesc;
        case "bFillAdrenalineOnPickup": return default.FillAdrenalineOnPickupDesc;
        case "bFlightCombo":     return default.FlightComboDesc;
        case "bVisionCombo":     return default.VisionComboDesc;
        case "bCancelCombos":    return default.CancelCombosDesc;
        case "bChainCombos":     return default.ChainCombosDesc;
        case "bInfiniteAdrenaline": return default.InfiniteAdrenalineDesc;
        case "ComboDrainPercent": return default.ComboDrainPercentDesc;
        case "AdrenalinePillAmount": return default.AdrenalinePillAmountDesc;
    }
    return Super.GetDescriptionText(PropName);
}

defaultproperties
{
    bAdrenalineUltimates=True
    AdrenalineUltimatesText="Armas ultimas con adrenalina"
    AdrenalineUltimatesDesc="El Redeemer, el Ion Painter y la Lightning Gun gastan adrenalina en vez de municion. Si se desactiva, usan municion normal y solo quedan los combos [por defecto: activada]"
    RedeemerCost=50
    IonPainterCost=25
    LightningGunCost=5
    bFillAdrenalineOnPickup=True
    FillAdrenalineOnPickupText="Llenar la adrenalina al agarrar un arma ultima"
    FillAdrenalineOnPickupDesc="Al agarrar un arma ultima que no tenias, la adrenalina se llena. Volver a tocar el punto mientras la tenes no da nada. Solo funciona con las armas ultimas con adrenalina [por defecto: activada]"
    bFlightCombo=True
    FlightComboText="Combo Vuelo"
    FlightComboDesc="Cuatro veces derecha: volas libremente durante 20 segundos (con el gasto normal); saltar sube y agacharse baja [por defecto: activada]"
    bVisionCombo=True
    VisionComboText="Combo Vision"
    VisionComboDesc="Cuatro veces izquierda: durante 30 segundos (con el gasto normal) quedan marcados a traves de las paredes los monstruos (amarillo), los otros jugadores (verde), el Rey Cthulhu (rojo) y los pickups importantes que podes agarrar (blanco). Los marcos se llenan segun la vida que les queda; el de los jugadores muestra la vida a la izquierda y el escudo a la derecha [por defecto: activada]"
    bCancelCombos=True
    CancelCombosText="Cortar el combo repitiendo las teclas"
    CancelCombosDesc="Si repetis las teclas del combo que tenes activo, se corta y te queda la adrenalina que sobraba. Vale para todos los combos [por defecto: activada]"
    bChainCombos=True
    ChainCombosText="Encadenar combos"
    ChainCombosDesc="Con un combo activo, si marcas las teclas de otro combo cambias a ese, con la adrenalina que te quedaba. Vale para todos los combos [por defecto: activada]"
    bInfiniteAdrenaline=False
    ComboDrainPercent=100
    AdrenalinePillAmount=2
    AdrenalinePillAmountText="Adrenalina por pastilla"
    AdrenalinePillAmountDesc="Adrenalina que da cada pastilla de adrenalina del mapa (de 1 a 100) [por defecto: 2]"
    ComboDrainPercentText="Gasto de adrenalina de los combos (%)"
    ComboDrainPercentDesc="Que tan rapido gastan adrenalina los combos: con 50 duran el doble y con 200 la mitad. Vale para todos los combos (de 0 a 400, 0 = no gastan) [por defecto: 100]"
    InfiniteAdrenalineText="Adrenalina infinita"
    InfiniteAdrenalineDesc="La adrenalina de los jugadores (no la de los bots) siempre esta llena: los combos no se terminan solos y, con las armas ultimas con adrenalina, disparar no gasta [por defecto: desactivada]"
    RedeemerCostText="Adrenalina por disparo: Redeemer"
    RedeemerCostDesc="Adrenalina que cuesta cada disparo del Redeemer (de 0 a 100, 0 = gratis) [por defecto: 50]"
    IonPainterCostText="Adrenalina por disparo: Ion Painter"
    IonPainterCostDesc="Adrenalina que cuesta cada disparo del Ion Painter (de 0 a 100, 0 = gratis) [por defecto: 25]"
    LightningGunCostText="Adrenalina por disparo: Lightning Gun"
    LightningGunCostDesc="Adrenalina que cuesta cada disparo de la Lightning Gun (de 0 a 100, 0 = gratis) [por defecto: 5]"
    GroupName="Gigachadrenalina"
    FriendlyName="[Irreal] GIGACHADrenalina"
    Description="El Redeemer, el Ion Painter y la Lightning Gun usan adrenalina en vez de municion: cada disparo cuesta adrenalina (50, 25 y 5 por defecto) y al agarrar una se llena la adrenalina. Agrega dos combos: Vuelo (cuatro veces derecha; saltar sube y agacharse baja) y Vision (cuatro veces izquierda), que marca a traves de las paredes a los monstruos, los jugadores, el Rey Cthulhu y los pickups utiles, con la vida de cada uno. Los combos se cortan repitiendo sus teclas y se encadenan marcando las de otro. Todo se cambia en Configurar mutadores."
}
