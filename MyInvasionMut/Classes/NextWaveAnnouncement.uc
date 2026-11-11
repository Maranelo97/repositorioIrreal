// "Next wave in..." del locutor cuando termina la pausa de Control de plagas. Invasion lo manda
// al empezar el descanso con una llamada de red que se puede perder, y ahi la pausa todavia no
// empezo. Este mensaje llega siempre (los mensajes son confiables) y no muestra texto: solo
// hace sonar la voz en la computadora de cada jugador.
class NextWaveAnnouncement extends LocalMessage;

static function ClientReceive(PlayerController P, optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
    // Sin Super: Super agregaria un mensaje (vacio) al HUD
    if (P != None)
        P.PlayStatusAnnouncement('Next_wave_in', 1, true);
}

defaultproperties
{
    bIsConsoleMessage=False
}
