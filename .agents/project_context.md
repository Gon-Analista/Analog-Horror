# Contexto del proyecto: ¡Hola, Vecinitos! (título provisional)

## Identidad y objetivo

Juego de terror analógico **cooperativo online** (1–4 jugadores) en **3D, primera persona, con gráficos pixel art de baja resolución**. La meta es un loop corto, rejugable y terrorífico que produzca momentos memorables al jugarlo en grupo y en directo, pensado para que lo jueguen youtubers y streamers de terror grandes y para que sus clips circulen solos.

**ADN del proyecto: el juego no intenta parecer un juego de terror; intenta parecer evidencia.** Partimos de algo que el jugador reconoce como normal y fiable —un programa infantil, una alerta de emergencia, una videocámara doméstica— y lo contaminamos con algo imposible. La base teórica está en `Informe_terror_analogico.md` y el mercado en `Investigacion_viralidad.md`; ante cualquier duda de tono, releerlos.

La estética VHS/pixel es una **herramienta**, no la idea: la baja resolución esconde, sugiere y obliga a la imaginación a completar. Aquí además **el medio analógico es la mecánica**: solo la cámara VHS ve a la entidad.

## Regla de decisión

Ante cada decisión de diseño, arte, audio, interfaz, texto, red o interacción, preguntar:

1. **¿Seguiría siendo inquietante si quitáramos todos los efectos VHS?** Si no, falta idea, no efecto.
2. **¿Primero establece confianza y después la rompe?** Lo cotidiano e institucional debe sentirse creíble antes de corromperse.
3. **¿Genera un momento que un grupo comentaría en voz alta o que alguien recortaría como clip?** Que se entienda en 20 segundos de vídeo sin contexto.
4. **¿Funciona igual de bien con 4 jugadores en red que con 1?** Todo se diseña pensando en el online.

Si una idea mejora el espectáculo pero rompe la credibilidad del material o depende del susto barato, adaptarla hasta que respete el ADN.

## Concepto (decidido por el usuario el 2026-10-25)

Fusión de las tres direcciones propuestas: **«Solo la cámara la ve»** + **la mascota de una cinta infantil perdida** + **la alerta de emergencia que miente**.

- **El mundo:** 14 de octubre de 1989. Tras «la emisión del 14 de octubre», el Canal 9 local emitió por error un episodio de *¡Hola, Vecinitos!*, un programa infantil que nunca debió salir al aire. Después de esa noche, el barrio fue evacuado. Las televisiones siguen encendidas con un aviso de emergencia.
- **Los jugadores:** un equipo contratado (1–4) para entrar de noche en las casas evacuadas y **recuperar todas las copias de la cinta** antes de que amanezca.
- **La entidad, «la Visita»:** Vecinito, la mascota del programa. Un oso de felpa mostaza de 2,3 m, brazos demasiado largos, ojos negros brillantes y una sonrisa pintada demasiado ancha. Es **clara e icónica** (funciona en una miniatura), pero su origen y sus razones quedan abiertos.
- **Reglas de la entidad (simples, aprendibles viendo un directo):**
  1. **A simple vista no existe.** Solo se ve a través del visor de la videocámara VHS.
  2. **No se mueve mientras alguien la graba.** Grabar gasta batería.
  3. **Viene más rápido cuando nadie mira hacia ella.**
  4. **Se oye:** una canción de caja de música la acompaña y **se calla mientras la están grabando**. Sus pasos pesados se oyen cuando avanza.
  5. **Las luces y la linterna fallan cerca de ella.**
  6. Despierta con la primera cinta recogida y **escala con cada cinta**: más rápida, la canción más desafinada.
- **La autoridad corrompida:** las televisiones dan las reglas oficiales de supervivencia. A mitad de la noche, el aviso cambia y empieza a mentir («Ya no es necesario grabar. Apague la cámara. La Visita es su amiga»).

### Loop de partida (15–20 min, objetivo para el cooperativo)

1. **Furgoneta (lobby):** el aviso de la noche y el equipo. Las videocámaras son escasas (orientativo: una cada dos jugadores), lo que crea roles: quien graba y quien recoge.
2. **Casa evacuada:** buscar las cintas con linterna. Cada casa varía (distribución, cintas, luces que funcionan, qué regla miente).
3. **La Visita despierta** con la primera cinta. El equipo se coordina por voz de proximidad: «¡No dejes de grabar!», «¿Se calló la canción?».
4. **Gestión de recursos:** la batería se agota, hay pilas escondidas y la cámara puede pasar de mano. Si cae quien graba, la cámara queda en el suelo grabando.
5. **El aviso miente:** el equipo debe decidir si cree a la televisión.
6. **Extracción:** volver a la furgoneta con la cuota antes del amanecer o de quedarse sin batería.
7. **Después de la noche:** ver las cintas recuperadas (episodios de lore en formato terror analógico) y la grabación de vuestra propia noche (el clip para compartir).

**Meta a largo plazo (no prototipar aún):** más calles y casas, mejor equipo (zoom, modo nocturno), y la historia humana del creador del programa y de las familias del barrio, contada en las cintas.

### Momentos de clip buscados

- La batería parpadea en rojo con la Visita a dos metros.
- Alguien se da la vuelta y la canción vuelve a sonar.
- La televisión dice «apague la cámara» y alguien la apaga.
- Quien grababa cae y su cámara sigue grabando en el suelo.

## Pilares de experiencia

- **Corromper la autoridad (LOCAL58):** la televisión de emergencia es fiable al principio y luego parte del peligro.
- **La espera vale más que el susto (Gemini):** tensión → revelación → silencio. El único susto fuerte es la captura (ganada, breve) y siempre va seguida de «SIN SEÑAL».
- **Lo que falta asusta más que lo que se ve:** a simple vista solo hay sonido, luces que fallan y consecuencias. Se ve con claridad solo en el visor, y con ruido.
- **El casi-humano:** una mascota infantil que es *casi* amable. Más adelante, explorar que la Visita imite a compañeros en la cámara.
- **Normalidad → anomalía → evidencia → patrón → implicación → silencio:** cada noche y la campaña completa siguen esta curva.
- **El jugador es investigador:** las cintas y los avisos esconden pistas consistentes (ver «Lore»).
- **Una historia humana debajo (Walten Files):** quién hizo el programa, qué les pasó a las familias del barrio.
- **Rejugable y clipeable:** partidas cortas, variaciones por semilla y reglas que generan situaciones que se cuentan solas.

## Dirección de arte

- **3D en primera persona con pixel art:** resolución interna 480×270 escalada por enteros con filtrado nearest. Texturas pequeñas (32 px por metro) con nearest + mipmaps, geometría low-poly, cuantización de color con tramado ordenado (post-proceso).
- **Atmósfera:** casas suburbanas de los 80 a oscuras, papel pintado gastado, azulejos, madera, polvo. Niebla volumétrica ligera, lámparas cálidas inestables, la luz azul de la televisión y la linterna como luz principal con sombras duras (sin suavizado, más pixel art).
- **Dos registros visuales:**
  - **A simple vista:** imagen limpia (dentro de lo pixelado), oscura, cálida y silenciosa.
  - **El visor VHS:** ganancia de luz (se ve mejor en la oscuridad), color lavado, aberración cromática, scanlines, grano, tracking, interfaz REC/batería/contador/fecha. Interferencia cuando la Visita está cerca.
- Los efectos VHS **solo en el visor y en momentos con propósito**, nunca como filtro permanente.
- Interfaces diegéticas: aviso de emergencia en CRT, visor de la cámara, pantallas «SIN SEÑAL».
- La entidad es un placeholder hecho con primitivas. Su versión final será un modelo low-poly con textura pixel art que conserve la silueta (orejas redondas, cabeza enorme, brazos largos) y la cara pintada.

## Sonido y música

- El audio es la mitad del terror: zumbido, estática, tono de emergencia, pasos, el silencio de una casa vacía.
- **La canción de la caja de música** es la firma sonora de la Visita: indica que está cerca y se calla cuando la graban.
- **Chat de voz por proximidad** como pieza central del cooperativo.
- Un susto sonoro solo en la captura.
- Todo el audio debe ser apto para streaming. Los placeholders actuales son síntesis propia (`tools/gen_audio.py`).

## Interfaz e interacciones

- HUD mínimo: un punto de mira, el aviso de interacción y mensajes breves. Todo lo demás es diegético (visor, televisión).
- Controles: WASD, ratón, **clic derecho mantenido = cámara**, F linterna, E recoger, Shift correr, F3 datos de rendimiento, F11 pantalla completa, R reintentar al final.
- Las pantallas de intro y de final forman parte de la ficción (tarjeta de fecha, «SIN SEÑAL», «CINTA RECUPERADA»).

## Lore

- El mundo tiene **respuestas definidas aunque el jugador solo vea fragmentos**. Mantenerlas en `.agents/lore.md` (por crear) antes de esparcir pistas: qué es la Visita, quién hizo el programa, qué pasó el 14 de octubre.
- Pistas consistentes entre partidas y actualizaciones para teorías de comunidad y ARG.

## Alcance actual

- **Prototipo para un jugador** (decisión del usuario, 2026-10-25) para encontrar el estilo gráfico y el loop básico antes del online.
  - Una casa (`HouseMap`), linterna, videocámara con batería, la Visita con sus reglas, 6 cintas de las que hay que recoger 5, pilas, una televisión que se corrompe a la tercera cinta, salida por la puerta principal, captura con «SIN SEÑAL» y reinicio.
- El código ya separa el estado autoritativo (`Run`, el movimiento de la entidad) de la presentación local (visor, post-proceso, sombras y audio de la entidad), para pasar al online sin rehacerlo.
- Siguiente objetivo tras validar el estilo: la vertical slice online (lobby EOS, 2–4 jugadores, cámaras compartidas, voz por proximidad).
- No añadir progresión, tienda ni campaña antes de que una noche dé miedo jugándola.

## Tecnología y organización

- Motor: **Godot 4.7.2** con GDScript y Forward+ (sombras dinámicas, niebla volumétrica). Ejecutable local: `C:\Users\usuario\Desktop\Godot_v4.7.2-stable_win64.exe`. GPU de desarrollo: Intel Iris Xe (integrada; buena referencia de gama baja).
- Proyecto en `game/`; la raíz guarda documentación (`.agents/`, informes) y herramientas (`tools/`).
- **Render:** viewport 480×270 (`stretch/mode="viewport"`, escala entera, ventana 1440×810), sin MSAA/FXAA, sombras duras (`soft_shadow_filter_quality=0`), proyector de linterna nearest, atlas de sombras 2048. Texturas importadas sin compresión, con mipmaps y sin detección 3D (`[importer_defaults]`), para que el pixel art no se emborrone.
- **Estructura del código:**
  - `data/tuning.gd`: todos los números de juego y las capas de física.
  - `data/house_map.gd`: el mapa ASCII de la casa (leyenda en el archivo).
  - `scripts/world/level.gd`: construye la casa. Una malla con una superficie por material, un colisionador trimesh, muebles, lámparas, rejilla transitable con BFS y los puntos del mapa.
  - `scripts/core/run.gd`: estado de la noche (autoritativo) con fase, cintas, escalada, captura y huida.
  - `scripts/entity/entity.gd`: la Visita. Capa visual 2, que solo renderiza la cámara al grabar.
  - `scripts/player/`: jugador (`player.gd`) y videocámara (`camcorder.gd`).
  - `scripts/ui/`: post-proceso, visor, HUD, pantallas y overlay F3.
  - `shaders/post.gdshader`: una sola pasada a pantalla completa (tramado, cuantización y VHS).
  - `scripts/core/`: también `controls.gd` (acciones de entrada, remapeables) y `sfx.gd` (caché de audio).
- **Assets placeholder generados:** `python tools/gen_textures.py` y `python tools/gen_audio.py`. Después hay que importar con `godot --headless --path game --import`.
- **Pruebas de desarrollo** (todas tras `--`):
  - `godot --headless --path game -- --smoke`: comprueba las reglas (grabar congela, sin grabar te alcanza desde su cuarto, la cuota abre la salida). Imprime líneas `SMOKE ok` / `SMOKE FAIL` y su código de salida indica si falló algo.
  - `godot --path game -- --shots <carpeta absoluta>`: recorrido fijo que guarda 6 capturas a 480×270 (pasillo, televisión, cocina, entidad a simple vista, por la cámara y de cerca).
  - `--seed N` fija la colocación de las cintas.
- MCP de Godot (`Coding-Solo/godot-mcp`, en `C:\Users\usuario\mcp\godot-mcp`) registrado en `.mcp.json`.
- **Online con Epic Online Services (EOS)**, producto `horror-proyect` (cliente Peer2Peer, sandbox y despliegue Live).
  - Credenciales en `game/eos/credentials.cfg`, ignorado por git.
  - El C SDK 1.19.1 está en `epic_sdk/` como referencia y no se sube.
  - El juego usa el plugin **EOSG 2.3.1** (`game/addons/epic-online-services-godot/`), que trae su propia DLL. Sus binarios no van en git: `python tools/get_eosg.py` los descarga. Lleva un parche heredado: `EOS.Achievements` renombrado `EOS.Achievement`.
- **Capa de red:** `game/scripts/net/eos_net.gd` (autoload `EosNet`). Login Device ID, sala de hasta 4 con código de 5 caracteres y `EOSGMultiplayerPeer` (socket `analog`). Falta RTC para la voz.
  - Prueba: `godot --headless --path game res://scenes/dev/eos_check.tscn` → `EOS_CHECK ok code=…` (verificado el 2026-10-25).
  - Trampas conocidas:
    - `application/config/version` vacío hace fallar `EOS_Initialize`.
    - Liberar la plataforma dentro del tick de EOS cierra el juego con signal 11.
    - El Client ID del portal lleva `9Ii`.
- **Modelo online previsto:** host autoritativo. `Run` y el movimiento de la entidad corren en el host, que necesita de cada jugador `filming` y la transformación de su cámara. Visibilidad, sombra, audio y post-proceso son locales.
- Plataforma objetivo inicial: Windows (Steam/itch a decidir).

## Cómo evaluar una propuesta visual o jugable

Revisar el conjunto con las capturas (`--shots`) y jugando:

- ¿La casa se siente real y abandonada antes que «de terror»?
- ¿A simple vista hay tensión sin ver nada?
- ¿El visor da miedo por lo que muestra y no solo por el ruido?
- ¿Las reglas de la Visita se entienden sin explicación?
- ¿Produciría una reacción que alguien querría compartir?

La referencia de calidad es una noche corta, completa y convincente: un lugar creíble, una regla que se aprende con miedo, una televisión que da escalofríos cuando cambia y un final que deja silencio.
