// Disparo de la Lightning Gun de Murio una banda de gente: el mismo del juego (SniperFire) y,
// si el rayo le pega a un monstruo, salta a otros monstruos cercanos ("rayo en cadena"), cada
// salto con menos dano. Los saltos, el dano y el alcance salen de las opciones del mutador.
// Todo pasa en el servidor; los rayos son los mismos efectos del juego, que llegan a todos.
class UltiLightningFire extends SniperFire;

var float ChainRange;    // distancia maxima de cada salto

// Copia de SniperFire.DoTrace, con el rayo en cadena al final (ver ChainLightning)
function DoTrace(Vector Start, Rotator Dir)
{
    local Vector X,Y,Z, End, HitLocation, HitNormal, RefNormal;
    local Actor Other, mainArcHitTarget;
    local int Damage, ReflectNum, arcsRemaining, FirstDamage;
    local bool bDoReflect;
    local xEmitter hitEmitter;
    local class<Actor> tmpHitEmitClass;
    local float tmpTraceRange;
    local vector arcEnd, mainArcHit;
    local Pawn HeadShotPawn;
    local vector EffectOffset;

    if ( class'PlayerController'.Default.bSmallWeapons )
        EffectOffset = Weapon.SmallEffectOffset;
    else
        EffectOffset = Weapon.EffectOffset;

    Weapon.GetViewAxes(X, Y, Z);
    if ( Weapon.WeaponCentered() || SniperRifle(Weapon).zoomed )
        arcEnd = (Instigator.Location + EffectOffset.Z * Z);
    else if ( Weapon.Hand == 0 )
    {
        if ( class'PlayerController'.Default.bSmallWeapons )
            arcEnd = (Instigator.Location + EffectOffset.X * X);
        else
            arcEnd = (Instigator.Location + EffectOffset.X * X - 0.5 * EffectOffset.Z * Z);
    }
    else
        arcEnd = (Instigator.Location + Instigator.CalcDrawOffset(Weapon) + EffectOffset.X * X
            + Weapon.Hand * EffectOffset.Y * Y + EffectOffset.Z * Z);

    arcsRemaining = NumArcs;
    tmpHitEmitClass = HitEmitterClass;
    tmpTraceRange = TraceRange;

    ReflectNum = 0;
    while (true)
    {
        bDoReflect = false;
        X = Vector(Dir);
        End = Start + tmpTraceRange * X;
        Other = Weapon.Trace(HitLocation, HitNormal, End, Start, true);

        if ( Other != None && (Other != Instigator || ReflectNum > 0) )
        {
            if (bReflective && Other.IsA('xPawn') && xPawn(Other).CheckReflect(HitLocation, RefNormal, DamageMin*0.25))
            {
                bDoReflect = true;
            }
            else if ( Other != mainArcHitTarget )
            {
                if ( !Other.bWorldGeometry )
                {
                    Damage = (DamageMin + Rand(DamageMax - DamageMin)) * DamageAtten;
                    if ( arcsRemaining == NumArcs )
                        FirstDamage = Damage;

                    if (Vehicle(Other) != None)
                        HeadShotPawn = Vehicle(Other).CheckForHeadShot(HitLocation, X, 1.0);

                    if (HeadShotPawn != None)
                        HeadShotPawn.TakeDamage(Damage * HeadShotDamageMult, Instigator, HitLocation, Momentum*X, DamageTypeHeadShot);
                    else if ( (Pawn(Other) != None) && (arcsRemaining == NumArcs)
                        && Pawn(Other).IsHeadShot(HitLocation, X, 1.0) )
                        Other.TakeDamage(Damage * HeadShotDamageMult, Instigator, HitLocation, Momentum*X, DamageTypeHeadShot);
                    else
                    {
                        if ( arcsRemaining < NumArcs )
                            Damage *= SecDamageMult;
                        Other.TakeDamage(Damage, Instigator, HitLocation, Momentum*X, DamageType);
                    }
                }
                else
                    HitLocation = HitLocation + 2.0 * HitNormal;
            }
        }
        else
        {
            HitLocation = End;
            HitNormal = Normal(Start - End);
        }
        if ( Weapon == None )
            return;
        hitEmitter = xEmitter(Weapon.Spawn(tmpHitEmitClass,,, arcEnd, Rotator(HitNormal)));
        if ( hitEmitter != None )
            hitEmitter.mSpawnVecA = HitLocation;
        if ( HitScanBlockingVolume(Other) != None )
            return;

        if( arcsRemaining == NumArcs )
        {
            mainArcHit = HitLocation + (HitNormal * 2.0);
            if ( Other != None && !Other.bWorldGeometry )
                mainArcHitTarget = Other;
        }

        if (bDoReflect && ++ReflectNum < 4)
        {
            Start = HitLocation;
            Dir = Rotator( X - 2.0*RefNormal*(X dot RefNormal) );
        }
        else if ( arcsRemaining > 0 )
        {
            arcsRemaining--;
            Start = mainArcHit;
            Dir = Rotator(VRand());
            tmpHitEmitClass = SecHitEmitterClass;
            tmpTraceRange = SecTraceDist;
            arcEnd = mainArcHit;
        }
        else
        {
            break;
        }
    }

    if ( Monster(mainArcHitTarget) != None && FirstDamage > 0 )
        ChainLightning(Monster(mainArcHitTarget), FirstDamage);
}

// El rayo en cadena es de Murio una banda de gente: con GIGACHADrenalina solo, su Lightning Gun
// (que hereda de UltiLightningGun) es la comun
function bool UltimatesActive()
{
    local MutInvasionUltimates M;

    foreach Weapon.DynamicActors(class'MutInvasionUltimates', M)
        return true;
    return false;
}

// Desde el monstruo golpeado salta al monstruo vivo mas cercano que se vea desde ahi y todavia
// no recibio este disparo; cada salto hace menos dano que el anterior, segun la opcion
function ChainLightning(Monster First, int FirstDamage)
{
    local array<Pawn> Hit;
    local Pawn From, Best;
    local Controller C;
    local Monster M;
    local float Dist, BestDist, Damage;
    local int Jump, Jumps, i;
    local bool bAlready;
    local xEmitter Bolt;

    if ( !class'MutInvasionUltimates'.default.bChainLightning || Weapon == None || !UltimatesActive() )
        return;

    Jumps = Clamp(class'MutInvasionUltimates'.default.ChainJumps, 1, 5);
    Damage = FirstDamage;
    From = First;
    Hit[0] = First;

    for (Jump = 0; Jump < Jumps; Jump++)
    {
        Damage *= float(100 - Clamp(class'MutInvasionUltimates'.default.ChainDamageReduction, 0, 99)) / 100.0;
        if ( Damage < 1 )
            return;

        Best = None;
        BestDist = ChainRange;
        for (C = Level.ControllerList; C != None; C = C.NextController)
        {
            M = Monster(C.Pawn);
            if ( M == None || M.Health <= 0 || M.bDeleteMe )
                continue;
            bAlready = false;
            for (i = 0; i < Hit.Length; i++)
                if ( Hit[i] == M )
                    bAlready = true;
            if ( bAlready )
                continue;
            Dist = VSize(M.Location - From.Location);
            if ( Dist < BestDist && Weapon.FastTrace(M.Location, From.Location) )
            {
                Best = M;
                BestDist = Dist;
            }
        }
        if ( Best == None )
            return;

        // El rayo del juego, de un monstruo al otro
        Bolt = Weapon.Spawn(HitEmitterClass,,, From.Location, Rotator(Best.Location - From.Location));
        if ( Bolt != None )
            Bolt.mSpawnVecA = Best.Location;

        Hit[Hit.Length] = Best;
        Best.TakeDamage(int(Damage + 0.5), Instigator, Best.Location, vect(0,0,0), DamageType);
        From = Best;
        if ( Weapon == None || From == None || From.bDeleteMe )
            return;
    }
}

defaultproperties
{
    ChainRange=1000.0
}
