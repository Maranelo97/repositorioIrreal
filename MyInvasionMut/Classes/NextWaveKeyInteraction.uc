// En la maquina de cada jugador: la tecla H manda "mutate nextwave" (Control de plagas). Solo
// si H no tiene otra asignacion, para no pisar la configuracion del jugador. La tecla sigue su
// camino normal (no se consume). Si el jugador asigno "mutate nextwave" a otra tecla, esa
// tambien sirve. Mientras se escribe en el chat o hay un menu abierto, la consola o el menu
// reciben la tecla antes y no llega aca.
class NextWaveKeyInteraction extends Interaction;

function bool KeyEvent(out EInputKey Key, out EInputAction Action, float Delta)
{
    local PlayerController PC;

    if (Action != IST_Press || Key != IK_H || ViewportOwner == None)
        return false;
    PC = ViewportOwner.Actor;
    if (PC == None || PC.ConsoleCommand("KEYBINDING H") != "")
        return false;

    PC.Mutate("nextwave");
    return false;
}

// Las interacciones sobreviven al cambio de mapa: se quita sola para no duplicarse
event NotifyLevelChange()
{
    if (Master != None)
        Master.RemoveInteraction(self);
}

defaultproperties
{
}
