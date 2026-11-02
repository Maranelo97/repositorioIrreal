class UltimatesRules extends GameRules;

var MutInvasionUltimates UltimatesMut;

// Quienes ya recogieron el arma del punto especial desde el ultimo cambio de arma
// (se usa cuando la opcion de recogerla varias veces por oleada esta desactivada)
var array<Controller> PickedUp;

// El arma del punto cambia al terminar cada oleada (al empezar el descanso): ahi se vacia la lista
function ResetPickups()
{
    PickedUp.Length = 0;
}

function bool HasPickedUp(Controller C)
{
    local int i;

    for (i = 0; i < PickedUp.Length; i++)
    {
        if (PickedUp[i] == C)
            return true;
    }
    return false;
}

// Opcion "Los bots pueden recoger las armas ultimas" (la usan tambien las armas del punto)
static function bool BotsCanPickup()
{
    return class'MutInvasionUltimates'.default.bBotsCanPickup;
}

// La llaman las armas del punto especial cuando alguien las recoge de verdad
static function NotePickup(Actor Context, Pawn Receiver)
{
    local GameRules G;
    local UltimatesRules R;

    if (Context == None || Context.Level.Game == None || Receiver == None || Receiver.Controller == None)
        return;

    for (G = Context.Level.Game.GameRulesModifiers; G != None; G = G.NextGameRules)
    {
        R = UltimatesRules(G);
        if (R != None)
        {
            if (!R.HasPickedUp(Receiver.Controller))
                R.PickedUp[R.PickedUp.Length] = Receiver.Controller;
            return;
        }
    }
}

// Como el punto especial ignora 'Weapons Stay', quien ya tiene el arma puede
// volver a tocarlo para recargar. Si la municion ya esta llena se rechaza la
// recogida, asi no se repite sin parar mientras alguien esta parado encima.
function bool OverridePickupQuery(Pawn Other, Pickup item, out byte bAllowPickup)
{
    local Weapon W;

    if (Other != None && item != None && IsUltimatePickup(item))
    {
        // Los bots no la recogen si la opcion esta desactivada (por defecto)
        if (!BotsCanPickup() && Bot(Other.Controller) != None)
        {
            bAllowPickup = 0;
            return true;
        }

        // Una sola vez por oleada si la opcion esta desactivada
        if (UltimatesMut != None && !UltimatesMut.bRepeatPickup && HasPickedUp(Other.Controller))
        {
            bAllowPickup = 0;
            return true;
        }

        W = Weapon(Other.FindInventoryType(item.InventoryType));
        if (W != None && W.AmmoMaxed(0))
        {
            bAllowPickup = 0;
            return true;
        }
    }

    if (NextGameRules != None)
    {
        return NextGameRules.OverridePickupQuery(Other, item, bAllowPickup);
    }

    return false;
}

function bool IsUltimatePickup(Pickup item)
{
    return MutInvasionRedeemerPickup(item) != None
        || MutInvasionIonPainterPickup(item) != None
        || MutInvasionLightningGunPickup(item) != None;
}
