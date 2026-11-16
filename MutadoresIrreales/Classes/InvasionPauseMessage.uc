class InvasionPauseMessage extends LocalMessage;

// Linea fija durante la pausa con la tecla para iniciar la siguiente oleada.
// El texto se arma en la maquina de cada jugador, porque las teclas asignadas solo
// se conocen ahi: muestra H, o el comando si ese jugador tiene H asignada a otra cosa.
// Switch 0 la muestra y Switch 1 la saca (MutControlDePlagas lo manda al terminar la pausa).
static function ClientReceive(
    PlayerController P,
    optional int Switch,
    optional PlayerReplicationInfo RelatedPRI_1,
    optional PlayerReplicationInfo RelatedPRI_2,
    optional Object OptionalObject
)
{
    local string Text;

    if (P == None || P.myHUD == None)
        return;

    if (Switch == 1)
    {
        // Como es unica, reemplaza a la linea fija y vence enseguida (ver GetLifeTime)
        Text = " ";
    }
    else
    {
        // H manda el comando (NextWaveKeyInteraction) mientras no tenga otra asignacion
        if (P.ConsoleCommand("KEYBINDING H") == "")
            Text = "H: siguiente oleada";
        else
            Text = "Siguiente oleada: escribir mutate nextwave en la consola";
    }

    P.myHUD.LocalizedMessage(default.Class, Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject, Text);
}

// El HUD solo borra los mensajes que se desvanecen. La linea fija dura tanto que el
// desvanecimiento no se nota; la del Switch 1 dura un instante y se lleva la linea.
static function float GetLifeTime(int Switch)
{
    if (Switch == 1)
        return 0.01;
    return 9999.0;
}

defaultproperties
{
    bIsUnique=True
    bIsConsoleMessage=False
    bFadeMessage=True
    DrawColor=(R=0,G=160,B=255,A=255)
    PosY=0.88
}
