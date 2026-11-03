// Mejora el radar de Invasion: puntos fijos (sin parpadeo) con un color para monstruos y
// otro para jugadores, el Rey Cthulhu resaltado, y una linea vertical en cada monstruo o
// jugador que esta en otro piso. El mutador solo corre en el servidor: crea un actor
// replicado que en cada computadora agrega el dibujo al HUD del jugador local y le pasa
// la configuracion.
class MutRadarMejorado extends Mutator;

// Opciones de "Configurar mutadores"; quedan guardadas en el .ini del juego del host
var config bool bColoredDots;      // puntos fijos de colores (y el Rey Cthulhu en rojo)
var config bool bShowHeightLines;  // lineas de altura
var config float MinHeightDiff;    // diferencia de altura (pies contra pies) para dibujar la linea

var localized string ColoredDotsText, ColoredDotsDesc;
var localized string ShowHeightLinesText, ShowHeightLinesDesc;
var localized string MinHeightDiffText, MinHeightDiffDesc;

function PostBeginPlay()
{
    local RadarMejoradoReplicationInfo RI;

    Super.PostBeginPlay();

    if (Invasion(Level.Game) != None)
    {
        RI = Spawn(class'RadarMejoradoReplicationInfo');
        if (RI != None)
        {
            RI.bColoredDots = bColoredDots;
            RI.bShowHeightLines = bShowHeightLines;
            RI.MinHeightDiff = FClamp(MinHeightDiff, 50, 2000);
        }
    }
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
    Super.FillPlayInfo(PlayInfo);
    PlayInfo.AddSetting(default.RulesGroup, "bColoredDots", default.ColoredDotsText, 0, 1, "Check");
    PlayInfo.AddSetting(default.RulesGroup, "bShowHeightLines", default.ShowHeightLinesText, 0, 2, "Check");
    // Ajuste fino: solo se ve con "Ver opciones avanzadas" (ultimo parametro de AddSetting)
    PlayInfo.AddSetting(default.RulesGroup, "MinHeightDiff", default.MinHeightDiffText, 0, 3, "Text", "4;50:2000", , , True);
}

static event string GetDescriptionText(string PropName)
{
    switch (PropName)
    {
        case "bColoredDots":     return default.ColoredDotsDesc;
        case "bShowHeightLines": return default.ShowHeightLinesDesc;
        case "MinHeightDiff":    return default.MinHeightDiffDesc;
    }
    return Super.GetDescriptionText(PropName);
}

defaultproperties
{
    bColoredDots=True
    bShowHeightLines=True
    MinHeightDiff=200.0
    ColoredDotsText="Puntos de colores"
    ColoredDotsDesc="Puntos fijos, sin parpadeo: amarillo para monstruos y verde para jugadores; los bots quedan tenues, el Rey Cthulhu aparece en rojo y Fer en magenta. Si se desactiva, se ven los puntos normales del radar [por defecto: activada]"
    ShowHeightLinesText="Lineas de altura"
    ShowHeightLinesDesc="Muestra una linea vertical en cada monstruo o jugador que esta en otro piso [por defecto: activada]"
    MinHeightDiffText="Diferencia minima de altura"
    MinHeightDiffDesc="Diferencia de altura (en unidades, pies contra pies) a partir de la cual se dibuja la linea. Un piso suele estar a entre 200 y 500 unidades. Mas bajo: mas sensible (de 50 a 2000) [por defecto: 200]"
    GroupName="RadarMejorado"
    FriendlyName="[Irreal] Sigan viendo"
    Description="Reemplaza los puntos del radar de Invasion por puntos fijos, sin parpadeo: amarillo para monstruos y verde para jugadores; el Rey Cthulhu aparece como un punto rojo mas grande y Fer (en Cuiden a Fer!) en magenta. Los bots quedan con el punto tenue del radar original, para no llenar el radar. Ademas, cada monstruo o jugador que esta en otro piso muestra una linea vertical: si esta arriba, el punto queda sobre la linea; si esta abajo, el punto cuelga de la linea. Cuanto mas larga la linea, mas diferencia de altura. Cada parte se puede desactivar en Configurar mutadores."
}
