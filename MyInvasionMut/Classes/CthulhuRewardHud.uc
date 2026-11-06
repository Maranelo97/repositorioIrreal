// Esconde el contador del Double Damage que da el Rey Cthulhu: dura hasta el final de la oleada,
// asi que el HUD mostraria un numero enorme que no significa nada. Corre en cada computadora y
// reconoce la recompensa por el tiempo que queda, mucho mas largo que el de un Double Damage
// normal. Mientras tanto deja transparentes el icono y el numero del HUD del jugador local.
class CthulhuRewardHud extends ReplicationInfo;

var float HideAboveSeconds;   // con mas tiempo que esto, el Double Damage es la recompensa
var HudCDeathMatch HiddenHud; // el HUD al que se le escondio el contador (None si esta normal)
var byte OldIconAlpha[2], OldTimeAlpha[2];
var ERenderStyle OldIconStyle, OldTimeStyle;

simulated function Tick(float DeltaTime)
{
    local PlayerController PC;
    local HudCDeathMatch H;
    local xPawn P;
    local bool bHide;

    if (Level.NetMode == NM_DedicatedServer)
    {
        Disable('Tick');
        return;
    }

    PC = Level.GetLocalPlayerController();
    if (PC != None)
        H = HudCDeathMatch(PC.myHUD);

    if (H != None)
    {
        // Igual que el HUD: en un vehiculo mira al que maneja
        if (Vehicle(H.PawnOwner) != None)
            P = xPawn(Vehicle(H.PawnOwner).Driver);
        else
            P = xPawn(H.PawnOwner);
        bHide = P != None && P.UDamageTime > Level.TimeSeconds + HideAboveSeconds;
    }

    // Si el HUD cambio, el viejo ya no importa; el nuevo se esconde abajo si hace falta
    if (HiddenHud != None && (!bHide || HiddenHud != H))
        ShowCounter();

    if (bHide && HiddenHud == None)
        HideCounter(H);
}

simulated function HideCounter(HudCDeathMatch H)
{
    HiddenHud = H;
    OldIconStyle = H.UDamageIcon.RenderStyle;
    OldTimeStyle = H.UDamageTime.RenderStyle;
    OldIconAlpha[0] = H.UDamageIcon.Tints[0].A;
    OldIconAlpha[1] = H.UDamageIcon.Tints[1].A;
    OldTimeAlpha[0] = H.UDamageTime.Tints[0].A;
    OldTimeAlpha[1] = H.UDamageTime.Tints[1].A;

    H.UDamageIcon.RenderStyle = STY_Alpha;
    H.UDamageTime.RenderStyle = STY_Alpha;
    H.UDamageIcon.Tints[0].A = 0;
    H.UDamageIcon.Tints[1].A = 0;
    H.UDamageTime.Tints[0].A = 0;
    H.UDamageTime.Tints[1].A = 0;
}

simulated function ShowCounter()
{
    HiddenHud.UDamageIcon.RenderStyle = OldIconStyle;
    HiddenHud.UDamageTime.RenderStyle = OldTimeStyle;
    HiddenHud.UDamageIcon.Tints[0].A = OldIconAlpha[0];
    HiddenHud.UDamageIcon.Tints[1].A = OldIconAlpha[1];
    HiddenHud.UDamageTime.Tints[0].A = OldTimeAlpha[0];
    HiddenHud.UDamageTime.Tints[1].A = OldTimeAlpha[1];
    HiddenHud = None;
}

defaultproperties
{
    HideAboveSeconds=120.0
    bAlwaysRelevant=True
    RemoteRole=ROLE_SimulatedProxy
    NetUpdateFrequency=1.0
}
