// Agrega el comando de consola "irreal" como atajo de "mutate test".
// Lo crea MutIrrealTest para el jugador local (el host).
class IrrealTestInteraction extends Interaction;

exec function Irreal(optional string Args)
{
    if (ViewportOwner != None && ViewportOwner.Actor != None)
    {
        ViewportOwner.Actor.Mutate("test " $ Args);
    }
}

// Las interacciones sobreviven al cambio de mapa: se quita sola para no duplicarse
event NotifyLevelChange()
{
    if (Master != None)
        Master.RemoveInteraction(self);
}

defaultproperties
{
    bActive=True
    bVisible=False
}
