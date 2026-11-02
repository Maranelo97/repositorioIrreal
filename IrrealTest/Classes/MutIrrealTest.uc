// Mutador SOLO PARA PRUEBAS. No se distribuye con MyInvasionMut.
// Agrega comandos de consola para el host (o un admin) que llaman a las
// funciones de los mutadores de MyInvasionMut, para probarlos sin esperar.
class MutIrrealTest extends Mutator;

var bool bInteractionAdded;

function PostBeginPlay()
{
    Super.PostBeginPlay();
    SetTimer(1.0, true);
}

// Cuando el jugador local (el host) ya esta listo, le agrega el comando "irreal"
function Timer()
{
    local PlayerController PC;

    if (bInteractionAdded)
        return;

    PC = Level.GetLocalPlayerController();
    if (PC != None && PC.Player != None && PC.Player.InteractionMaster != None)
    {
        PC.Player.InteractionMaster.AddInteraction("IrrealTest.IrrealTestInteraction", PC.Player);
        bInteractionAdded = true;
        SetTimer(0.0, false);
    }
}

function bool IsHostOrAdmin(PlayerController PC)
{
    if (PC == None)
    {
        return false;
    }

    if (PC.PlayerReplicationInfo != None && PC.PlayerReplicationInfo.bAdmin)
    {
        return true;
    }

    return Viewport(PC.Player) != None;
}

function Mutate(string MutateString, PlayerController Sender)
{
    local string Cmd, Arg;
    local int i;

    if (Sender != None && Left(MutateString, 4) ~= "test" && (Len(MutateString) == 4 || Mid(MutateString, 4, 1) == " "))
    {
        if (!IsHostOrAdmin(Sender))
        {
            Sender.ClientMessage("Solo el host o un admin puede usar los comandos de prueba.");
        }
        else
        {
            Cmd = Mid(MutateString, 5);
            i = InStr(Cmd, " ");
            if (i >= 0)
            {
                Arg = Mid(Cmd, i + 1);
                Cmd = Left(Cmd, i);
            }
            RunCommand(Locs(Cmd), Locs(Arg), Sender);
        }
    }

    Super.Mutate(MutateString, Sender);
}

function RunCommand(string Cmd, string Arg, PlayerController Sender)
{
    if (Cmd == "kill")
        EndWave(Sender);
    else if (Cmd == "cthulhu" || Cmd == "cutulu")
        SpawnCthulhu(Sender);
    else if (Cmd == "infectado")
        SpawnKrall(Sender);
    else if (Cmd == "kayros")
        GiveKayros(Arg, Sender);
    else if (Cmd == "ulti")
        SetUltimateWeapon(Arg, Sender);
    else
        ShowHelp(Sender);
}

function ShowHelp(PlayerController Sender)
{
    Sender.ClientMessage("Comandos de prueba (irreal ... o mutate test ...):");
    Sender.ClientMessage("  irreal kill - mata a todos los monstruos y termina la oleada");
    Sender.ClientMessage("  irreal cthulhu (o cutulu) - hace aparecer al Rey Cthulhu");
    Sender.ClientMessage("  irreal infectado - hace aparecer al Elite Krall infectado");
    Sender.ClientMessage("  irreal kayros poco/mucho - te da Poco o Mucho Kayros");
    Sender.ClientMessage("  irreal ulti 1-4 - cambia el arma ultima: 1 Redeemer, 2 Target Painter, 3 Ion Painter, 4 Lightning Gun");
}

function Invasion GetWaveInProgress(PlayerController Sender)
{
    local Invasion InvGame;

    InvGame = Invasion(Level.Game);
    if (InvGame == None)
    {
        Sender.ClientMessage("Este comando solo funciona en Invasion.");
        return None;
    }
    if (!InvGame.bWaveInProgress)
    {
        Sender.ClientMessage("Este comando solo funciona durante una oleada.");
        return None;
    }
    return InvGame;
}

function EndWave(PlayerController Sender)
{
    local Invasion InvGame;
    local MutMarianoskyRage RageMut;
    local Controller C;
    local array<Pawn> Victims;
    local int i;

    InvGame = GetWaveInProgress(Sender);
    if (InvGame == None)
        return;

    // Invasion termina la oleada cuando paso su tiempo, ya aparecieron todos
    // sus monstruos (WaveMonsters >= 2 * MaxMonsters) y no queda ninguno vivo.
    InvGame.WaveEndTime = Level.TimeSeconds - 1;
    InvGame.WaveMonsters = Max(InvGame.WaveMonsters, 2 * InvGame.MaxMonsters);

    // Que no aparezca un Rey Cthulhu pendiente despues de limpiar la oleada
    foreach DynamicActors(class'MutMarianoskyRage', RageMut)
    {
        RageMut.bWaveHasChampion = false;
        break;
    }

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        if (Monster(C.Pawn) != None && C.Pawn.Health > 0)
            Victims[Victims.Length] = C.Pawn;
    }

    // KilledBy pasa por Died: Invasion descuenta el monstruo como una muerte normal
    for (i = 0; i < Victims.Length; i++)
    {
        if (Victims[i] != None && !Victims[i].bDeleteMe && Victims[i].Health > 0)
            Victims[i].KilledBy(Victims[i]);
    }

    Sender.ClientMessage("Prueba: " $ Victims.Length $ " monstruos eliminados, la oleada termina.");
}

function SpawnCthulhu(PlayerController Sender)
{
    local Invasion InvGame;
    local MutMarianoskyRage RageMut;
    local Controller C;
    local Monster Boss;

    InvGame = GetWaveInProgress(Sender);
    if (InvGame == None)
        return;

    foreach DynamicActors(class'MutMarianoskyRage', RageMut)
        break;
    if (RageMut == None)
    {
        Sender.ClientMessage("Marianosky's rage no esta activo.");
        return;
    }

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        if (Monster(C.Pawn) != None && C.Pawn.Health > 0 && C.Pawn.Tag == 'ChampionMonster')
        {
            Sender.ClientMessage("El Rey Cthulhu ya esta en la partida.");
            return;
        }
    }

    Boss = RageMut.SpawnChampionWarLord(InvGame);
    if (Boss == None)
    {
        Sender.ClientMessage("No se encontro un lugar para hacer aparecer al Rey Cthulhu.");
        return;
    }

    RageMut.bWaveHasChampion = true;
    RageMut.bChampionSpawnedThisWave = true;
    RageMut.PromoteToChampion(Boss);
    Sender.ClientMessage("Prueba: Rey Cthulhu creado.");
}

function SpawnKrall(PlayerController Sender)
{
    local Invasion InvGame;
    local MutLeTransmitoTodoAMiBB InfectMut;

    InvGame = GetWaveInProgress(Sender);
    if (InvGame == None)
        return;

    foreach DynamicActors(class'MutLeTransmitoTodoAMiBB', InfectMut)
        break;
    if (InfectMut == None)
    {
        Sender.ClientMessage("Le transmito todo a mi BB no esta activo.");
        return;
    }

    if (InfectMut.SpawnEliteKrall(InvGame) == None)
    {
        Sender.ClientMessage("No se encontro un lugar para hacer aparecer al Elite Krall.");
        return;
    }

    Sender.ClientMessage("Prueba: Elite Krall infectado creado.");
    if (InvGame.WaveNum < 8)
        Sender.ClientMessage("Ojo: el contagio solo funciona desde la oleada 9.");
}

function GiveKayros(string Arg, PlayerController Sender)
{
    local MutKayros KayrosMut;
    local MutChatDokaBots ChatMut;
    local int NewState;

    if (Arg == "mucho")
        NewState = 1;
    else if (Arg == "poco")
        NewState = 2;
    else
    {
        Sender.ClientMessage("Uso: irreal kayros poco/mucho");
        return;
    }

    foreach DynamicActors(class'MutKayros', KayrosMut)
        break;
    if (KayrosMut == None)
    {
        Sender.ClientMessage("Poco o mucho Kayros no esta activo.");
        return;
    }

    // Igual que el sorteo de cada oleada, pero eligiendo siempre a quien usa el comando
    KayrosMut.ChosenPlayer = Sender;
    KayrosMut.PreviousChosenPlayer = Sender;
    KayrosMut.KayrosState = NewState;
    Sender.ReceiveLocalizedMessage(class'KayrosMessage', NewState);

    foreach DynamicActors(class'MutChatDokaBots', ChatMut)
    {
        ChatMut.TriggerKayrosSnitchChat(Sender, NewState == 1);
        break;
    }

    Sender.ClientMessage("Prueba: Kayros asignado hasta la proxima oleada.");
}

function SetUltimateWeapon(string Arg, PlayerController Sender)
{
    local MutInvasionUltimates UltMut;
    local int WeaponIndex;
    local string WeaponName;

    // Mismo orden que MutInvasionUltimates.SetUltimate; tambien acepta los nombres
    if (Arg == "1" || Arg == "redeemer")
    {
        WeaponIndex = 0;
        WeaponName = "Redeemer";
    }
    else if (Arg == "2" || Arg == "painter")
    {
        WeaponIndex = 1;
        WeaponName = "Target Painter";
    }
    else if (Arg == "3" || Arg == "ion")
    {
        WeaponIndex = 2;
        WeaponName = "Ion Painter";
    }
    else if (Arg == "4" || Arg == "lightning")
    {
        WeaponIndex = 3;
        WeaponName = "Lightning Gun";
    }
    else
    {
        Sender.ClientMessage("Uso: irreal ulti 1-4 (1 Redeemer, 2 Target Painter, 3 Ion Painter, 4 Lightning Gun)");
        return;
    }

    foreach DynamicActors(class'MutInvasionUltimates', UltMut)
        break;
    if (UltMut == None)
    {
        Sender.ClientMessage("Invasion: Armas ultimas no esta activo.");
        return;
    }
    if (UltMut.UltimateBase == None)
    {
        Sender.ClientMessage("Armas ultimas todavia no eligio su punto; proba de nuevo en unos segundos.");
        return;
    }

    UltMut.SetUltimate(WeaponIndex);
    Sender.ClientMessage("Prueba: arma ultima cambiada a " $ WeaponName $ " hasta la proxima oleada.");
}

defaultproperties
{
    GroupName="IrrealTest"
    FriendlyName="[Irreal_Test] PRUEBAS (no distribuir)"
    Description="Comandos de prueba para el host: irreal kill, cthulhu (o cutulu), infectado, kayros poco/mucho y ulti 1-4 (tambien con mutate test). Escribir irreal para ver la ayuda. Solo para probar; no usar en partidas con amigos."
}
