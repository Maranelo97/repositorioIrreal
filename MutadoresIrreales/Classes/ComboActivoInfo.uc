// Uno por jugador, creado por MutSiganViendo (opcion "Mostrar el combo activo"): le dice solo a ese
// jugador que combo tiene activo, para que RadarMejoradoOverlay muestre el nombre debajo de la
// adrenalina. El juego no le manda el combo a nadie (CurrentCombo existe solo en el servidor).
// Con bOnlyRelevantToOwner, en la computadora de cada jugador solo existe el suyo; en la del host
// estan todos y se elige el que tiene de dueno al jugador local.
class ComboActivoInfo extends ReplicationInfo;

var class<Combo> ComboClass;   // None si no hay combo activo

replication
{
    reliable if (Role == ROLE_Authority)
        ComboClass;
}

defaultproperties
{
    bAlwaysRelevant=False
    bOnlyRelevantToOwner=True
    RemoteRole=ROLE_SimulatedProxy
    NetUpdateFrequency=10.0
}
