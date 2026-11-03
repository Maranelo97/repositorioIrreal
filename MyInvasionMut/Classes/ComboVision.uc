// Combo de GIGACHADrenalina: marca a los monstruos, los otros jugadores y el Rey Cthulhu en pantalla a traves de las paredes
// mientras dura (cuatro veces izquierda). En una partida en red el servidor
// no le manda a cada jugador los monstruos que no puede ver, asi que GigaVisionInfo le pasa
// las posiciones solo a quien hizo el combo.
class ComboVision extends Combo;

var GigaVisionInfo Info;

function StartEffect(xPawn P)
{
    if (PlayerController(P.Controller) != None)
        Info = Spawn(class'GigaVisionInfo', P.Controller);
}

function StopEffect(xPawn P)
{
    if (Info != None)
        Info.Destroy();
    Info = None;
}

defaultproperties
{
    ExecMessage="Vision!"
    keys(0)=8
    keys(1)=8
    keys(2)=8
    keys(3)=8
}
