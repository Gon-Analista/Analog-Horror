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
- **La entidad, «la Visita»:** Vecinito, el personaje animado del programa, **dibujado a tinta como un dibujo animado** que se escapó de la cinta (rediseño pedido por el usuario el 2026-10-25, con referencias a Mandela Catalogue):
  - Una máscara alargada, pálida y algo torcida (*casi* una cara), con cuencas hundidas y ojos que son agujeros negros con un punto de luz que te mira.
  - Restos de orejas de mascota y pelos como púas rayadas.
  - La boca: la mandíbula desencajada. Un agujero ancho rasgado por las comisuras hacia las orejas, una fila de dientes humanos pequeños, cuadrados y amarillentos (algunos faltan) sobre encías oscuras, y los dientes de abajo colgando a la altura de la barbilla, donde no debería haber mandíbula. El agujero sigue bajando por el cuerpo.
  - Nada de rasgos simpáticos de dibujo animado en la cara (ojos saltones, colorete, sonrisa de dientes): la hacían graciosa (feedback del usuario). Lo caricaturesco queda en el trazo de tinta y la animación que tiembla.
  - Alta y delgada (cabeza pequeña para el cuerpo, cuello largo), cuerpo de tinta encorvado, brazos de goma demasiado largos que pasan de las rodillas y **manos pálidas con cinco dedos larguísimos**, doblados y con las puntas negras. Dedos de los pies largos y abiertos.
  - Sin guantes ni zapatos de dibujo animado: resultaban graciosos (feedback del usuario).
  - Las líneas «hierven» como la animación hecha a mano.
  - Es **clara e icónica** (funciona en una miniatura), pero su origen y sus razones quedan abiertos.
- **Reglas de la entidad (simples, aprendibles viendo un directo):**
  1. **A simple vista no existe.** Solo se ve a través del visor de la videocámara VHS.
  2. **No se mueve mientras alguien la graba.** Grabar gasta batería. Cada vez que la vuelves a encontrar en el visor está en **otra pose** (de pie, alargando una mano hacia la cámara, con la cabeza girada 90°, mirando entre los dedos o agachada), y a veces aparece un fotograma subliminal de su cara abalanzándose.
  3. **Viene más rápido cuando nadie mira hacia ella.**
  4. **Se oye:**
     - La sintonía del programa sale de una cinta moribunda y **se calla mientras la están grabando**.
     - Un dron grave se oye siempre a su alrededor.
     - Cuando nadie la graba, saluda («hola, vecinito»), o lo susurra si está cerca.
     - Sus pasos son un golpe sordo y pesado sobre tablas viejas que crujen, como algo grande que intenta no hacer ruido.
  5. **Las luces y la linterna fallan cerca de ella.**
  6. **Despierta cuando la alerta interrumpe el programa** (decisión del usuario, 2026-10-25). La tele del salón está emitiendo *¡Hola, Vecinitos!* con Vecinito en su **forma normal**: un osito mostaza simpático que saluda en un plató soleado. Con [E] lo ves a pantalla completa. Si sigues mirando, a los 2,5 s el programa empieza a estropearse durante 5 s: Vecinito deja de saludar y te mira fijo, se le vacían los ojos, se le cae la mandíbula, el color se apaga, la cinta se ralentiza y al final solo queda su cara. Después la señal se corta con estática y sale sola la alerta con las reglas. **La Visita despierta cuando dejas de leer la alerta** (o a los 20 s de leerla), para que dé tiempo a leer las reglas. Hasta entonces la casa está en silencio. Si nadie mira la tele, la alerta salta sola a los 120 s. **Escala con cada cinta**: más rápida, la sintonía más desafinada.
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
- **La casa (pasada de calidad del 2026-10-25):**
  - Papel pintado por habitación (damasco verde, estrellas en el cuarto infantil, rayas granate en el dormitorio) con manchas de agua, desconchones, humedad y rodapié.
  - Ventanas con cortinas rotas y luz de luna fría (focos sin sombra con proyector de marco de ventana).
  - Muebles con forma: sofá con respaldo y brazos, camas con cabecero y almohada, mesas con patas, encimeras.
  - Marcos de puerta, alfombra, cajas de mudanza, papeles por el suelo, fotos familiares con las caras rayadas, dibujos infantiles de Vecinito (uno tachado en negro).
  - Polvo en el aire que solo se ve en la luz de la linterna, y un grano de película leve también a simple vista.
  - La decoración fija está en `HouseMap.ZONES` / `DECOR` y en la semilla `Level.DECOR_SEED`, igual en todas las partidas.
- **Atmósfera:** casas suburbanas de los 80 a oscuras, papel pintado gastado, azulejos, madera, polvo. Niebla volumétrica ligera, lámparas cálidas inestables, la luz azul de la televisión y la linterna como luz principal con sombras duras (sin suavizado, más pixel art).
- **Dos registros visuales:**
  - **A simple vista:** imagen limpia (dentro de lo pixelado), oscura, cálida y silenciosa.
  - **El visor VHS:** ganancia de luz (se ve mejor en la oscuridad), color lavado, aberración cromática, scanlines, grano, tracking, interfaz REC/batería/contador/fecha. Interferencia cuando la Visita está cerca.
- Los efectos VHS **solo en el visor y en momentos con propósito**, nunca como filtro permanente.
- Interfaces diegéticas: aviso de emergencia en CRT, visor de la cámara, pantallas «SIN SEÑAL».
- **La entidad es un dibujo, no un modelo:** un sprite (`Sprite3D` billboard, sin iluminación) generado por `tools/gen_entity.py` a 128×224 px por fotograma, con 6 poses × 3 fotogramas de «hervor» a 8 fps.
  - Se desvanece con la distancia en vez de con la luz: es un dibujo que no pertenece al mundo.
  - Proyecta sombra solo cuando la ves por la cámara.
  - La versión final debería dibujarse a mano con el mismo lenguaje (tinta, máscara, guantes, boca que baja) y más poses.

## Sonido y música

- El audio es la mitad del terror: zumbido, estática, tono de emergencia, pasos, el silencio de una casa vacía.
- **Sonido analógico de verdad** (referencia: Mandela Catalogue, Local 58): todo lo de la Visita suena a material infantil reproducido desde una cinta que se muere. Lleva:
  - variaciones de velocidad (wow y flutter) y frenadas que hunden el tono;
  - cortes de señal (dropouts), saturación, siseo de cinta y graves apagados;
  - una voz de presentador sintetizada por formantes, grave y doblada una octava por debajo.
- **La sintonía de ¡Hola, Vecinitos!** (órgano de juguete con un último compás que se tuerce) es la firma sonora de la Visita: indica que está cerca y se calla cuando la graban. Además suenan su voz («hola, vecinito»), un dron, al pillarla en cámara la sintonía se frena y muere como una cinta parada a mano (nada de silbidos: sonaban graciosos) y el grito de la captura.
- **Chat de voz por proximidad** como pieza central del cooperativo.
- Un susto sonoro solo en la captura.
- Todo el audio debe ser apto para streaming. Los placeholders actuales son síntesis propia: `tools/gen_audio.py` (ambiente e interfaz) y `tools/gen_entity_audio.py` (la Visita).

## Interfaz e interacciones

- HUD mínimo: un punto de mira, el aviso de interacción y mensajes breves. Todo lo demás es diegético (visor, televisión).
- Controles: WASD, ratón, **clic derecho mantenido = cámara**, F linterna, E usar, Shift correr, C agacharse, F3 datos de rendimiento, F11 pantalla completa, R reintentar al final.
- Las pantallas de intro y de final forman parte de la ficción (tarjeta de fecha, «SIN SEÑAL», «CINTA RECUPERADA»).

## Lore

- El mundo tiene **respuestas definidas aunque el jugador solo vea fragmentos**. Mantenerlas en `.agents/lore.md` (por crear) antes de esparcir pistas: qué es la Visita, quién hizo el programa, qué pasó el 14 de octubre.
- Pistas consistentes entre partidas y actualizaciones para teorías de comunidad y ARG.

## Alcance actual

- **Primera versión jugable online (2026-10-25):** de 1 a 4 jugadores, en solo, en red local (para desarrollo) o online con Epic.
  - Una casa (`HouseMap`), linterna, videocámara con batería, la Visita con sus reglas, 6 cintas de las que hay que recoger 5, pilas, la tele (programa → se estropea → alerta → se corrompe a la tercera cinta), salida por la puerta principal.
  - **Menú y sala** (`scenes/menu.tscn`): nombre, jugar solo, crear sala online (código de 5 letras), unirse con el código (o con una IP para la red local), lista de jugadores con su color y «empezar» (solo el anfitrión). De fondo, el programa en una cinta gastada que a veces se estropea un instante.
  - **El anfitrión decide**: cintas, pilas, avance de la tele, despertar, capturas y final; los demás piden por RPC. La Visita persigue al jugador vivo más cercano y se congela si **cualquiera** la graba; cada uno la ve solo por su propia cámara.
  - **Captura en cooperativo**: la Visita se lanza a por ese jugador (solo él ve la cara), su cámara queda en el suelo grabando con la luz roja encendida y él pasa a ver por las cámaras de los demás (clic para cambiar). La noche acaba si escapan o si caen todos. El anfitrión reinicia con R; M vuelve al menú.
  - **Jugadores**: cada uno tiene un cuerpo (`PlayerAvatar`) con chaqueta de trabajo de su color, vaqueros y gorro, con la linterna en la mano izquierda y la cámara en la derecha. Tiene animación procedural: camina, la cabeza sigue la mirada, sube la cámara a la cara al grabar (la luz roja parpadea) y apunta la linterna. Se ven las linternas de los demás y su nombre al estar cerca.
  - **Primera persona** (`ViewModel`): manos con la linterna (de donde sale el haz) y la cámara; al grabar, la cámara sube hasta el ojo y la vista pasa al visor. Se balancea con los pasos y con el ratón.
- **Pasada del 2026-10-25 (tarde):**
  - **Música** (`tools/gen_music.py`; referencias: muzak y música de cierre de emisión de Local 58, ambient triste de Gemini, sintonías infantiles de los 80, todo desde un VHS gastado). Incluye:
    - `menu_theme`: «Fin de emisión», piano eléctrico FM, pad y la melodía del programa lejana en una campana; bucle de 60 s.
    - `show_theme`: la sintonía con bajo, glockenspiel, acordes y batería suave.
    - `jingle`: la canción de la Visita, con caja de música y piano en una cinta moribunda y una sala grande.
    - `house_ambience`: zumbido, viento y crujidos de fondo en la casa.
  - **Menú:** una habitación oscura iluminada solo por un televisor de madera que emite el programa (con cristal curvo y líneas), mientras suena el «Fin de emisión».
  - **Tele en 320×240** con mejor arte (cielo degradado, valla, flores, ventanas); el texto de la alerta va a 22 px.
  - **Agacharse con C** (alterna; no te levantas si hay algo encima). Dos puertas tapiadas con tablones desde 1 m (`U` en el mapa: cuarto infantil ↔ pasillo, salón ↔ baño) obligan a pasar agachado. Los demás ven tu cuerpo agachado (muslos y espinillas).
  - **Salida clara:** lámpara encima, cartel rojo de «SALIDA», luz por debajo de la puerta y los faros de la furgoneta por la ventanita. Con la cuota, los faros se encienden del todo y la furgoneta pita.
  - **Las cintas aparecen al despertar la Visita** (no antes) y suenan rebobinándose: se encuentran de oído.
  - **Manos en primera persona** más bajas, pegadas al cuerpo y abiertas a los lados; la linterna tiene un modelo nuevo (goma con anillos, bisel cromado).
- **Falta para el cooperativo completo:** voz por proximidad (RTC de Epic), cámaras escasas que se pueden pasar de mano, probar una sesión online real con varias personas y ajustar el juego en grupo.
- No añadir progresión, tienda ni campaña antes de que una noche dé miedo jugándola en grupo.

## Tecnología y organización

- Motor: **Godot 4.7.2** con GDScript y Forward+ (sombras dinámicas, niebla volumétrica). Ejecutable local: `C:\Users\usuario\Desktop\Godot_v4.7.2-stable_win64.exe`. GPU de desarrollo: Intel Iris Xe (integrada; buena referencia de gama baja).
- Proyecto en `game/`; la raíz guarda documentación (`.agents/`, informes) y herramientas (`tools/`).
- **Render:** el mundo 3D vive en un `SubViewport` de 480×270 (`WorldView/World` en `main.tscn`), escalado con nearest; el post-proceso va dentro de ese SubViewport. La interfaz se dibuja encima a la resolución real de la ventana (`stretch/mode="canvas_items"`, base 480×270, escala entera, ventana 1440×810) para que el texto sea nítido. El SubViewport tiene `audio_listener_enable_3d` activado (sin eso no se oye el audio 3D). Sin MSAA/FXAA, sombras duras (`soft_shadow_filter_quality=0`), proyector de linterna nearest, atlas de sombras 2048. Texturas importadas sin compresión, con mipmaps y sin detección 3D (`[importer_defaults]`), para que el pixel art no se emborrone.
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
- **Fuente:** VT323 (Google Fonts, licencia SIL OFL 1.1; `game/assets/fonts/` con `OFL.txt`), fuente por defecto del proyecto. Tamaños en coordenadas base de 480×270: 13 para la interfaz y 10 para el overlay F3. La televisión tiene un área para leer el aviso a tamaño completo ([E] Leer el aviso).
- **Assets placeholder generados:** `python tools/gen_textures.py`, `tools/gen_entity.py` (sprite de la Visita), `tools/gen_tv.py` (fotogramas del programa en la tele), `tools/gen_music.py` (música; antes que `gen_entity_audio.py`), `tools/gen_audio.py` y `tools/gen_entity_audio.py` (requiere scipy). Después hay que importar con `godot --headless --path game --import`.
- **Pruebas de desarrollo** (todas tras `--`):
  - `godot --headless --path game -- --smoke`: comprueba que la entrada llega al mundo 3D y las reglas (grabar congela, sin grabar te alcanza desde su cuarto, la cuota abre la salida). Imprime líneas `SMOKE ok` / `SMOKE FAIL` y su código de salida indica si falló algo.
  - `godot --path game -- --shots <carpeta absoluta>`: recorrido fijo que guarda 6 capturas a la resolución de la ventana, con la interfaz (pasillo, televisión, cocina, entidad a simple vista, por la cámara y de cerca). Imprime una línea `PERF`.
  - `--seed N` fija la colocación de las cintas.
  - Prueba de red con dos ventanas en el mismo PC: `godot --headless --path game -- --net-test host` y, en otra, `... --net-test client`. Cada una imprime una línea `NETTEST` (jugadores, cintas, dónde ve al otro y a la Visita). Verificado el 2026-10-25.
  - `--menu-shot <archivo.png>` guarda una captura del menú.
- MCP de Godot (`Coding-Solo/godot-mcp`, en `C:\Users\usuario\mcp\godot-mcp`) registrado en `.mcp.json`.
- **Online con Epic Online Services (EOS)**, producto `horror-proyect` (cliente Peer2Peer, sandbox y despliegue Live).
  - Credenciales en `game/eos/credentials.cfg`, ignorado por git.
  - El C SDK 1.19.1 está en `epic_sdk/` como referencia y no se sube.
  - El juego usa el plugin **EOSG 2.3.1** (`game/addons/epic-online-services-godot/`), que trae su propia DLL. Sus binarios no van en git: `python tools/get_eosg.py` los descarga. Lleva un parche heredado: `EOS.Achievements` renombrado `EOS.Achievement`.
- **Capa de red:**
  - `game/scripts/net/net.gd` (autoload `Net`): la sesión. Modos solo (`OfflineMultiplayerPeer`), red local (ENet, puerto 7777) y online. Mantiene `players` (id → nombre y color) y el arranque de la partida con semilla compartida.
  - `game/scripts/net/eos_net.gd` (autoload `EosNet`): login Device ID, sala de hasta 4 con código de 5 caracteres y `EOSGMultiplayerPeer` (socket `analog`). Falta RTC para la voz.
  - **Sincronización:** cada jugador es autoridad de su cuerpo (`net_pos`, `net_yaw`, `net_pitch`, `net_raise`, `net_light`, `net_filming` por `MultiplayerSynchronizer`, a 30 Hz con interpolación). El anfitrión es autoridad de la Visita (`net_pos`, `state`, `pose`, `tapes`) y de la tele (`state`, `watched`). Los eventos (recoger, despertar, captura, final) van por RPC desde `Run`.
  - Los nodos sincronizados tienen el mismo nombre en todas las máquinas: `P<id>`, `Entity`, `Level/TV`; las cintas, `Tape<n>` / `Battery<n>`.
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
