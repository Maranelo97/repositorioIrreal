// Cuentas compartidas por las armas ultimas de GIGACHADrenalina: en vez de municion,
// cada disparo cuesta adrenalina. El "contador de municion" es la cantidad de disparos
// que alcanza la adrenalina actual.
class GigaAdrenalina extends Object
    abstract;

// Disparos que alcanza la adrenalina actual del duenio del arma
static function int Shots(Weapon W, int Cost)
{
    if (W == None || W.Instigator == None || W.Instigator.Controller == None)
        return 0;
    if (Cost <= 0)
        return 999;
    return int(W.Instigator.Controller.Adrenaline / float(Cost));
}

// Disparos con la adrenalina llena (para la barra de municion del HUD)
static function int MaxShots(int Cost)
{
    if (Cost <= 0)
        return 999;
    return Max(1, 100 / Cost);
}

// Llena la adrenalina de quien agarro un arma ultima (opcion bFillAdrenalineOnPickup)
static function FillOnPickup(Pawn P)
{
    if (!class'MutGigachadrenalina'.default.bFillAdrenalineOnPickup)
        return;
    if (P == None || P.Controller == None || !P.Controller.bAdrenalineEnabled)
        return;
    P.Controller.Adrenaline = P.Controller.AdrenalineMax;
}

// Cobra el disparo. Solo el servidor descuenta: la adrenalina se replica al jugador.
static function bool Spend(Weapon W, int Cost, float Load)
{
    local Controller C;

    if (W == None || W.Role < ROLE_Authority || Load <= 0 || Cost <= 0)
        return true;
    if (W.Instigator == None || W.Instigator.Controller == None)
        return false;

    C = W.Instigator.Controller;
    if (C.Adrenaline < Cost * Load)
        return false;
    C.Adrenaline = FMax(0, C.Adrenaline - Cost * Load);
    return true;
}
