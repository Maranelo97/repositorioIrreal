# Mutadores Ver 1.1

Automatización de actualizaciones al activar Radmin: ver [automation/README.md](automation/README.md). Incluye publicación desde `production`/`Production` y un actualizador para las PCs de los amigos.

Documento de estado del paquete `MyInvasionMut` para Unreal Tournament 2004.

La lista y las descripciones se basan en las fuentes actuales del paquete y en las pruebas LAN realizadas hasta el 1 de noviembre de 2026. Las clases auxiliares de reglas, mensajes, efectos visuales, daño y pickups no se cuentan como mutadores separados.

## 1 - Listado general de los mutadores que tenemos

1. `MutCuidenAFer` — **Cuiden a Fer!**
2. `MutInvasionPause` — **Control de plagas FV**
3. `MutInstantRespawn` — **Es todo muy irreal**
4. `MutMarianoskyRage` — **Marianosky's rage**
5. `MutChatDokaBots` — **Chat-doka Bots**
6. `MutNeedMoreBots` — **Necesitamos mas BOTS**
7. `MutInvasionUltimates` — **Invasion: Armas ultimas**
8. `MutSixSeven` — **Six Seven**
9. `MutKayros` — **Poco o mucho Kayros?**
10. `MutLeTransmitoTodoAMiBB` — **Le transmito todo a mi BB**

El paquete también incluye clases de apoyo para `MarianoskyRage`, `CuidenAFer`, `ChatDokaBots`, `Kayros` e infección. Esas clases permiten aplicar reglas, mensajes y efectos, pero no se seleccionan como mutadores independientes.

## 2 - Descripción detallada de cada uno

### 2.1 — Cuiden a Fer!

Protege al jugador designado como Fer durante una partida de Invasion. El mutador aplica restricciones y reglas especiales sobre ese jugador, mantiene las condiciones de protección y fuerza el comportamiento de los monstruos relacionado con Fer.

Su descripción actual limita expresamente las combinaciones permitidas a `Necesitamos mas BOTS`, `Chat-doka Bots`, `Invasion: Armas ultimas` y el mutador externo de Salto cuádruple. Esa regla es intencional y se conserva sin cambios.

### 2.2 — Control de plagas FV

Cuando termina una oleada, congela el inicio de la siguiente hasta que se presiona la tecla `Q`. Durante la pausa otorga un aumento temporal de velocidad del 50% para permitir que los jugadores recojan objetos del mapa.

La pausa usa un contador de oleada muy alto para impedir que Invasion avance por su cuenta. Al recibir la orden, libera el contador y permite iniciar la ronda siguiente.

### 2.3 — Es todo muy irreal

Reduce prácticamente a cero el tiempo de reaparición de los objetos del suelo, incluyendo munición, salud, escudos y armas. El mutador establece `bInstantRespawn`, un tiempo de 0,05 segundos y un tiempo de efecto de reaparición igual a cero.

No modifica los objetos que los jugadores dejaron caer. Su efecto puede interactuar con cualquier otro mutador que controle recogidas o puntos de armas.

### 2.4 — Marianosky's rage

En cada oleada hay un 25% de probabilidad de que aparezca un único Rey Cthulhu basado en un WarLord. El jefe actual tiene:

- 30% más de tamaño.
- 2.000 puntos de vida base más 500 por cada jugador humano.
- 300 de escudo.
- 20% más de velocidad.
- 50% menos de daño recibido; contra ataques de bots la reducción llega al 65%.
- 50% menos de retroceso.
- Cambio a estado de furia al 35% de vida.
- Skin roja en furia, llamas en alas y pies y corona giratoria.

La presentación del Rey, el sonido, el movimiento de cámara y sus efectos visuales se transmiten mediante actores auxiliares replicados. El arreglo más reciente mantiene al jefe relevante para la red cuando se aleja de la vista y reaplica su apariencia cuando vuelve a ser visible.

### 2.5 — Chat-doka Bots

Hace que los bots escriban frases personalizadas y contextuales en el chat. Tiene respuestas para la aparición del Rey Cthulhu, bajas con Redeemer o Ion Painter, eventos de Kayros y muertes de jugadores humanos.

Las frases están contenidas en el propio mutador y se envían según eventos de la partida. El contenido es principalmente cosmético y depende de que los otros mutadores informen correctamente sus eventos.

### 2.6 — Necesitamos mas BOTS

Mantiene una proporción dinámica de tres bots por cada jugador humano conectado. Si faltan bots, intenta agregarlos; si sobran, elimina los excedentes. El ajuste se revisa periódicamente y también contempla desconexiones de jugadores.

La cantidad final depende de los límites y de la capacidad de `DeathMatch` para crear bots. El mutador tiene un límite de seguridad para evitar bucles de creación.

### 2.7 — Invasion: Armas ultimas

Elige un único punto de arma del mapa y lo convierte en un punto especial. Durante la partida rota al azar entre cuatro armas:

- Redeemer.
- Target Painter.
- Ion Painter.
- Lightning Gun.

El cambio ocurre al detectar una nueva oleada. Las armas personalizadas tienen reaparición prácticamente instantánea y la intención es que, una vez recogidas, permanezcan en el inventario del jugador.

El mutador desactiva otros puntos de armas especiales para concentrar la rotación en un solo punto. Actualmente puede repetir el arma de la oleada anterior porque cada sorteo es independiente.

### 2.8 — Six Seven

En partidas por equipos, coloca a todos los jugadores humanos en el equipo azul y a todos los bots en el equipo rojo. Revisa periódicamente los controladores y vuelve a aplicar la distribución cuando entra un jugador nuevo.

En modos que no son partidas por equipos no modifica la partida.

### 2.9 — Poco o mucho Kayros?

Al comenzar cada oleada elige un jugador humano al azar y le asigna uno de dos estados:

- Mucho Kayros: aumento del 20% en los pickups.
- Poco Kayros: reducción del 20% en los pickups.

El estado se aplica mediante reglas de juego y se comunica al sistema de chat cuando está disponible. El cálculo afecta de forma distinta a cada arma según cómo consuma munición el arma base.

### 2.10 — Le transmito todo a mi BB

Después de la oleada 8 existe un 30% de probabilidad por oleada de que aparezca un Elite Krall especial. Su rayo inicia la infección, que se propaga por proximidad dentro de un radio de 180 unidades.

La infección puede curarse con la Entrelazadora después de 10 segundos y se revisa cada 0,25 segundos. Al iniciar una nueva oleada se limpian las infecciones de la ronda anterior.

## 3 - Informe de incongruencias y errores hasta el momento

### 3.1 — Incongruencias en las descripciones del menú

- `Invasion: Armas ultimas` todavía tiene textos de idioma que hablan solo de Redeemer y Target Painter, de dos minutos de respawn y de exclusión de la Entrelazadora. El código actual usa cuatro armas y respawn casi instantáneo.
- `Marianosky's rage` todavía aparece en los archivos de idioma con una versión vieja: 40% de probabilidad, 2.500 de vida base, 500 de armadura y estadísticas distintas. El código actual usa 25%, 2.000 de vida base, 300 de escudo y los valores detallados en este documento.
- `Es todo muy irreal` también tenía una descripción antigua que no mencionaba armas ni objetos soltados; la descripción del código ya fue actualizada, pero los archivos de idioma deben sincronizarse.

### 3.2 — Problema de Kayros con Redeemer

El Redeemer tiene una sola carga máxima. Cuando `Poco Kayros` calcula una reducción de munición, el redondeo mínimo consume al menos una unidad. En la práctica, un Redeemer recién recogido puede quedar vacío inmediatamente.

Los Painters tienen otra ruta de consumo y no se comportan igual, por lo que el mismo modificador no produce un resultado uniforme entre armas.

### 3.3 — Restricciones de los Painters en mapas de Invasion

Los Painters necesitan condiciones geométricas específicas: espacio vertical, línea libre y una zona válida para el bombardeo. En sectores interiores o con techo bajo de mapas como HyperBlast2, el rayo puede marcar el punto pero el ataque puede ser rechazado.

Esto es una limitación de la mecánica original del arma, pero el mutador no informa al jugador por qué el ataque no se ejecutó. El resultado se percibe como un fallo del arma.

### 3.4 — Recarga y permanencia de las armas especiales

Invasion repone la munición de muchas armas entre oleadas, pero excluye Redeemer y ambos Painters. Por eso las armas pueden permanecer en el inventario y, aun así, quedar vacías.

La Lightning Gun además hereda el comportamiento global de `bWeaponStay`. Si el jugador ya la tiene, volver a tocar el punto puede ser rechazado aunque se quisiera usarlo como recarga.

### 3.5 — Recogida repetida en el punto especial

Con respawn de 0,05 segundos, un jugador que permanece parado sobre el punto puede activar repetidamente la recogida. Esto puede producir sonidos, eventos y objetos temporales innecesarios, además de impedir que otro jugador aproveche el punto.

El problema es especialmente probable cuando el arma ya está llena de munición y la recogida no aporta nada.

### 3.6 — Falta de recuperación si falla la aparición del arma

`Invasion: Armas ultimas` elimina el pickup anterior y no verifica de forma completa que el nuevo pickup haya quedado creado. Si la aparición falla, el punto puede quedar vacío hasta el siguiente cambio de oleada y el sistema no muestra un aviso claro.

### 3.7 — Rotación y momento del cambio

El cambio de arma se procesa mediante un temporizador. Durante la preparación de una nueva oleada puede seguir visible el arma anterior y la nueva rotación no queda disponible hasta que el mutador detecta la oleada activa.

Además, repetir el mismo arma en dos oleadas consecutivas está permitido por diseño actual. No es un error de código, pero puede parecer que la rotación no funcionó.

### 3.8 — Desactivación de puntos de Lightning Gun

Al seleccionar el punto especial, el mutador considera especial a la Lightning Gun y desactiva otros puntos de armas especiales. Si el mapa tenía Lightning Guns normales que se querían conservar, también pueden desaparecer.

Debe definirse si la intención es controlar solo el pedestal elegido o retirar todas las Lightning Guns del mapa.

### 3.9 — Efectos visuales del Rey en red

En las pruebas anteriores, todos los jugadores llegaron a ver la presentación, el sonido, la cámara y la apariencia inicial. En HyperBlast2, cuando el Rey salía de pantalla y volvía a aparecer, algunos clientes lo veían con la apariencia normal.

La causa técnica identificada fue la falta de una garantía uniforme de relevancia y de reaplicación cuando el jefe o sus componentes visuales perdían temporalmente la referencia. El paquete recompilado mantiene los actores relevantes y reaplica la apariencia, pero la confirmación definitiva depende de una nueva prueba LAN con todos los clientes.

### 3.10 — Riesgo de versiones mezcladas

El error de “versión del paquete no coincidente” se produce si el host y un cliente cargan distintos `MyInvasionMut.u`. Todos deben usar el mismo `.u` y `.ucl`, instalar el mismo ZIP y cerrar UT2004 completamente antes de reemplazar archivos.

La compilación más reciente quedó validada con 0 errores y 0 advertencias. El paquete distribuido tiene SHA-256 `4487F5C422CEE8F224697C25D06CE330DEECF945E19339CEC2FCCE423D0814D3`.

### 3.11 — Cuiden a Fer

La regla de compatibilidad y protección de `Cuiden a Fer` es una decisión de diseño vigente. No se considera un error y no forma parte de las propuestas de modificación de este informe.

## 4 - Oportunidades de mejora

1. Unificar las descripciones de código, menú e idiomas para que cada mutador anuncie exactamente lo que hace.
2. Corregir el cálculo de `Poco Kayros` para que no vacíe un Redeemer de una sola carga.
3. Definir un tratamiento común para armas de munición única y armas con consumo especial.
4. Implementar una recarga explícita entre oleadas para Redeemer, Target Painter, Ion Painter y Lightning Gun.
5. Permitir que el punto especial recargue una Lightning Gun ya poseída, aunque esté activo `bWeaponStay`.
6. Bloquear recogidas que no aporten munición y evitar repeticiones mientras el jugador siga sobre el punto.
7. Verificar que cada pickup se creó correctamente y reintentar o recuperar el punto si la aparición falla.
8. Hacer que la nueva arma se coloque durante la preparación de la siguiente oleada, según la regla que se elija.
9. Añadir un aviso claro cuando un Painter no pueda ejecutar un ataque por falta de espacio o línea libre.
10. Decidir explícitamente si se permiten armas repetidas entre oleadas.
11. Decidir explícitamente si las Lightning Gun normales del mapa deben conservarse.
12. Añadir trazas de diagnóstico opcionales para servidor y clientes: oleada, arma elegida, pickup creado, recogida rechazada y reaparición fallida.
13. Mantener `bAlwaysRelevant`, la referencia persistente al jefe y la reaplicación de visuales del Rey como una única política de red, en lugar de resolver cada efecto por separado.
14. Probar cada combinación relevante de mutadores en un servidor dedicado local antes de publicar una nueva versión.
15. Publicar un ZIP versionado con hash, fecha, lista de archivos y una instrucción única de instalación para evitar paquetes mezclados.

## 5 - Sugerencias finales para la Ver 1.2

### Prioridad alta

1. Corregir primero el vaciado de Redeemer provocado por `Poco Kayros`.
2. Implementar recarga y recogida coherentes para las cuatro armas de `Invasion: Armas ultimas`.
3. Añadir recuperación cuando el pickup especial no se crea.
4. Sincronizar todas las descripciones de idioma con el comportamiento real.
5. Repetir la prueba LAN de Marianosky's Rage en HyperBlast2, verificando al mismo tiempo skin, llamas, corona, sonido y retorno después de salir de pantalla.

### Prioridad media

6. Evitar recogidas repetidas sin ganancia.
7. Mostrar mensajes de compatibilidad cuando un Painter no pueda bombardear el lugar marcado.
8. Definir la política de repetición de armas y el momento exacto de la rotación.
9. Definir si las Lightning Gun normales del mapa deben permanecer activas.

### Prioridad de mantenimiento

10. Incorporar una prueba de servidor dedicado local al proceso de compilación.
11. Generar automáticamente un informe de hash para el host y los clientes.
12. Mantener una copia de respaldo de cada versión distribuida.
13. Documentar qué mutadores son obligatorios para cada combinación y conservar la regla vigente de `Cuiden a Fer`.

La Ver 1.2 debería publicarse solo después de comprobar tres cosas en una partida real: que las armas ultimas se puedan recoger y recargar de forma consistente, que los Painters den una respuesta clara cuando el mapa no permite el ataque y que todos los clientes mantengan la apariencia completa del Rey después de perderlo de vista.
