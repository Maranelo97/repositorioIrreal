# Notas técnicas de MyInvasionMut

Cosas que conviene saber antes de tocar el código o los textos del paquete.

## Acentos y codificación

UT2004 es de 2004 y no entiende UTF-8. Todo el texto que llega al juego tiene que estar en Latin-1 (Windows "ANSI").

### Archivos de idioma (`System/*.int`, `System/*.est`)

- Se guardan en **Latin-1 / Windows-1252, sin BOM**. Si se guardan en UTF-8, los acentos aparecen rotos en el juego (por ejemplo `Ã¡` en lugar de `á`).
- GitHub y algunos editores los muestran con caracteres raros porque esperan UTF-8. Es normal: el archivo está bien para el juego.
- En VS Code: abajo a la derecha, "Reopen with Encoding" → "Western (Windows 1252)" antes de editar.
- El `.est` es una copia idéntica del `.int` (el juego en español lee el `.est`, en inglés el `.int`). Al cambiar uno, copiar el otro.

### Fuentes: cuáles muestran bien los acentos

Revisamos las imágenes de las fuentes del juego letra por letra. Estas cuatro tienen **todos los caracteres con acento corridos un lugar**: en vez de la letra pedida dibujan la siguiente (`é` sale `ê`, `É` sale `Ê`, `á` sale `â`, `Ñ` sale `Ò`, `¿` sale `À`...). Algunos lugares quedan vacíos.

| Fuente | Problema |
|---|---|
| `UT2003Fonts.FontEurostile37` | Acentos corridos un lugar |
| `UT2003Fonts.FontNeuzeit37` | Acentos corridos un lugar |
| `UT2003Fonts.FontLarge1024x768` | Acentos corridos un lugar |
| `UT2003Fonts.jFontLarge1024x768` | Acentos corridos un lugar |

Comprobado en el juego: con `FontEurostile37`, "TENÉS POCO KAYROS" se veía "TENÊS POCO KAYROS"; con `FontEurostile29` se ve bien.

`UT2003Fonts.FontEurostile29` y `UT2003Fonts.FontEurostile24` dibujan bien todos los caracteres del español (`á é í ó ú ñ Á É Í Ó Ú Ñ ¿ ¡`).

Por eso:

- **Mensajes grandes del centro de la pantalla** (Rey Cthulhu, Kayros): usan `FontEurostile29`. No volver a `FontEurostile37` si los mensajes llevan acentos.
- **Nombres y descripciones del menú:** el menú no usa esas cuatro fuentes; en el juego se vieron bien las minúsculas con acento y `¿`. `¡` y las mayúsculas `Á Í Ó Ú` no se probaron todavía en el menú.
- **Chat de los bots:** `¡`, `¿` y `Ñ` se ven bien (comprobado en el juego).
- Antes de usar otra fuente con acentos, probarla en el juego: que tenga una imagen para cada letra no garantiza que sea la letra correcta.

### Acentos dentro del código (`.uc`)

- Los `.uc` se guardan en **UTF-8**, pero el compilador los lee como Latin-1. Una `á` escrita directamente en un texto entre comillas sale rota en el juego.
- En el código, escribir los caracteres especiales con `Chr()`:

  | Carácter | Código | Carácter | Código |
  |---|---|---|---|
  | `á` | `Chr(225)` | `Á` | `Chr(193)` |
  | `é` | `Chr(233)` | `É` | `Chr(201)` |
  | `í` | `Chr(237)` | `Í` | `Chr(205)` |
  | `ó` | `Chr(243)` | `Ó` | `Chr(211)` |
  | `ú` | `Chr(250)` | `Ú` | `Chr(218)` |
  | `ñ` | `Chr(241)` | `Ñ` | `Chr(209)` |
  | `¿` | `Chr(191)` | `¡` | `Chr(161)` |

  Ejemplo: `"TEN" $ Chr(201) $ "S MUCHO KAYROS"`.
- En `defaultproperties` no se puede usar `Chr()`. Si un texto por defecto necesita acentos, asignarlo en `PostBeginPlay` o dejarlo sin acentos.
- Otra opción, la que usan las frases de `MutChatDokaBots`: escribir los acentos tal cual en el `.uc` y pasar el texto por `FixAccents` antes de usarlo. El compilador guarda los dos bytes UTF-8 de cada letra (por ejemplo `C3 81` para `Á`) y `FixAccents` los vuelve a unir en el juego. Así las frases se leen bien en GitHub y se pueden escribir con tildes normalmente. Para las frases con el nombre de un jugador se usa `WithName("... %n ...", Nombre)`, que arregla los acentos sin tocar el nombre.
- Los `FriendlyName` y `Description` de las clases quedan **sin acentos** a propósito: son solo el texto de respaldo si falta el `.int`. Lo que se ve en el menú sale del `.int`/`.est`.
- En los comentarios del código, mejor sin acentos para no mezclar codificaciones.

## Otras cosas a tener en cuenta

- **Oleadas:** `Invasion.WaveNum` empieza en 0; en pantalla se muestra `WaveNum + 1`. La oleada 9 es `WaveNum == 8`.
- **Nombres en el menú:** la lista de mutadores se ordena alfabéticamente sin distinguir mayúsculas, comparando letra por letra (los símbolos como `[`, `]` y `_` quedan antes que las letras). Con el prefijo `[Irreal]` los nuestros quedan juntos al principio, y `[Irreal_Test]` queda justo después de ellos (con un espacio, `[Irreal Test]`, quedaría antes).
- **Descripciones en el menú:** el carácter `|` es un salto de línea en el cuadro de descripción. No usarlo para separar opciones; usar comas o `/`. El juego guarda la selección por nombre de clase, así que cambiar el nombre visible no rompe configuraciones guardadas. Los nombres tienen que ser únicos.
- **Recursos:** el paquete se compila solo con código. Usa recursos del juego en lugar de recursos propios: la skin original del WarLord (con brillo violeta/rojo), el sonido `SkaarjPack_rc.WarLord.laugh1WL` y la fuente `UT2003Fonts.FontEurostile29` para los mensajes grandes.
- **Tecla para la siguiente oleada (Control de plagas FV):** el comando es `mutate nextwave`. No conviene asignarlo a la `Q`, que por defecto es el translocator. Por ejemplo: `set input H mutate nextwave` en la consola (queda guardado).
- **Jugar en red (`bAddToServerPackages`):** cada mutador tiene `bAddToServerPackages=True` en `defaultproperties`. Sin eso, el servidor no les manda el paquete a los que se conectan y a ellos no les llega nada de lo que existe en su máquina (radar, Visión, mensajes, armas con adrenalina, efectos del Rey Cthulhu): todo funciona para el host y nada para los demás. Un mutador nuevo tiene que llevarlo. Se prueba solo con un servidor dedicado: en Host Game, **DEDICATED**, y después conectarse a la propia partida desde Join Game → LAN (o `open 127.0.0.1` en la consola).
- **`Owner` en los clientes:** en las clases que heredan de `Info` (y `ReplicationInfo`), `Owner` no se replica (`bSkipActorPropertyReplication=True`), así que en la máquina del jugador vale `None`. Si un actor así tiene `bOnlyRelevantToOwner`, en el cliente solo existe el propio y no hace falta mirar `Owner` (ver `GigaVisionInfo`).
- **Instalar una versión nueva:** todos (host y clientes) tienen que tener los mismos `MyInvasionMut.u`, `.ucl`, `.int` y `.est` en la carpeta `System`, con el juego cerrado. Si no, aparece el error de versión del paquete no coincidente.
