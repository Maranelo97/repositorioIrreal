class MutKayros extends Mutator;

var int CurrentWaveNum;
var PlayerController ChosenPlayer;
var PlayerController PreviousChosenPlayer;
var int KayrosState; // 0 = Ninguno, 1 = Mucho Kayros (+20%), 2 = Poco Kayros (-20%)

// Ajustes diferidos al mismo frame/tick para UDamagePack y WeaponPickup
var bool bPendingUDamage;
var xPawn PendingUDamagePawn;
var float PendingUDamageFactor;

var bool bPendingWeaponAmmo;
var Pawn PendingWeaponPawn;
var class<Weapon> PendingWeaponClass;
var int PendingWeaponOldAmmo;
var float PendingWeaponFactor;

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

function float GetFactorForPawn(Pawn Other)
{
    if (Other == None || Other.Controller == None || ChosenPlayer == None)
    {
        return 1.00;
    }

    // Nunca afecta a bots, solo al unico jugador humano elegido en esta ronda
    if (PlayerController(Other.Controller) == ChosenPlayer)
    {
        if (KayrosState == 1)
        {
            return 1.20;
        }
        else if (KayrosState == 2)
        {
            return 0.80;
        }
    }

    return 1.00;
}

function PreparePickupForPawn(Pawn Other, Pickup item)
{
    local float Factor;
    local TournamentHealth TH;
    local ShieldPickup SP;
    local AdrenalinePickup AP;
    local Ammo AM;
    local WeaponPickup WP;
    local Weapon ExistingWeap;

    if (Other == None || item == None)
    {
        return;
    }

    Factor = GetFactorForPawn(Other);

    // 1. Salud (Viales, Botiquines, Super Keg)
    TH = TournamentHealth(item);
    if (TH != None)
    {
        TH.HealingAmount = Max(1, int(float(TH.Default.HealingAmount) * Factor + 0.5));
        return;
    }

    // 2. Escudos (ShieldPack 50, SuperShieldPack 100)
    SP = ShieldPickup(item);
    if (SP != None)
    {
        SP.ShieldAmount = Max(1, int(float(SP.Default.ShieldAmount) * Factor + 0.5));
        return;
    }

    // 3. Pastillas de Adrenalina
    AP = AdrenalinePickup(item);
    if (AP != None)
    {
        AP.AdrenalineAmount = AP.Default.AdrenalineAmount * Factor;
        return;
    }

    // 4. Cajas de municion del piso
    AM = Ammo(item);
    if (AM != None)
    {
        AM.AmmoAmount = Max(1, int(float(AM.Default.AmmoAmount) * Factor + 0.5));
        return;
    }

    // 5. Double Damage (UDamagePack: 36s con Mucho Kayros, 24s con Poco Kayros)
    if (UDamagePack(item) != None && Factor != 1.00 && xPawn(Other) != None)
    {
        bPendingUDamage = true;
        PendingUDamagePawn = xPawn(Other);
        PendingUDamageFactor = Factor;
        return;
    }

    // 6. Armas del suelo (modifica en +20% o -20% las balas otorgadas al levantar el arma)
    WP = WeaponPickup(item);
    if (WP != None && Factor != 1.00 && class<Weapon>(WP.InventoryType) != None)
    {
        bPendingWeaponAmmo = true;
        PendingWeaponPawn = Other;
        PendingWeaponClass = class<Weapon>(WP.InventoryType);
        PendingWeaponFactor = Factor;

        ExistingWeap = Weapon(Other.FindInventoryType(PendingWeaponClass));
        if (ExistingWeap != None)
        {
            PendingWeaponOldAmmo = ExistingWeap.AmmoAmount(0);
        }
        else
        {
            PendingWeaponOldAmmo = 0;
        }
    }
}

function Tick(float DeltaTime)
{
    local Weapon W;
    local int NewAmmo, GainedAmmo, AmmoDelta;

    Super.Tick(DeltaTime);

    // Aplica la duracion modificada del Double Damage (36s o 24s) apenas termina Touch()
    if (bPendingUDamage)
    {
        bPendingUDamage = false;
        if (PendingUDamagePawn != None && PendingUDamagePawn.Health > 0 && PendingUDamagePawn.HasUDamage())
        {
            PendingUDamagePawn.UDamageTime = 0.0;
            PendingUDamagePawn.EnableUDamage(30.0 * PendingUDamageFactor);
        }
        PendingUDamagePawn = None;
    }

    // Aplica el +20% o -20% de municion al levantar un arma del piso
    if (bPendingWeaponAmmo)
    {
        bPendingWeaponAmmo = false;
        if (PendingWeaponPawn != None && PendingWeaponPawn.Health > 0 && PendingWeaponClass != None)
        {
            W = Weapon(PendingWeaponPawn.FindInventoryType(PendingWeaponClass));
            if (W != None)
            {
                NewAmmo = W.AmmoAmount(0);
                GainedAmmo = NewAmmo - PendingWeaponOldAmmo;
                if (GainedAmmo > 0)
                {
                    if (PendingWeaponFactor > 1.00)
                    {
                        AmmoDelta = Max(1, int(float(GainedAmmo) * (PendingWeaponFactor - 1.00) + 0.5));
                        W.AddAmmo(AmmoDelta, 0);
                    }
                    else if (PendingWeaponFactor < 1.00)
                    {
                        // Sin minimo de 1 y nunca toda la municion recogida: con armas de una
                        // sola carga (Redeemer) la reduccion es 0 y el jugador conserva el arma.
                        AmmoDelta = Min(int(float(GainedAmmo) * (1.00 - PendingWeaponFactor) + 0.5), GainedAmmo - 1);
                        if (AmmoDelta > 0)
                        {
                            W.ConsumeAmmo(0, AmmoDelta);
                        }
                    }
                }
            }
        }
        PendingWeaponPawn = None;
        PendingWeaponClass = None;
    }
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

    // 50% Mucho Kayros (Buff +20%) / 50% Poco Kayros (Debuff -20%)
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
    CurrentWaveNum=-1
    GroupName="KayrosMut"
    FriendlyName="[Irreal] Poco o mucho Kayros?"
    Description="En cada ronda elige a 1 jugador humano al azar y le otorga Mucho Kayros (+20% en todos los pickups) o Poco Kayros (-20% en todos los pickups)."
}
