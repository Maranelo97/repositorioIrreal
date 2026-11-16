// Descarta los mensajes de voz normales de los bots ("I've got your back", "I'm hit!"...),
// asi en el chat solo quedan las frases de Chat-doka Bots. Los de los jugadores pasan igual.
// Las ordenes a los bots siguen funcionando: les llegan por otro camino; solo se pierde su
// respuesta hablada ("Got it!").
class ChatDokaBroadcastHandler extends BroadcastHandler;

function bool AcceptBroadcastSpeech(PlayerController Receiver, PlayerReplicationInfo SenderPRI)
{
    if (SenderPRI != None && SenderPRI.bBot)
        return false;
    return Super.AcceptBroadcastSpeech(Receiver, SenderPRI);
}
