// Mejora el radar de Invasion: puntos fijos (sin parpadeo) con un color para monstruos y
// otro para jugadores, el Rey Cthulhu resaltado, y una linea vertical en cada monstruo o
// jugador que esta en otro piso. Tambien muestra la oleada actual y la final en lugar
// del reloj. El mutador solo corre en el servidor: crea un actor
// replicado que en cada computadora agrega el dibujo al HUD del jugador local y le pasa
// la configuracion.
class MutRadarMejorado extends Mutator;

// Opciones de "Configurar mutadores"; quedan guardadas en el .ini del juego del host
var config bool bColoredDots;      // puntos fijos de colores (y el Rey Cthulhu en rojo)
var config bool bShowHeightLines;  // lineas de altura
var config float MinHeightDiff;    // diferencia de altura (pies contra pies) para dibujar la linea
var config bool bShowWave;         // oleada actual y final en lugar del reloj
var config bool bShowWaveProgress; // barra debajo de la oleada que se llena a medida que avanza

var localized string ColoredDotsText, ColoredDotsDesc;
var localized string ShowHeightLinesText, ShowHeightLinesDesc;
var localized string MinHeightDiffText, MinHeightDiffDesc;
var localized string ShowWaveText, ShowWaveDesc;
var localized string ShowWaveProgressText, ShowWaveProgressDesc;

var RadarMejoradoReplicationInfo RI;
var bool bWasInProgress;       // para saber cuando empieza cada oleada
var float WaveStartTime, WaveTime;   // cuando empezo y cuanto dura como minimo

function PostBeginPlay()
{

    Super.PostBeginPlay();

    if (Invasion(Level.Game) != None)
    {
        RI = Spawn(class'RadarMejoradoReplicationInfo');
        if (RI != None)
        {
            RI.bColoredDots = bColoredDots;
            RI.bShowHeightLines = bShowHeightLines;
            RI.MinHeightDiff = FClamp(MinHeightDiff, 50, 2000);
            RI.bShowWave = bShowWave;
            RI.FinalWave = Invasion(Level.Game).FinalWave;
            RI.bShowWaveProgress = bShowWave && bShowWaveProgress;
            if (RI.bShowWaveProgress)
                SetTimer(0.5, true);
        }
    }
}

// Avance de la oleada, de 0 a 255, para la barra de cada jugador. Invasion termina la oleada
// cuando paso su tiempo minimo, aparecieron al menos el doble de MaxMonsters y no queda ninguno
// vivo; mientras no pasa el tiempo siguen apareciendo, asi que el total no se sabe de antemano.
// Por eso el avance es el menor entre el tiempo y las muertes (sobre los que aparecieron, o
// sobre el doble de MaxMonsters si todavia son menos): no se adelanta a ninguno de los dos y,
// cuando ya no aparecen mas, llega al final con el ultimo monstruo. En el descanso esta lleno.
function Timer()
{
    local Invasion InvGame;
    local float TimeDone, Killed, Total, Progress;

    InvGame = Invasion(Level.Game);
    if (InvGame == None || RI == None)
        return;

    if (!InvGame.bWaveInProgress)
    {
        bWasInProgress = false;
        Progress = 1.0;
    }
    else
    {
        if (!bWasInProgress)
        {
            bWasInProgress = true;
            WaveStartTime = Level.TimeSeconds;
            WaveTime = FMax(1.0, InvGame.WaveEndTime - Level.TimeSeconds);
        }
        TimeDone = FClamp((Level.TimeSeconds - WaveStartTime) / WaveTime, 0.0, 1.0);
        Killed = Max(0, InvGame.WaveMonsters - InvGame.NumMonsters);
        Total = Max(2 * InvGame.MaxMonsters, InvGame.WaveMonsters);
        if (Total > 0)
            Progress = FMin(TimeDone, FClamp(Killed / Total, 0.0, 1.0));
    }

    if (RI.WaveProgress != byte(Progress * 255.0))
        RI.WaveProgress = byte(Progress * 255.0);
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
    Super.FillPlayInfo(PlayInfo);
    PlayInfo.AddSetting(default.RulesGroup, "bColoredDots", default.ColoredDotsText, 0, 1, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bShowHeightLines", default.ShowHeightLinesText, 0, 2, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bShowWave", default.ShowWaveText, 0, 3, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bShowWaveProgress", default.ShowWaveProgressText, 0, 4, "Check");
    // Ajuste fino: solo se ve con "Ver opciones avanzadas" (ultimo parametro de AddSetting)
    PlayInfo.AddSetting(default.RulesGroup, "MinHeightDiff", default.MinHeightDiffText, 0, 5, "Text", "4;50:2000", , , True);
}

static event string GetDescriptionText(string PropName)
{
    switch (PropName)
    {
        case "bColoredDots":     return default.ColoredDotsDesc;
        case "bShowHeightLines": return default.ShowHeightLinesDesc;
        case "MinHeightDiff":    return default.MinHeightDiffDesc;
        case "bShowWave":        return default.ShowWaveDesc;
        case "bShowWaveProgress": return default.ShowWaveProgressDesc;
    }
    return Super.GetDescriptionText(PropName);
}

defaultproperties
{
    // Manda este paquete a los jugadores que se conectan: sin esto, a ellos no les llega nada
    // de lo que se dibuja o pasa en su maquina (radar, Vision, mensajes, armas con adrenalina...)
    bAddToServerPackages=True
    bColoredDots=True
    bShowHeightLines=True
    MinHeightDiff=200.0
    bShowWave=True
    bShowWaveProgress=True
    ShowWaveProgressText="Barra de avance de la oleada"
    ShowWaveProgressDesc="Debajo de la oleada, una barra que se llena a medida que avanza: sigue el tiempo de la oleada y los monstruos muertos, y se completa con el ultimo. Necesita Mostrar la oleada [por defecto: activada]"
    ShowWaveText="Mostrar la oleada"
    ShowWaveDesc="En lugar del reloj muestra la oleada actual y la final, con el simbolo del Skaarj y los mismos numeros (por ejemplo 3 / 16). En el descanso muestra la que viene. Si se desactiva, vuelve el reloj [por defecto: activada]"
    ColoredDotsText="Puntos de colores"
    ColoredDotsDesc="Puntos fijos, sin parpadeo: amarillo para monstruos y verde para jugadores; los bots quedan tenues y el Rey Cthulhu aparece en rojo. Si se desactiva, se ven los puntos normales del radar [por defecto: activada]"
    ShowHeightLinesText="Lineas de altura"
    ShowHeightLinesDesc="Muestra una linea vertical en cada monstruo o jugador que esta en otro piso [por defecto: activada]"
    MinHeightDiffText="Diferencia minima de altura"
    MinHeightDiffDesc="Diferencia de altura (en unidades, pies contra pies) a partir de la cual se dibuja la linea. Un piso suele estar a entre 200 y 500 unidades. Mas bajo: mas sensible (de 50 a 2000) [por defecto: 200]"
    GroupName="RadarMejorado"
    FriendlyName="[Irreal] Sigan viendo"
    Description="Reemplaza los puntos del radar de Invasion por puntos fijos, sin parpadeo: amarillo para monstruos y verde para jugadores; el Rey Cthulhu aparece como un punto rojo mas grande. Los bots quedan con el punto tenue del radar original, para no llenar el radar. Ademas, cada monstruo o jugador que esta en otro piso muestra una linea vertical: si esta arriba, el punto queda sobre la linea; si esta abajo, el punto cuelga de la linea. Cuanto mas larga la linea, mas diferencia de altura. En lugar del reloj muestra la oleada actual y la final, con una barra que se llena a medida que avanza. Cada parte se puede desactivar en Configurar mutadores. (Ver 1.4.3)"
}
