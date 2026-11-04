class KayrosRules extends GameRules;

var MutKayros KayrosMut;

// Cambia el dano que hace y que recibe el jugador elegido. Si se lastima a si mismo (por
// ejemplo con un cohete) cuenta solo como dano recibido.
function int NetDamage(int OriginalDamage, int Damage, Pawn injured, Pawn instigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
    local float Factor;

    if (NextGameRules != None)
    {
        Damage = NextGameRules.NetDamage(OriginalDamage, Damage, injured, instigatedBy, HitLocation, Momentum, DamageType);
    }

    // No convierte impactos nulos o curativos en dano
    if (KayrosMut == None || Damage <= 0)
    {
        return Damage;
    }

    Factor = 1.0;
    if (KayrosMut.IsChosenPawn(injured))
        Factor = KayrosMut.GetReceivedFactor();
    else if (KayrosMut.IsChosenPawn(instigatedBy))
        Factor = KayrosMut.GetDealtFactor();

    if (Factor != 1.0)
        Damage = Max(1, int(float(Damage) * Factor + 0.5));

    return Damage;
}
