class MutChatDokaBots extends Mutator;

var string Phrases[50];
var string CthulhuPhrases[9];
var string UltimateKillPhrases[6];
var int LastPhraseIndex;
var float LastChatTime;
var float NextRandomChatTime;
var int LastWaveNum;
var bool bWasWaveActive;
var bool bChampionAnnounced;

// Opciones de "Configurar mutadores"; quedan guardadas en el .ini del juego del host
var config bool bSilenceBotVoice;        // silencia los mensajes de voz normales de los bots
var config bool bRandomPhrases;          // frases al azar (las de cada tantos segundos y las de bajas, poca vida y oleadas)
var config bool bDeathTaunts;            // burlas por nombre al morir un jugador
var config bool bCthulhuReactions;       // reaccion cuando aparece el Rey Cthulhu
var config bool bUltimateKillReactions;  // festejos de bajas con Redeemer / Ion Painter
var config int PhraseInterval;           // segundos entre frases al azar

var localized string SilenceBotVoiceText, SilenceBotVoiceDesc;
var localized string RandomPhrasesText, RandomPhrasesDesc;
var localized string DeathTauntsText, DeathTauntsDesc;
var localized string CthulhuReactionsText, CthulhuReactionsDesc;
var localized string UltimateKillReactionsText, UltimateKillReactionsDesc;
var localized string PhraseIntervalText, PhraseIntervalDesc;

// Segundos entre frases al azar, dentro del rango de la opcion
function float ChatInterval()
{
    return float(Clamp(PhraseInterval, 5, 300));
}

function PostBeginPlay()
{
    local ChatDokaRules GR;
    local int i;

    Super.PostBeginPlay();

    // Las frases tienen tildes escritas tal cual en este archivo (ver FixAccents)
    for (i = 0; i < ArrayCount(Phrases); i++)
        Phrases[i] = FixAccents(Phrases[i]);
    for (i = 0; i < ArrayCount(CthulhuPhrases); i++)
        CthulhuPhrases[i] = FixAccents(CthulhuPhrases[i]);
    for (i = 0; i < ArrayCount(UltimateKillPhrases); i++)
        UltimateKillPhrases[i] = FixAccents(UltimateKillPhrases[i]);

    GR = Spawn(class'ChatDokaRules');
    if (Level.Game != None && GR != None)
    {
        GR.ChatMut = self;
        if (Level.Game.GameRulesModifiers == None)
        {
            Level.Game.GameRulesModifiers = GR;
        }
        else
        {
            Level.Game.GameRulesModifiers.AddGameRules(GR);
        }
    }

    if (bSilenceBotVoice && Level.Game != None && Level.Game.BroadcastHandler != None)
        Level.Game.BroadcastHandler.RegisterBroadcastHandler(Spawn(class'ChatDokaBroadcastHandler'));

    LastChatTime = -ChatInterval();
    NextRandomChatTime = Level.TimeSeconds + ChatInterval();
    SetTimer(1.0, true);
}

// Este archivo esta en UTF-8, pero el compilador lo lee byte por byte: una letra con tilde
// (por ejemplo la A con tilde, bytes C3 81) llega como dos caracteres. Esto los vuelve a unir.
// Si el compilador ya la leyo bien, no hay nada que arreglar y la frase queda igual.
static function string FixAccents(string S)
{
    local string Out;
    local int i, Lead, Next;

    for (i = 0; i < Len(S); i++)
    {
        Lead = Asc(Mid(S, i, 1));
        if ((Lead == 194 || Lead == 195) && i + 1 < Len(S))
        {
            Next = Utf8ContinuationByte(Asc(Mid(S, i + 1, 1)));
            if (Next >= 128 && Next < 192)
            {
                if (Lead == 195)
                    Next += 64;
                Out = Out $ Chr(Next);
                i++;
                continue;
            }
        }
        Out = Out $ Mid(S, i, 1);
    }
    return Out;
}

// Segundo byte de la letra con tilde. Si el compilador uso la tabla de Windows (cp1252),
// algunos bytes llegan como otros caracteres (comillas, etc.): se devuelven al byte original.
static function int Utf8ContinuationByte(int C)
{
    switch (C)
    {
        case 8364: return 128;
        case 8218: return 130;
        case 402:  return 131;
        case 8222: return 132;
        case 8230: return 133;
        case 8224: return 134;
        case 8225: return 135;
        case 710:  return 136;
        case 8240: return 137;
        case 352:  return 138;
        case 8249: return 139;
        case 338:  return 140;
        case 381:  return 142;
        case 8216: return 145;
        case 8217: return 146;
        case 8220: return 147;
        case 8221: return 148;
        case 8226: return 149;
        case 8211: return 150;
        case 8212: return 151;
        case 732:  return 152;
        case 8482: return 153;
        case 353:  return 154;
        case 8250: return 155;
        case 339:  return 156;
        case 382:  return 158;
        case 376:  return 159;
    }
    return C;
}

// Frase con tildes y el nombre del jugador en lugar de %n (el nombre no pasa por FixAccents)
function string WithName(string Template, string PlayerName)
{
    return Repl(FixAccents(Template), "%n", PlayerName);
}

function string GetRandomPhrase()
{
    local int Idx;

    Idx = Rand(ArrayCount(Phrases));
    if (Idx == LastPhraseIndex)
    {
        Idx = (Idx + 1 + Rand(ArrayCount(Phrases) - 1)) % ArrayCount(Phrases);
    }
    LastPhraseIndex = Idx;
    return Phrases[Idx];
}

function string GetHumanDeathMockPhrase(string VictimName)
{
    switch (Rand(9))
    {
        case 0:
            return WithName("¡%n, HASTA LOS HUEVOS!", VictimName);
        case 1:
            return WithName("¡NOOO %n, CÓMO TE VAS A MORIR ASÍ CARAJO?!", VictimName);
        case 2:
            return WithName("¡LEVANTATE %n, Y ANDÁ A UNA FÁBRICA, CARAJO!", VictimName);
        case 3:
            return WithName("¡%n MURIÓ! NECESITAMOS MÁS BOTS PARA CARREARLO!", VictimName);
        case 4:
            return WithName("¡MIRÁ CÓMO JUEGAN CON LA VIDA DE %n!", VictimName);
        case 5:
            return WithName("¡%n TENÍA INFORMACIÓN QUE PUEDE LLEVAR AL ARRESTO DE CRISTINA KIRCHNER!", VictimName);
        case 6:
            return WithName("¡A %n LE PEGARON EL TIRO DE MÁXIMO A NÉSTOR!", VictimName);
        case 7:
            return WithName("¡CHAU %n, APROBASTE EL CASTING PARA EL CAJÓN!", VictimName);
        default:
            return WithName("¡%n FUE PIOLADO EN LA SEDE DEL PJ!", VictimName);
    }
}

function Bot PickRandomBot()
{
    local Controller C;
    local Bot B, Chosen;
    local int Count;

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        B = Bot(C);
        if (B != None && B.PlayerReplicationInfo != None)
        {
            Count++;
            if (Rand(Count) == 0)
            {
                Chosen = B;
            }
        }
    }

    return Chosen;
}

function SendBotMessage(Bot Speaker, string Msg)
{
    local Controller C;
    local PlayerController PC;

    if (Speaker == None)
    {
        Speaker = PickRandomBot();
    }

    if (Speaker == None || Speaker.PlayerReplicationInfo == None)
    {
        return;
    }

    LastChatTime = Level.TimeSeconds;
    NextRandomChatTime = Level.TimeSeconds + ChatInterval();

    for (C = Level.ControllerList; C != None; C = C.NextController)
    {
        PC = PlayerController(C);
        if (PC != None)
        {
            PC.TeamMessage(Speaker.PlayerReplicationInfo, Msg, 'Say');
        }
    }
}

function TriggerBotChat(Bot PreferredBot, float Chance)
{
    // Respeta el intervalo entre mensajes de frases generales
    if (!bRandomPhrases || Level.TimeSeconds - LastChatTime < ChatInterval())
    {
        return;
    }

    if (FRand() <= Chance)
    {
        SendBotMessage(PreferredBot, GetRandomPhrase());
    }
}

function TriggerCthulhuBossChat()
{
    local string Msg;

    if (!bCthulhuReactions)
        return;

    Msg = CthulhuPhrases[Rand(ArrayCount(CthulhuPhrases))];
    SendBotMessage(None, Msg);
}

function TriggerUltimateKillChat(Bot KillerBot)
{
    local string Msg;

    if (!bUltimateKillReactions || Level.TimeSeconds - LastChatTime < 2.5)
    {
        return;
    }

    Msg = UltimateKillPhrases[Rand(ArrayCount(UltimateKillPhrases))];
    SendBotMessage(KillerBot, Msg);
}

function TriggerHumanDeathTaunt(Controller DeadHuman)
{
    local string VictimName;

    if (!bDeathTaunts || DeadHuman == None || DeadHuman.PlayerReplicationInfo == None)
    {
        return;
    }

    if (Level.TimeSeconds - LastChatTime < 2.0)
    {
        return;
    }

    VictimName = DeadHuman.PlayerReplicationInfo.PlayerName;
    SendBotMessage(None, GetHumanDeathMockPhrase(VictimName));
}

function string GetKayrosSnitchPhrase(string TargetName, bool bIsMuchoKayros)
{
    if (bIsMuchoKayros)
    {
        switch (Rand(4))
        {
            case 0:
                return WithName("¡MIREN A %n, TIENE MUCHO KAYROS ESTA RONDA!", TargetName);
            case 1:
                return WithName("¡%n LIGÓ MUCHO KAYROS, CÓMO JUEGAN CON MI GUITA!", TargetName);
            case 2:
                return WithName("¡DÉJENLE LOS ÍTEMS A %n QUE TIENE MUCHO KAYROS (+20%)!", TargetName);
            default:
                return WithName("¡QUÉ ORTO %n, TIENE MUCHO KAYROS!", TargetName);
        }
    }
    else
    {
        switch (Rand(4))
        {
            case 0:
                return WithName("¡MIREN A %n, TIENE MUY POCO KAYROS!", TargetName);
            case 1:
                return WithName("¡%n TIENE POCO KAYROS, HASTA LOS HUEVOS!", TargetName);
            case 2:
                return WithName("¡NO LE DEJEN AGARRAR NADA A %n QUE TIENE POCO KAYROS (-20%)!", TargetName);
            default:
                return WithName("¡JAJAJA %n, TE TOCÓ MUY POCO KAYROS ESTA RONDA!", TargetName);
        }
    }
}

function TriggerKayrosSnitchChat(PlayerController TargetPC, bool bIsMuchoKayros)
{
    local string TargetName;

    if (TargetPC == None || TargetPC.PlayerReplicationInfo == None)
    {
        return;
    }

    TargetName = TargetPC.PlayerReplicationInfo.PlayerName;
    SendBotMessage(None, GetKayrosSnitchPhrase(TargetName, bIsMuchoKayros));
}

function Timer()
{
    local Invasion InvGame;
    local Controller C;
    local Monster M;
    local bool bFoundChampion;

    InvGame = Invasion(Level.Game);
    if (InvGame != None)
    {
        // Al empezar una nueva oleada
        if (InvGame.bWaveInProgress && !bWasWaveActive)
        {
            bWasWaveActive = true;
            bChampionAnnounced = false;
            TriggerBotChat(None, 0.85);
        }
        // Al terminar/limpiar una oleada
        else if (!InvGame.bWaveInProgress && bWasWaveActive)
        {
            bWasWaveActive = false;
            TriggerBotChat(None, 0.85);
        }

        // Si aparece el Rey Cthulhu en la partida, los bots reaccionan especificamente al jefe
        if (InvGame.bWaveInProgress && !bChampionAnnounced)
        {
            for (C = Level.ControllerList; C != None; C = C.NextController)
            {
                M = Monster(C.Pawn);
                if (M != None && M.Health > 0 && M.Tag == 'ChampionMonster')
                {
                    bFoundChampion = true;
                    break;
                }
            }
            if (bFoundChampion)
            {
                bChampionAnnounced = true;
                TriggerCthulhuBossChat();
            }
        }
    }

    // Comentarios cada tantos segundos en la partida
    if (bRandomPhrases && Level.TimeSeconds >= NextRandomChatTime)
    {
        SendBotMessage(None, GetRandomPhrase());
        NextRandomChatTime = Level.TimeSeconds + ChatInterval();
    }
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
    Super.FillPlayInfo(PlayInfo);
    PlayInfo.AddSetting(default.RulesGroup, "bRandomPhrases", default.RandomPhrasesText, 0, 1, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bDeathTaunts", default.DeathTauntsText, 0, 2, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bCthulhuReactions", default.CthulhuReactionsText, 0, 3, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bUltimateKillReactions", default.UltimateKillReactionsText, 0, 4, "Check");
    // Solo se ven con "Ver opciones avanzadas" (ultimo parametro de AddSetting)
    PlayInfo.AddSetting(default.RulesGroup, "bSilenceBotVoice", default.SilenceBotVoiceText, 0, 5, "Check", , , , True);
    PlayInfo.AddSetting(default.RulesGroup, "PhraseInterval", default.PhraseIntervalText, 0, 6, "Text", "3;5:300", , , True);
}

static event string GetDescriptionText(string PropName)
{
    switch (PropName)
    {
        case "bSilenceBotVoice":       return default.SilenceBotVoiceDesc;
        case "bRandomPhrases":         return default.RandomPhrasesDesc;
        case "bDeathTaunts":           return default.DeathTauntsDesc;
        case "bCthulhuReactions":      return default.CthulhuReactionsDesc;
        case "bUltimateKillReactions": return default.UltimateKillReactionsDesc;
        case "PhraseInterval":         return default.PhraseIntervalDesc;
    }
    return Super.GetDescriptionText(PropName);
}

defaultproperties
{
    // Manda este paquete a los jugadores que se conectan: sin esto, a ellos no les llega nada
    // de lo que se dibuja o pasa en su maquina (radar, Vision, mensajes, armas con adrenalina...)
    bAddToServerPackages=True
    bSilenceBotVoice=True
    bRandomPhrases=True
    bDeathTaunts=True
    bCthulhuReactions=True
    bUltimateKillReactions=True
    PhraseInterval=30
    SilenceBotVoiceText="Silenciar los mensajes de voz de los bots"
    SilenceBotVoiceDesc="Saca los mensajes de voz normales de los bots (por ejemplo I've got your back), asi en el chat solo quedan las frases de Chat-doka. Los bots siguen obedeciendo ordenes, pero no responden en voz alta [por defecto: activada]"
    RandomPhrasesText="Frases al azar"
    RandomPhrasesDesc="Frases de la lista general: una cada tantos segundos y algunas al matar, morir, quedar con poca vida y al empezar o terminar una oleada. Si se desactiva, solo quedan las reacciones [por defecto: activada]"
    DeathTauntsText="Burlas al morir un jugador"
    DeathTauntsDesc="Un bot se burla por nombre del jugador que muere [por defecto: activada]"
    CthulhuReactionsText="Reacciones al Rey Cthulhu"
    CthulhuReactionsDesc="Un bot reacciona cuando aparece el Rey Cthulhu [por defecto: activada]"
    UltimateKillReactionsText="Festejos con Redeemer e Ion Painter"
    UltimateKillReactionsDesc="Un bot festeja cuando mata con el Redeemer o el Ion Painter [por defecto: activada]"
    PhraseIntervalText="Segundos entre frases al azar"
    PhraseIntervalDesc="Cada cuantos segundos un bot dice una frase al azar; tambien es el tiempo minimo entre las frases de la lista general (de 5 a 300) [por defecto: 30]"
    Phrases(0)="CUÁNTO VALE LOS ELAO DE 100?, VALEN 100!!!"
    Phrases(1)="NO TE PODÉS EMBARAZAR DE UN TACHERO!"
    Phrases(2)="NO PODÉS EMBARAZAR A UNA JUDÍA!"
    Phrases(3)="GANATE LA GARCHA!"
    Phrases(4)="HASTA LOS HUEVOS!"
    Phrases(5)="QUÉ HACÉS MARIANOSKY?, PASAME EL DATASET!"
    Phrases(6)="¿CÓMO COJO CARAJO!?"
    Phrases(7)="LIBEREN A CHADOCA!!!"
    Phrases(8)="AHORA EL TORNEO ES MUY REAL!"
    Phrases(9)="AGUANTE LA COMPETENCIA FALAZ!"
    Phrases(10)="CHADOKA MAGICA IS REAL!"
    Phrases(11)="MUY POCO KAYROS"
    Phrases(12)="MAMÁ, LA BOLA DEL QUINI METIÓ A LOS CHICO EN LA TIMBA!"
    Phrases(13)="...........OOOOOCHOOOOOOOOOHHH!!!!!!"
    Phrases(14)="A MÍ POR 10MIL NO ME VAN A LLEVAR!"
    Phrases(15)="APROBASTE CASTING CONEJITO!, BIENVENIDO A LA EMPRESA!"
    Phrases(16)="HACEME UN OEVEJEROALEMAN!"
    Phrases(17)="Y ANDÁ A UNA FÁBRICA!, CARAJO!"
    Phrases(18)="NECESITAMOS MÁS BOTS!"
    Phrases(19)="NO LE DEN ASILO A GRACHU, ES UN PELIGRO!"
    Phrases(20)="CÓMO JUEGAN CON MI GUITA!"
    Phrases(21)="CHUPALA Y PAJEALA!"
    Phrases(22)="YO SOY JULIO JULIAN!"
    Phrases(23)="COLITA DE CUADRIL VS LOS EXTRATERRESTRES!"
    Phrases(24)="PROBALAS ESTÁN BUENÍSIMAS!, NO DEJES DE PROBARLAS!"
    Phrases(25)="ME QUIERO MORIR AMIGO, LE TRANSMITO TODO A MI BEBÉ!"
    Phrases(26)="QUÉ SE SIENTE VIVIR UNA MENTIRA!?"
    Phrases(27)="COMPRÁ LA ULTI EN HERNÁN DEPORTES!"
    Phrases(28)="CHACO, VO Y TU PERRO DE MIERDA!"
    Phrases(29)="HAY ARTÍCULOS DEPORTIVOS, TODO OK!"
    Phrases(30)="ÁNGELES ARIANA, HUUUUU QUÉ VIEJA PUTA!"
    Phrases(31)="DALE, DAME LA PAPAFRITA Y PAGAME EL VIÁTICO!"
    Phrases(32)="PÁGUENLE AL PANA RAMÓN CLEMENTE!!!"
    Phrases(33)="COMEME BIEN LOS HUEVOS NÉSTOR!"
    Phrases(34)="TE GUSTA LA VIOLENCIA!?!?"
    Phrases(35)="NOOOO AMIGO, MURIÓ UNA BANDA DE GENTE!!"
    Phrases(36)="QUIÉN ES TU DUEÑO CARAJO! TE GUSTA CÓMO TE GARCHO!?!"
    Phrases(37)="GALLETITAS VANINA, ESTÁN BUENÍSIMAS!!"
    Phrases(38)="GENIALESSSSS!!"
    Phrases(39)="GENUISSSSSS!"
    Phrases(40)="CALDOS KNORR, LO MEJOR PARA EL INVIERNO!"
    Phrases(41)="LABORATORIOS BAGÓ, CONCIENCIA AL SERVICIO DE LA SALUD!"
    Phrases(42)="YO SOY EL LUIS AMSTRONG DE LA CHOTA!"
    Phrases(43)="AHHAHAHAHAHAHAH, EL CTHULHU GARCADO EN FUGACETA!"
    Phrases(44)="BUENO, VAMOS AL TELO!"
    Phrases(45)="MIREN CHICOS, MARCIEL DESNUDO!"
    Phrases(46)="EL 8 DE OCTUBRE MARCIEL CUMPLE AÑOS!"
    Phrases(47)="HAY QUE HIDRATARSE PARA EL HYPERBLASTO!"
    Phrases(48)="JUGAR AL HYPERBLASTO ME CAMBIÓ LA VIDA!"
    Phrases(49)="MI VIEJA ME DIO LA VIDA, EL HYPERBLASTO LAS GANAS DE VIVIRLA"
    CthulhuPhrases(0)="CORRAN QUE APARECIÓ EL REY CTHULHU, HASTA LOS HUEVOS!"
    CthulhuPhrases(1)="MIREN EL TAMAÑO DE ESE CTHULHU, CÓMO JUEGAN CON MI GUITA!"
    CthulhuPhrases(2)="EL REY CTHULHU?! A MÍ POR 10MIL NO ME VAN A LLEVAR!"
    CthulhuPhrases(3)="CUIDADO CON EL REY CTHULHU, ESTÁ HASTA LOS HUEVOS!"
    CthulhuPhrases(4)="EL REY CTHULHU VS COLITA DE CUADRIL, HAGAN SUS APUESTAS!"
    CthulhuPhrases(5)="QUÉ HACÉS MARIANOSKY?! NOS SOLTASTE AL REY CTHULHU!"
    CthulhuPhrases(6)="EL REY CTHULHU ESTÁ DESNUDO!"
    CthulhuPhrases(7)="TÚ QUIERE LA PINGA DEL REY CTHULHU EN TU CULO!"
    CthulhuPhrases(8)="Y EL GRAN RESPONSABLE DE ESTO ES EL REY CTHULHU!"
    UltimateKillPhrases(0)="BOOOM! COMAN REDEEMER, HASTA LOS HUEVOS!"
    UltimateKillPhrases(1)="PROBALAS ESTÁN BUENÍSIMAS! MIRÁ CÓMO EXPLOTÓ TODO!"
    UltimateKillPhrases(2)="RAYO DEL ESPACIO, CHUPALA Y PAJEALA!"
    UltimateKillPhrases(3)="AHORA EL TORNEO ES MUY REAL! MIRÁ ESA EXPLOSIÓN!"
    UltimateKillPhrases(4)="LIBEREN A CHADOCA! VOLARON TODOS EN PEDAZOS!"
    UltimateKillPhrases(5)="...........OOOOOCHOOOOOOOOOHHH!!!!!! QUÉ LINDO BOMBAZO!"
    LastPhraseIndex=-1
    LastWaveNum=-1
    GroupName="ChatDokaBots"
    FriendlyName="[Irreal] Chat-doka Bots"
    Description="Hace que los bots escriban frases personalizadas y contextuales en el chat (frases al azar cada tantos segundos, reaccion al Rey Cthulhu, bajas con Redeemer/Ion Painter, Kayros y burlas por nombre al morir un humano). Tambien silencia los mensajes de voz normales de los bots. Cada parte se puede activar o desactivar en Configurar mutadores."
}
