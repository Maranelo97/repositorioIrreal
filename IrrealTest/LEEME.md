# IrrealTest: mutador solo para pruebas

Paquete aparte de `MyInvasionMut` con comandos de consola para probar los mutadores sin esperar a que pasen las cosas por azar. **No se distribuye**: no va en el ZIP ni se instala en partidas con amigos (si el host lo activa, los demás también necesitarían el archivo).

## Cómo usarlo

1. Compilar los dos paquetes juntos (`IrrealTest` depende de `MyInvasionMut` e instalar los dos `.u` de la misma compilación).
2. Copiar `IrrealTest.u` y `IrrealTest.ucl` a la carpeta `System` del juego.
3. En el menú de mutadores activar **[Irreal_Test] PRUEBAS (no distribuir)** junto con los que se quieran probar. El guion bajo hace que aparezca justo después de los mutadores `[Irreal]` (con un espacio, como en "[Irreal Test]", quedaría antes que ellos).
4. En la partida, abrir la consola y escribir los comandos. Solo funcionan para el host o un admin.

Cada comando se puede escribir como `irreal ...` o como `mutate test ...` (por ejemplo `irreal kill` o `mutate test kill`). `irreal` solo existe en la computadora del host; un admin conectado desde otra computadora tiene que usar `mutate test`.

## Comandos

| Comando | Qué hace |
|---|---|
| `irreal` | Muestra la ayuda |
| `irreal kill` | Mata a todos los monstruos y termina la oleada (Invasion los cuenta como muertes normales) |
| `irreal cthulhu` (o `irreal cutulu`) | Hace aparecer al Rey Cthulhu ahora |
| `irreal kayros poco` / `mucho` | Te da Poco o Mucho Kayros hasta la próxima oleada |
| `irreal ulti 1` / `2` / `3` | Cambia el arma del punto especial de Armas últimas y además te la da (o te la recarga): 1 Redeemer, 2 Ion Painter, 3 Lightning Gun (también acepta `redeemer`, `ion` y `lightning`). Con GIGACHADrenalina activo te da la versión que usa adrenalina. El arma que te da no pasa por Kayros; para probar Kayros, levantarla del punto especial |
| `irreal adrenalina` / `irreal adrenalina 40` | Pone tu adrenalina en 100, o en el número que se indique (de 0 a 100). Sirve para probar combos y GIGACHADrenalina |

`irreal kayros` e `irreal ulti` se pueden usar durante una oleada (vale hasta que termina) o entre oleadas (vale para la oleada que viene; sin esto, el sorteo al empezar la oleada pisaría la elección).

Los comandos llaman a las mismas funciones que usan los mutadores en una partida normal, así que lo que se ve es lo que pasaría de verdad.

## Por qué no usar `killall monster`

El comando del juego `killall monster` también elimina a todos los bots y borra los monstruos sin que Invasion los cuente como muertos, así que la oleada nunca termina. `irreal kill` evita los dos problemas.

Los trucos del juego (`god`, `allammo`, `loaded`) solo funcionan en Acción Instantánea, no en un servidor propio.
