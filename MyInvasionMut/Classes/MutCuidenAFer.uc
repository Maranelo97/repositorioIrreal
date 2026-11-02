class MutCuidenAFer extends Mutator;

var Controller CurrentFerController;
var Controller PreviousFerController;
var Pawn FerPawn;
var FerBRVisual FerVisual;
var PlayerController CurrentFerPC;
var float PreviousFerHandedness;
var bool bSavedFerHandedness;
var MutCuidenAFerRules FerRules;
var int CurrentWaveNum;
var bool bWaveWasActive;
var bool bBetweenRounds;
var bool bCompatibilityBlocked;
var bool bBlockMessageSent;
var bool bEndingGame;
var float IntermissionEndTime;
var float NoFerSince;
var string IncompatibleMutators;

function PostBeginPlay()
{
    Super.PostBeginPlay();
    CurrentWaveNum = -1;
    if (Invasion(Level.Game) == None)
    {
        bCompatibilityBlocked = true;
        IncompatibleMutators = "Cuiden a Fer! solo funciona en Invasion.";
    }
    else
    {
        FindIncompatibleMutators();
    }
    if (bCompatibilityBlocked && Invasion(Level.Game) != None)
        Invasion(Level.Game).WaveCountDown = 9999;
    else if (!bCompatibilityBlocked)
        InstallRules();
    SetTimer(0.25, true);
}

function bool IsAllowedMutator(Mutator M)
{
    return M == Self
        || M.Class == class'MyInvasionMut.MutNeedMoreBots'
        || M.Class == class'MyInvasionMut.MutChatDokaBots'
        || M.Class == class'MyInvasionMut.MutInvasionUltimates'
        || M.Class == class'XGame.MutQuadJump'
        // Mutador que Invasion agrega automaticamente como componente interno.
        || M.Class == class'SkaarjPack.InvasionMutator';
}

function FindIncompatibleMutators()
{
    local Mutator M;
    local GameInfo GI;

    GI = Level.Game;
    if (GI == None)
        return;

    for (M = GI.BaseMutator; M != None; M = M.NextMutator)
    {
        if (!IsAllowedMutator(M))
        {
            bCompatibilityBlocked = true;
            if (IncompatibleMutators != "")
                IncompatibleMutators = IncompatibleMutators $ ", ";
            IncompatibleMutators = IncompatibleMutators $ string(M.Class);
        }
    }
}

function InstallRules()
{
    if (Level.Game == None || FerRules != None)
        return;

    FerRules = Spawn(class'MutCuidenAFerRules');
    if (FerRules != None)
    {
        FerRules.FerMutator = Self;
        if (Level.Game.GameRulesModifiers == None)
            Level.Game.GameRulesModifiers = FerRules;
        else
            Level.Game.GameRulesModifiers.AddGameRules(FerRules);
    }
}

function NotifyIncompatiblePlayers()
{
    local Controller C;
    local PlayerController PC;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        PC = PlayerController(C);
        if (PC != None)
            PC.ClientMessage("Cuiden a Fer! PARTIDA BLOQUEADA: " $ IncompatibleMutators, 'CriticalEvent');
    }
}

function bool HasConnectedPlayer()
{
    local Controller C;
    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        if (PlayerController(C) != None)
            return true;
    }
    return false;
}
function StopForIncompatibility()
{
    if (bBlockMessageSent || Level.Game == None)
        return;

    NotifyIncompatiblePlayers();
    bBlockMessageSent = true;
    bEndingGame = true;
    Level.Game.EndGame(None, "CuidenAFer_IncompatibleMutators");
}

function bool IsEligibleFer(Controller C)
{
    return C != None && C != PreviousFerController
        && C.PlayerReplicationInfo != None && !C.PlayerReplicationInfo.bOnlySpectator
        && (PlayerController(C) != None || Bot(C) != None)
        && C.Pawn != None && C.Pawn.Health > 0 && Monster(C.Pawn) == None;
}

function bool IsControllerPresent(Controller TargetController)
{
    local Controller C;
    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        if (C == TargetController)
            return true;
    }
    return false;
}
function Controller PickFer()
{
    local Controller C, Chosen;
    local int Count;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        if (IsEligibleFer(C))
        {
            Count++;
            if (Rand(Count) == 0)
                Chosen = C;
        }
    }
    return Chosen;
}

function SetFerPawnRestrictions(Pawn P, bool bEnable)
{
    local xPawn XP;

    if (P == None)
        return;

    XP = xPawn(P);
    if (bEnable)
    {
        P.bNoWeaponFiring = true;
        if (P.Weapon != None)
            P.Weapon.bHidden = true;
        if (XP != None && XP.WeaponAttachment != None)
            XP.WeaponAttachment.bHidden = true;
    }
    else
    {
        P.bNoWeaponFiring = P.Default.bNoWeaponFiring;
        if (P.Weapon != None)
            P.Weapon.bHidden = false;
        if (XP != None && XP.WeaponAttachment != None)
            XP.WeaponAttachment.bHidden = false;
    }
}

function RemoveFerVisual()
{
    if (FerVisual != None)
    {
        FerVisual.Destroy();
        FerVisual = None;
    }
}

function ClearFer()
{
    if (CurrentFerController != None && CurrentFerController.Pawn != None)
        SetFerPawnRestrictions(CurrentFerController.Pawn, false);

    if (bSavedFerHandedness && CurrentFerPC != None)
        CurrentFerPC.Handedness = PreviousFerHandedness;
    bSavedFerHandedness = false;
    CurrentFerPC = None;
    RemoveFerVisual();
    FerPawn = None;
    CurrentFerController = None;
}

function ApplyFerVisual()
{
    if (FerPawn == None)
        return;

    if (FerVisual != None && FerVisual.Base != FerPawn)
    {
        FerVisual.Destroy();
        FerVisual = None;
    }

    if (FerVisual == None)
    {
        FerVisual = Spawn(class'FerBRVisual', self,, FerPawn.Location, FerPawn.Rotation);
        if (FerVisual != None)
            FerPawn.AttachToBone(FerVisual, 'spine');
    }
}

function BroadcastFerMessage(int Switch, Controller FerController)
{
    local PlayerReplicationInfo PRI;
    if (FerController != None)
        PRI = FerController.PlayerReplicationInfo;
    Level.Game.BroadcastLocalizedMessage(class'FerMessage', Switch, PRI);
}

function bool AssignNewFer(bool bReplaceWithinRound)
{
    local Controller NewFer;

    NewFer = PickFer();
    if (NewFer == None)
    {
        if (NoFerSince == 0.0)
            NoFerSince = Level.TimeSeconds;
        return false;
    }

    NoFerSince = 0.0;
    if (bReplaceWithinRound)
        ClearFer();

    CurrentFerController = NewFer;
    CurrentFerPC = PlayerController(NewFer);
    if (CurrentFerPC != None && !bSavedFerHandedness)
    {
        PreviousFerHandedness = CurrentFerPC.Handedness;
        bSavedFerHandedness = true;
    }
    FerPawn = NewFer.Pawn;
    SetFerPawnRestrictions(FerPawn, true);
    ApplyFerVisual();
    BroadcastFerMessage(0, CurrentFerController);
    return true;
}

function ApplyCooldownSpeed(bool bEnable)
{
    local Controller C;
    local Pawn P;
    local float Multiplier;

    Multiplier = 1.0;
    if (bEnable)
        Multiplier = 1.50;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        P = C.Pawn;
        if (C.PlayerReplicationInfo != None && !C.PlayerReplicationInfo.bOnlySpectator
            && P != None && P.Health > 0 && Monster(P) == None)
        {
            P.GroundSpeed = P.Default.GroundSpeed * Multiplier;
            P.AirSpeed = P.Default.AirSpeed * Multiplier;
            P.WaterSpeed = P.Default.WaterSpeed * Multiplier;
            P.AccelRate = P.Default.AccelRate * Multiplier;
        }
    }
}

function StartBetweenRounds(Invasion InvGame)
{
    if (InvGame == None || InvGame.WaveNum >= InvGame.FinalWave)
        return;

    PreviousFerController = CurrentFerController;
    ClearFer();
    bBetweenRounds = true;
    IntermissionEndTime = Level.TimeSeconds + 90.0;
    InvGame.WaveCountDown = 9999;
    ApplyCooldownSpeed(true);
}

function ForceMonstersToFer()
{
    local MonsterController MC;

    if (FerPawn == None || FerPawn.Health <= 0)
        return;

    foreach AllActors(class'SkaarjPack.MonsterController', MC)
    {
        if (MC != None && MC.Pawn != None && MC.Pawn.Health > 0 && MC.Enemy != FerPawn)
            MC.ChangeEnemy(FerPawn, MC.CanSee(FerPawn));
    }
}

function FerDied()
{
    if (bEndingGame || Level.Game == None)
        return;
    bEndingGame = true;
    BroadcastFerMessage(1, CurrentFerController);
    Level.Game.EndGame(None, "CuidenAFer_Died");
}

function Timer()
{
    local Invasion InvGame;
    local float TimeLeft;

    if (bCompatibilityBlocked)
    {
        InvGame = Invasion(Level.Game);
        if (InvGame != None)
            InvGame.WaveCountDown = 9999;
        if (HasConnectedPlayer())
            StopForIncompatibility();
        return;
    }

    InvGame = Invasion(Level.Game);
    if (InvGame == None || Level.Game.bGameEnded)
        return;

    if (bBetweenRounds)
    {
        TimeLeft = IntermissionEndTime - Level.TimeSeconds;
        if (TimeLeft > 0.0)
        {
            InvGame.WaveCountDown = 9999;
            ApplyCooldownSpeed(true);
            
            return;
        }
        bBetweenRounds = false;
        ApplyCooldownSpeed(false);
        InvGame.WaveCountDown = 1;
    }

    if (InvGame.bWaveInProgress)
    {
        if (InvGame.WaveNum != CurrentWaveNum)
        {
            CurrentWaveNum = InvGame.WaveNum;
            if (CurrentFerController != None)
            {
                PreviousFerController = CurrentFerController;
                ClearFer();
            }
            if (!AssignNewFer(false))
            {
                if (NoFerSince > 0.0 && Level.TimeSeconds - NoFerSince > 10.0)
                {
                    IncompatibleMutators = "No hay otro jugador activo para elegir como Fer sin repetir al de la ronda anterior.";
                    bCompatibilityBlocked = true;
                    InvGame.WaveCountDown = 9999;
                    return;
                }
            }
        }

        bWaveWasActive = true;
        if (CurrentFerController == None)
        {
            if (!AssignNewFer(false) && NoFerSince > 0.0 && Level.TimeSeconds - NoFerSince > 10.0)
            {
                IncompatibleMutators = "No hay otro jugador activo para elegir como Fer sin repetir al de la ronda anterior.";
                bCompatibilityBlocked = true;
                InvGame.WaveCountDown = 9999;
                return;
            }
        }
        else if (!IsControllerPresent(CurrentFerController)
            || CurrentFerController.PlayerReplicationInfo == None
            || CurrentFerController.PlayerReplicationInfo.bOnlySpectator)
        {
            ClearFer();
            if (!AssignNewFer(true) && NoFerSince > 0.0 && Level.TimeSeconds - NoFerSince > 10.0)
            {
                IncompatibleMutators = "Fer se desconecto y no hay un reemplazo valido sin repetir la ronda anterior.";
                bCompatibilityBlocked = true;
                InvGame.WaveCountDown = 9999;
                return;
            }
        }
        else if (CurrentFerController.Pawn == None || CurrentFerController.Pawn.Health <= 0)
        {
            FerDied();
            return;
        }

        if (CurrentFerController != None && CurrentFerController.Pawn != FerPawn)
        {
            FerPawn = CurrentFerController.Pawn;
            SetFerPawnRestrictions(FerPawn, true);
            ApplyFerVisual();
        }
        if (CurrentFerController != None)
        {
            SetFerPawnRestrictions(FerPawn, true);
            if (CurrentFerPC != None)
                CurrentFerPC.Handedness = 2.0;
        }
        ForceMonstersToFer();
    }
    else if (bWaveWasActive && InvGame.NumMonsters <= 0 && !bBetweenRounds)
    {
        bWaveWasActive = false;
        StartBetweenRounds(InvGame);
    }
}

function ModifyPlayer(Pawn Other)
{
    Super.ModifyPlayer(Other);
    if (Other != None && Other == FerPawn)
        SetFerPawnRestrictions(Other, true);
}

defaultproperties
{
    GroupName="CuidenAFer"
    FriendlyName="[Irreal] Cuiden a Fer!"
    Description="Cada oleada de Invasion un jugador al azar (humano o bot) es Fer: no puede disparar ni levantar armas, municion o adrenalina, y todos los monstruos lo persiguen. Si Fer muere, termina la partida. Entre oleadas hay 90 segundos de descanso con +50% de velocidad. Solo compatible con [Irreal] Necesitamos mas BOTS, [Irreal] Chat-doka Bots, [Irreal] Invasion: Armas ultimas y Salto cuadruple (QuadJump). Bloquea partidas con otros mutadores."
}
