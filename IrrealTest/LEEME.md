# IrrealTest: mutador solo para pruebas

Paquete aparte de `MyInvasionMut` con comandos de consola para probar los mutadores sin esperar a que pasen las cosas por azar. **No se distribuye**: no va en el ZIP ni se instala en partidas con amigos (si el host lo activa, los demás también necesitarían el archivo).

## Cómo usarlo

1. Compilar los dos paquetes juntos (`IrrealTest` depende de `MyInvasionMut` e instalar los dos `.u` de la misma compilación).
2. Copiar `IrrealTest.u` y `IrrealTest.ucl` a la carpeta `System` del juego.
3. En el menú de mutadores activar **[Irreal_Test] PRUEBAS (no distribuir)** junto con los que se quieran probar. El guion bajo hace que aparezca justo después de los mutadores `[Irreal]` (con un espacio, como en "[Irreal Test]", quedaría antes que ellos).
4. En la partida, abrir la consola y escribir los comandos. Solo funcionan para el host o un admin.

## Comandos

| Comando | Qué hace |
|---|---|
| `mutate test` | Muestra la ayuda |
| `mutate test kill` | Mata a todos los monstruos y termina la oleada (Invasion los cuenta como muertes normales) |
| `mutate test cthulhu` | Hace aparecer al Rey Cthulhu ahora |
| `mutate test krall` | Hace aparecer al Elite Krall infectado ahora (el contagio solo funciona desde la oleada 9) |
| `mutate test kayros poco` / `mucho` | Te da Poco o Mucho Kayros hasta la próxima oleada |
| `mutate test arma redeemer` / `painter` / `ion` / `lightning` | Cambia el arma del punto de Armas últimas hasta la próxima oleada |

Los comandos llaman a las mismas funciones que usan los mutadores en una partida normal, así que lo que se ve es lo que pasaría de verdad.

## Por qué no usar `killall monster`

El comando del juego `killall monster` también elimina a todos los bots y borra los monstruos sin que Invasion los cuente como muertos, así que la oleada nunca termina. `mutate test kill` evita los dos problemas.

Los trucos del juego (`god`, `allammo`, `loaded`) solo funcionan en Acción Instantánea, no en un servidor propio.
