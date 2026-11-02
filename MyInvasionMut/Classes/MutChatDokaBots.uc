class MutChatDokaBots extends Mutator;

var string Phrases[47];
var string CthulhuPhrases[6];
var string UltimateKillPhrases[6];
var int LastPhraseIndex;
var float LastChatTime;
var float NextRandomChatTime;
var int LastWaveNum;
var bool bWasWaveActive;
var bool bChampionAnnounced;

// Opcion de "Configurar mutadores": silencia los mensajes de voz normales de los bots
var config bool bSilenceBotVoice;
var localized string SilenceBotVoiceText, SilenceBotVoiceDesc;

function PostBeginPlay()
{
    local ChatDokaRules GR;

    Super.PostBeginPlay();

    // Asegura caracteres especiales sin problemas de codificacion
    Phrases[6] = Chr(191) $ "COMO COJO CARAJO!?";
    Phrases[36] = "QUIEN ES TU DUE" $ Chr(209) $ "O CARAJO! TE GUSTA COMO TE GARCHO!?!";
    Phrases[46] = "EL 8 DE OCTUBRE MARCIEL CUMPLE A" $ Chr(209) $ "OS!";
    CthulhuPhrases[1] = "MIREN EL TAMA" $ Chr(209) $ "O DE ESE CTHULHU, COMO JUEGAN CON MI GUITA!";

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

    LastChatTime = -30.0;
    NextRandomChatTime = Level.TimeSeconds + 30.0;
    SetTimer(1.0, true);
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
    switch (Rand(8))
    {
        case 0:
            return Chr(161) $ VictimName $ ", HASTA LOS HUEVOS!";
        case 1:
            return Chr(161) $ "NOOO " $ VictimName $ ", COMO TE VAS A MORIR ASI CARAJO?!";
        case 2:
            return Chr(161) $ "LEVANTATE " $ VictimName $ ", Y ANDA A UNA FABRICA, CARAJO!";
        case 3:
            return Chr(161) $ VictimName $ " MURIO! NECESITAMOS MAS BOTS PARA CARREARLO!";
        case 4:
            return Chr(161) $ "MIRA COMO JUEGAN CON LA VIDA DE " $ VictimName $ "!";
        case 5:
            return Chr(161) $ VictimName $ " TENIA INFORMACION QUE PUEDE LLEVAR AL ARRESTO DE CRISTINA KIRCHNER!";
        case 6:
            return Chr(161) $ "A " $ VictimName $ " LE METIERON EL TIRO DE MAXIMO A NESTOR!";
        default:
            return Chr(161) $ "CHAU " $ VictimName $ ", APROBASTE EL CASTING PARA EL CAJON!";
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
    NextRandomChatTime = Level.TimeSeconds + 30.0;

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
    // Respeta el intervalo de 30 segundos entre mensajes de frases generales
    if (Level.TimeSeconds - LastChatTime < 30.0)
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

    Msg = CthulhuPhrases[Rand(ArrayCount(CthulhuPhrases))];
    SendBotMessage(None, Msg);
}

function TriggerUltimateKillChat(Bot KillerBot)
{
    local string Msg;

    if (Level.TimeSeconds - LastChatTime < 2.5)
    {
        return;
    }

    Msg = UltimateKillPhrases[Rand(ArrayCount(UltimateKillPhrases))];
    SendBotMessage(KillerBot, Msg);
}

function TriggerHumanDeathTaunt(Controller DeadHuman)
{
    local string VictimName;

    if (DeadHuman == None || DeadHuman.PlayerReplicationInfo == None)
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
                return Chr(161) $ "MIREN A " $ TargetName $ ", TIENE MUCHO KAYROS ESTA RONDA!";
            case 1:
                return Chr(161) $ TargetName $ " LIGO MUCHO KAYROS, COMO JUEGAN CON MI GUITA!";
            case 2:
                return Chr(161) $ "DEJENLE LOS ITEMS A " $ TargetName $ " QUE TIENE MUCHO KAYROS (+20%)!";
            default:
                return Chr(161) $ "QUE ORTO " $ TargetName $ ", TIENE MUCHO KAYROS!";
        }
    }
    else
    {
        switch (Rand(4))
        {
            case 0:
                return Chr(161) $ "MIREN A " $ TargetName $ ", TIENE MUY POCO KAYROS!";
            case 1:
                return Chr(161) $ TargetName $ " TIENE POCO KAYROS, HASTA LOS HUEVOS!";
            case 2:
                return Chr(161) $ "NO LE DEJEN AGARRAR NADA A " $ TargetName $ " QUE TIENE POCO KAYROS (-20%)!";
            default:
                return Chr(161) $ "JAJAJA " $ TargetName $ ", TE TOCO MUY POCO KAYROS ESTA RONDA!";
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

    // Comentarios cada 30 segundos en la partida
    if (Level.TimeSeconds >= NextRandomChatTime)
    {
        SendBotMessage(None, GetRandomPhrase());
        NextRandomChatTime = Level.TimeSeconds + 30.0;
    }
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
    Super.FillPlayInfo(PlayInfo);
    PlayInfo.AddSetting(default.RulesGroup, "bSilenceBotVoice", default.SilenceBotVoiceText, 0, 1, "Check");
}

static event string GetDescriptionText(string PropName)
{
    if (PropName == "bSilenceBotVoice")
        return default.SilenceBotVoiceDesc;
    return Super.GetDescriptionText(PropName);
}

defaultproperties
{
    bSilenceBotVoice=True
    SilenceBotVoiceText="Silenciar los mensajes de voz de los bots"
    SilenceBotVoiceDesc="Saca los mensajes de voz normales de los bots (por ejemplo I've got your back), asi en el chat solo quedan las frases de Chat-doka. Los bots siguen obedeciendo ordenes, pero no responden en voz alta."
    Phrases(0)="CUANTO VALE LOS ELAO DE 100?, VALEN 100!!!"
    Phrases(1)="NO TE PODES EMBARAZAR DE UN TACHERO!"
    Phrases(2)="NO PODES EMBARAZAR A UNA JUDIA!"
    Phrases(3)="GANATE LA GARCHA!"
    Phrases(4)="HASTA LOS HUEVOS!"
    Phrases(5)="QUE HACES MARIANOSKY?, PASAME EL DATASET!"
    Phrases(6)="COMO COJO CARAJO!?"
    Phrases(7)="LIBEREN A CHADOCA!!!"
    Phrases(8)="AHORA EL TORNEO ES MUY REAL!"
    Phrases(9)="AGUANTE LA COMPETENCIA FALAZ!"
    Phrases(10)="CHADOKA MAGICA IS REAL!"
    Phrases(11)="MUY POCO KAYROS"
    Phrases(12)="MAMA, LA BOLA DEL QUINI METIO A LOS CHICO EN LA TIMBA!"
    Phrases(13)="...........OOOOOCHOOOOOOOOOHHH!!!!!!"
    Phrases(14)="A MI POR 10MIL NO ME VAN A LLEVAR!"
    Phrases(15)="APROBASTE CASTING CONEJITO!, BIENVENIDO A LA EMPRESA!"
    Phrases(16)="HACEME UN OEVEJEROALEMAN!"
    Phrases(17)="Y ANDA A UNA FABRICA!, CARAJO!"
    Phrases(18)="NECESITAMOS MAS BOTS!"
    Phrases(19)="NO LE DEN ASILO A GRACHU, ES UN PELIGRO!"
    Phrases(20)="COMO JUEGAN CON MI GUITA!"
    Phrases(21)="CHUPALA Y PAJEALA!"
    Phrases(22)="YO SOY JULIO JULIAN!"
    Phrases(23)="COLITA DE CUADRIL VS LOS EXTRATERRESTRES!"
    Phrases(24)="PROBALAS ESTAN BUENISIMAS!, NO DEJES DE PROBARLAS!"
    Phrases(25)="ME QUIERO MORIR AMIGO, LE TRANSMITO TODO A MI BEBE!"
    Phrases(26)="QUE SE SIENTE VIVIR UNA MENTIRA!?"
    Phrases(27)="COMPRA LA ULTI EN HERNAN DEPORTES!"
    Phrases(28)="CHACO, VO Y TU PERRO DE MIERDA!"
    Phrases(29)="HAY ARTICULOS DEPORTIVOS, TODO OK!"
    Phrases(30)="ANGELES ARIANA, HUUUUU QUE VIEJA PUTA!"
    Phrases(31)="DALE, DAME LA PAPAFRITA Y PAGAME EL VIATICO!"
    Phrases(32)="PAGUENLE AL PANA RAMON CLEMENTE!!!"
    Phrases(33)="COMEME BIEN LOS HUEVOS NESTOR!"
    Phrases(34)="TE GUSTA LA VIOLENCIA!?!?"
    Phrases(35)="NOOOO AMIGO, MURIO UNA BANDA DE GENTE!!"
    Phrases(36)="QUIEN ES TU DUENO CARAJO! TE GUSTA COMO TE GARCHO!?!"
    Phrases(37)="GALLETITAS VANINA, ESTAN BUENISIMAS!!"
    Phrases(38)="GENIALESSSSS!!"
    Phrases(39)="GENUISSSSSS!"
    Phrases(40)="CALDOS KNORR, LO MEJOR PARA EL INVIERNO!"
    Phrases(41)="LABORATORIOS BAGO, CONCIENCIA AL SERVICIO DE LA SALUD!"
    Phrases(42)="YO SOY EL LUIS AMSTRONG DE LA CHOTA!"
    Phrases(43)="AHHAHAHAHAHAHAH, EL CTHULHU GARCADO EN FUGACETA!"
    Phrases(44)="BUENO, VAMOS AL TELO!"
    Phrases(45)="MIREN CHICOS, MARCIEL DESNUDO!"
    Phrases(46)="EL 8 DE OCTUBRE MARCIEL CUMPLE ANOS!"
    CthulhuPhrases(0)="CORRAN QUE APARECIO EL REY CTHULHU, HASTA LOS HUEVOS!"
    CthulhuPhrases(1)="MIREN EL TAMANO DE ESE CTHULHU, COMO JUEGAN CON MI GUITA!"
    CthulhuPhrases(2)="EL REY CTHULHU?! A MI POR 10MIL NO ME VAN A LLEVAR!"
    CthulhuPhrases(3)="CUIDADO CON EL REY CTHULHU, ESTA HASTA LOS HUEVOS!"
    CthulhuPhrases(4)="EL REY CTHULHU VS COLITA DE CUADRIL, HAGAN SUS APUESTAS!"
    CthulhuPhrases(5)="QUE HACES MARIANOSKY?! NOS SOLTASTE AL REY CTHULHU!"
    UltimateKillPhrases(0)="BOOOM! COMAN REDEEMER, HASTA LOS HUEVOS!"
    UltimateKillPhrases(1)="PROBALAS ESTAN BUENISIMAS! MIRA COMO EXPLOTO TODO!"
    UltimateKillPhrases(2)="RAYO DEL ESPACIO, CHUPALA Y PAJEALA!"
    UltimateKillPhrases(3)="AHORA EL TORNEO ES MUY REAL! MIRA ESA EXPLOSION!"
    UltimateKillPhrases(4)="LIBEREN A CHADOCA! VOLARON TODOS EN PEDAZOS!"
    UltimateKillPhrases(5)="...........OOOOOCHOOOOOOOOOHHH!!!!!! QUE LINDO BOMBAZO!"
    LastPhraseIndex=-1
    LastWaveNum=-1
    GroupName="ChatDokaBots"
    FriendlyName="[Irreal] Chat-doka Bots"
    Description="Hace que los bots escriban frases personalizadas y contextuales en el chat (una frase al azar cada 30 segundos, reaccion al Rey Cthulhu, bajas con Redeemer/Ion Painter, Kayros y burlas por nombre al morir un humano). Tambien silencia los mensajes de voz normales de los bots (se puede cambiar en Configurar mutadores)."
}
