# Contexto del proyecto: Lost Signal - Analog Horror

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

**Nombres (decisión del usuario, 2026-10-26):**
- El juego se llama **Lost Signal - Analog Horror** (antes «Señal Perdida»; renombrado el 2026-10-25 en todas partes: ventana, menú, splash, exe `LostSignal.exe`, `project.godot`, export). La página de itch.io es `nearq.itch.io/lost-signal` (antes `seal-perdida`; el canal `windows` y su historial se conservan).
- El programa infantil se titula **«¡Te estoy viendo!»**, y es la frase de Vecinito. En el programa es un juego del escondite; en la casa, una amenaza, y es justo lo que hace la cámara con él. Sustituye a «¡Hola, Vecinitos!», que al usuario le sonaba artificial.
- La voz de la Visita dice «¡te estoy viendo!» o, pegada a ti, susurra algo que no se entiende (tres voces balbuceando sílabas, una al revés, con chasquidos de boca). Lo que no se entiende da más miedo (decisión del usuario 2026-10-26). Las reglas de la alerta la mencionan («si oye "te estoy viendo", no se detenga»).

## Concepto (decidido por el usuario el 2026-10-25)

Fusión de las tres direcciones propuestas: **«Solo la cámara la ve»** + **la mascota de una cinta infantil perdida** + **la alerta de emergencia que miente**.

- **El mundo:** 14 de octubre de 1989. Tras «la emisión del 14 de octubre», el Canal 9 local emitió por error un episodio de *¡Te estoy viendo!*, un programa infantil que nunca debió salir al aire. Después de esa noche, el barrio fue evacuado. Las televisiones siguen encendidas con un aviso de emergencia.
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
  6. **Despierta cuando la alerta interrumpe el programa** (decisión del usuario, 2026-10-25). La tele del salón está emitiendo *¡Te estoy viendo!* con Vecinito en su **forma normal**: un osito mostaza simpático que saluda en un plató soleado. Con [E] lo ves a pantalla completa. Si sigues mirando, a los 2,5 s el programa empieza a estropearse durante 5 s: Vecinito deja de saludar y te mira fijo, se le vacían los ojos, se le cae la mandíbula, el color se apaga, la cinta se ralentiza y al final solo queda su cara. Después la señal se corta con estática y sale sola la alerta con las reglas. **La Visita despierta cuando dejas de leer la alerta** (o a los 20 s de leerla), para que dé tiempo a leer las reglas. Hasta entonces la casa está en silencio. Si nadie mira la tele, la alerta salta sola a los 120 s. **Escala con cada cinta**: más rápida, la sintonía más desafinada.
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
  - **Ventanas reales (2026-11-20):** cada `W` es un hueco de verdad en la pared (se ve 0,3 m de muro, `HouseWindow.REVEAL`) con ventana de guillotina dos sobre dos: marco pintado y desconchado, vidrio sucio, alféizar, jambas, cortinas de tela con pliegues (una de cada tres rota) y, bajo la mitad, un radiador. Detrás del vidrio se ve la noche: fachada, césped, valla, árboles y la casa del vecino con una ventana encendida (`Level._build_outside`, una malla sin luz a 9 m). **E abre/cierra la hoja de abajo** (`HouseWindow`, el anfitrión decide por `Run._request_window`, igual que las puertas): suena a madera que se arrastra, la Visita lo oye, y abierta entra corriente (sonido de viento, las cortinas se levantan). Nadie sale por ella: el hueco está bloqueado. Lo fijo (marco, hoja de arriba, molduras) va en la malla de la casa; lo que se mueve (hoja de abajo, cortinas) es un nodo por ventana sin sombra. Además, zócalos y cornisas en 3D en todas las paredes. Smoke: `windows: ...`. Fotos: `--shots <dir> --house-only`.
  - Muebles con forma: sofá con respaldo y brazos, camas con cabecero y almohada, mesas con patas, encimeras.
  - Marcos de puerta, alfombra, cajas de mudanza, papeles por el suelo, fotos familiares con las caras rayadas, dibujos infantiles de Vecinito (uno tachado en negro).
  - Polvo en el aire que solo se ve en la luz de la linterna, y un grano de película leve también a simple vista.
  - Desde el 2026-10-26 la casa es procedural (ver «Casa procedural»): el papel pintado, los suelos, los muebles y los dibujos dependen del tipo de habitación, y la decoración menuda sale de la semilla de la partida.
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
- **Hollín de la Visita (2026-11-20, `EntitySoot`):** lo que queda de la cinta quemada de la que salió.
  - **Aura (solo por la cámara, capa visual 2):** humo de hollín que sale de la cabeza, la espalda y cada articulación de los brazos y piernas del muñeco 3D (`EntityModel.soot_points`), copos negros que caen y una mancha de sombra en el suelo bajo ella (en el techo si está colgada). Mientras la graban, el humo se queda casi quieto. Furiosa, echa más. `GPUParticles3D` + `shaders/entity_soot.gdshader` (ruido que se deshace en jirones, suave contra paredes y suelo).
  - **Huellas (también a simple vista, propuesta, `Tuning.SOOT_NAKED_EYE`):** pies largos de dedos con garra; a gatas, manos enormes; y una salpicadura quemada donde el flash la deshace. Aparecen `SOOT_SETTLE` (1,4 s) después de pasar, nunca donde está ahora, y se borran en `SOOT_LIFE` (50 s). Un fondo de decals reutilizados (`SOOT_MARKS`).
  - **Red:** solo presentación, cada máquina la deriva de lo que ya se replica (posición, estado, pose, modo); nada nuevo por la red.
  - **Coste:** los decals no son llamadas de dibujo; el aura son ~7-12 llamadas solo con la cámara levantada. El filtro de decals se pone en código (`RenderingServer.decals_set_filter`, nearest) y no en `project.godot`, para poder publicarlo como parche.
  - Texturas: `python tools/gen_soot.py` (requiere scipy). Capturas: `--shots <dir> --soot-only`.

## Sonido y música

- El audio es la mitad del terror: zumbido, estática, tono de emergencia, pasos, el silencio de una casa vacía.
- **Sonido analógico de verdad** (referencia: Mandela Catalogue, Local 58): todo lo de la Visita suena a material infantil reproducido desde una cinta que se muere. Lleva:
  - variaciones de velocidad (wow y flutter) y frenadas que hunden el tono;
  - cortes de señal (dropouts), saturación, siseo de cinta y graves apagados;
  - una voz de presentador sintetizada por formantes, grave y doblada una octava por debajo.
- **La sintonía de ¡Te estoy viendo!** (órgano de juguete con un último compás que se tuerce) es la firma sonora de la Visita: indica que está cerca y se calla cuando la graban. Además suenan su voz («hola, vecinito»), un dron, al pillarla en cámara la sintonía se frena y muere como una cinta parada a mano (nada de silbidos: sonaban graciosos) y el grito de la captura.
- **Chat de voz por proximidad** como pieza central del cooperativo.
- Un susto sonoro solo en la captura.
- Todo el audio debe ser apto para streaming. Los placeholders actuales son síntesis propia: `tools/gen_audio.py` (ambiente e interfaz) y `tools/gen_entity_audio.py` (la Visita).

## Interfaz e interacciones

- HUD mínimo: un punto de mira, el aviso de interacción y mensajes breves. Todo lo demás es diegético (visor, televisión).
- Controles: WASD, ratón, **clic derecho mantenido = cámara**, F linterna, E usar, R recargar batería, Shift correr, C agacharse, F3 datos de rendimiento, F11 pantalla completa, R reintentar al final.
- Las pantallas de intro y de final forman parte de la ficción (tarjeta de fecha, «SIN SEÑAL», «CINTA RECUPERADA»).

## Lore

- El mundo tiene **respuestas definidas aunque el jugador solo vea fragmentos**. Mantenerlas en `.agents/lore.md` (por crear) antes de esparcir pistas: qué es la Visita, quién hizo el programa, qué pasó el 14 de octubre.
- Pistas consistentes entre partidas y actualizaciones para teorías de comunidad y ARG.

## Alcance actual

- **Primera versión jugable online (2026-10-25):** de 1 a 4 jugadores, en solo, en red local (para desarrollo) o online con Epic.
  - Una casa generada para cada noche, linterna, videocámara con batería, la Visita con sus reglas, las cintas que elija el anfitrión (de 5 a 12, siempre aparece una de más), pilas, la tele (programa → se estropea → alerta → se corrompe a la tercera cinta), salida por la puerta principal.
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
  - **Agacharse con C** (alterna; no te levantas si hay algo encima). Las puertas tapiadas con tablones desde 1 m (`U` en el mapa; el generador pone 1, o 2 desde 9 cintas, solo donde hay otro camino) obligan a pasar agachado. Los demás ven tu cuerpo agachado (muslos y espinillas).
  - **Salida clara:** lámpara encima, cartel rojo de «SALIDA», luz por debajo de la puerta y los faros de la furgoneta por la ventanita. Con la cuota, los faros se encienden del todo y la furgoneta pita.
  - **Las cintas aparecen al despertar la Visita** (no antes) y suenan rebobinándose: se encuentran de oído.
  - **Manos en primera persona** más bajas, pegadas al cuerpo y abiertas a los lados; la linterna tiene un modelo nuevo (goma con anillos, bisel cromado).
- **Ajustes del 2026-10-26:**
  - **Apagón a la segunda cinta:** se apagan todas las lámparas y la tele; solo queda la lámpara de la salida (otro circuito). A partir de ahí se ve con la linterna, la cámara y las luces de los compañeros. La tele se vuelve a encender sola con la alerta corrupta a la tercera cinta.
  - **Batería al doble de gasto:** 2,8 %/s, unos 36 s de grabación con la batería llena.
  - **Sin abusar de la cámara:** tras bajarla hay 0,7 s antes de poder subirla. La Visita solo cambia de pose si llevaba más de 0,6 s sin que la grabaran, y el golpe de cinta suena como mucho cada 3 s.
  - **Tele:** el último fotograma del programa estropeado se dibuja otra vez con zoom a resolución completa, y la boca abierta queda dentro del hocico.
- **Final de la noche (2026-10-26):**
  - **Bajo los tablones, a gatas:** la Visita pasa por las puertas tapiadas como una araña, con codos y rodillas por encima del cuerpo y la cabeza colgando del revés (pose `CRAWL`).
  - **La quinta cinta la enfurece:** grita por toda la casa (interferencia en todas las pantallas), se vuelve más grande y roja, nunca está quieta y su canción se acelera. La cámara parece funcionar, pero solo la sujeta 1,2 s; después se suelta, aunque la sigas grabando, con un chasquido de cinta, y persigue un 20 % más rápido.
  - **Con que salga uno, se gana.**
  - **Pantalla de victoria:** la cinta recuperada se reproduce en una tele (con algún fotograma que no debería estar), el informe se escribe solo, «Las copias serán destruidas» se corrompe en «emitidas» y aparece «GRACIAS POR JUGAR LA DEMO» con la música de cierre.
- **Ayudas en solitario (2026-10-26):** con un solo jugador, la batería dura el doble, la Visita va un 10 % más lenta y E recoge la cinta o la pila que tengas al lado (a 1,4 m) aunque no la mires. Además, el extremo este del pasillo se abre al baño (puerta nueva), así que ya no hay callejones sin salida.
- **Cooperativo completo (2026-10-26):**
  - **Cámaras escasas:** una cada dos jugadores (1 para 1–2, 2 para 3–4), repartidas en orden de entrada. Con **G** se suelta delante (para pasarla) y con **E** se recoge; conserva su batería. Las pilas solo se pueden coger llevando cámara. Quien no lleva cámara no puede ver a la Visita y depende de los demás.
  - **Muerte de un compañero vista desde fuera:** cuerpo levantado del suelo y sacudido por algo invisible (si no lo grabas), luego estampado contra el suelo a los pies de la Visita, donde queda el cadáver (ver «La Visita juega»). Suena un grito real y crudo, y ropa y huesos rompiéndose, en 3D. Su cámara cae al suelo grabando (luz roja) y se puede recoger.
  - **Voz por proximidad** (`scripts/net/voice_chat.gd`):
    - **Rehecha el 2026-10-25** (se oía mal: entrecortada y con saltos).
    - **Captura:** el micro se lee directamente del servidor de audio (`AudioServer.set_input_device_active` / `get_input_frames`, a la frecuencia real del dispositivo; si falla, el método antiguo de bus con `AudioEffectCapture`). Filtro anti-alias de 4.º orden a 7,2 kHz, remuestreo por interpolación a 16 kHz y paso alto a 110 Hz.
    - **Envío:** tramas de 20 ms (50 por segundo, 322 bytes). Detección de voz con suelo de ruido adaptativo y **pre-roll** (manda las 3 tramas anteriores al abrirse, para no comerse el principio de las palabras) y fundidos al abrir y cerrar; o pulsar V. Ganancia automática lenta (hasta ×6, sin bombeo) y limitador suave. Mu-law, sin fiabilidad, numeradas.
    - **Recepción con búfer de jitter por persona:** espera ~60 ms de voz al empezar cada ráfaga, alimenta el sonido 3D a ritmo constante (mantiene 100 ms en cola), reordena paquetes desordenados, rellena un paquete perdido repitiendo el último más bajo (hasta 3) y, si se acumulan más de 240 ms, salta a lo último (nunca reproduce lo que se dijo hace segundos).
    - **Reproducción:** voz en 3D desde la cabeza (distancia inversa, `unit_size` 3,5, hasta 24 m, paneo al 80 % para no cansar con auriculares, sin Doppler); tras paredes se ahoga (filtro a 900 Hz) y baja 6 dB. Bus "Voice" con compresor suave y muy poca reverberación.
    - **Elegir micrófono:** en Opciones (menú y pausa), botón «ENTRADA/MICRÓFONO: …» que recorre los dispositivos del sistema (`Settings.mic_device`, guardado). En el menú, una barra muestra el nivel del micro al hablar.
    - **Medidor en el HUD (2026-10-25):** abajo en el centro, siempre, también en solitario (desde el 2026-10-25 el micro se abre también jugando solo: nadie te oye, pero la Visita sí): «MIC», barra con tu volumen y una marca donde se abre la detección de voz. Gris si no sale nada; ámbar si transmites; **rojo «TE OYE»** si transmites y la Visita está a ≤ `HEAR_VOICE` (9) pasos por la casa; **«¡TE ENCUENTRA!»** si además estás escondido y a ≤ 4 pasos (eso delata el escondite). «MIC APAGADO» o «[V]» según el modo. `hud.gd` `_draw_mic`, `VoiceChat.mic_level` / `gate_level()`.
    - **Pruebas:** el smoke comprueba el remuestreo (440 Hz limpio, los 12 kHz eliminados), mu-law y el búfer de jitter.
    - **Muertos:** los atrapados solo se oyen entre espectadores.
    - **La Visita oye las voces:** va a por quien habló en el último segundo y medio como si estuviera más cerca.
    - Las salas de voz de Epic (RTC) solo permiten cambiar el volumen de cada participante, sin posición 3D ni oclusión; por eso la voz va por el P2P de Epic y se espacializa en Godot.
- **Tercer jugador sin cuerpo (2026-10-25):** online, un tercer jugador aparecía para los demás pero en su pantalla veía la cámara del anfitrión sin poder moverse (no tenía su propio cuerpo: no estaba en la lista de jugadores al empezar). En LAN con 3 funciona. Ahora: el anfitrión no empieza hasta que cada invitado confirma que está en la lista (`Net._ack`, máx. 4 s, reenviándola); si a un invitado le llega el inicio sin estar en ella, la pide de nuevo (`_resync`) y espera; y si aun así no tiene cuerpo, vuelve al menú con un aviso en vez de quedarse congelado. Cada máquina escribe lo que ve de la sesión en `user://net_log.txt` (en Windows `%APPDATA%\Godot\app_userdata\Lost Signal - Analog Horror\net_log.txt`). Dev: `--net-test host --net-players 3` + dos `--net-test client`.
- **Falta para el cooperativo completo:** probar una sesión online real con varias personas (voz incluida) y ajustar el juego en grupo.
- **Casa procedural (2026-10-26)** (`scripts/world/house_generator.gd` → `HouseLayout` → `Level`):
  - **Cintas configurables:** el anfitrión (o el jugador en solo) elige de 5 a 12 en el menú (clic: más; clic derecho: menos). Viajan con la semilla en `Net._start`. Dev: `--tapes N`.
  - **La casa crece con las cintas:** 5 → unas 170 casillas transitables en una planta (22×14); 6 → ~200; desde 8, **dos plantas** (máximo) con escalera; 12 → ~400 casillas.
  - **Estructura:** un pasillo de fachada a lo ancho con la puerta principal (salida y punto de inicio) y habitaciones por partición binaria (BSP) detrás. Las puertas forman un árbol que conecta todo, con lazos extra y una segunda puerta para cualquier habitación con una sola: no hay callejones sin salida. La escalera es un tramo de 5 casillas en el pasillo, con barandilla y hueco arriba.
  - **Habitaciones por tipo:** salón (siempre con la tele, sofá y alfombra; nunca cambia), cocina (encimera, nevera, mesa, baldosa), baño (el cuarto más pequeño, bañera y lavabo, baldosa), cuarto infantil (dibujos de Vecinito), dormitorios, y desde el 2026-11-04 las temáticas (despacho, lavadero, cuarto de juegos, costura, despensa, comedor, trastero; ver «Feedback de jugadores»). Cada habitación tiene su lámpara (algunas fundidas) y las fachadas, ventanas con luz de luna.
  - **Colocación segura:** cintas y pilas solo en casillas libres de suelo alcanzables desde la entrada, a 6 pasos o más de ella, sin tapar puertas, preferiblemente pegadas a pared o mueble, repartidas por habitaciones. La Visita empieza en la casilla más lejana (arriba si hay dos plantas). Las cámaras que se sueltan caen siempre sobre suelo libre (`Run._floor_spot`).
  - **Validación:** cada casa se comprueba antes de construirse (todo alcanzable, una salida, una tele, cintas suficientes); si falla, se prueba otra (hasta 40). La prueba `--smoke` genera 100 casas de todos los tamaños y comprueba además, en la casa construida, que ninguna cinta o pila toque paredes o muebles.
- **La Visita no sabe dónde estás (2026-10-26)** (`entity.gd` y `director.gd`; todo en el anfitrión, se replica `mode`):
  - **Sentidos:**
    - **Vista:** un rayo libre desde sus ojos, unos 140° por delante (por cualquier lado a menos de 2,5 m). Te ve a 14 m con la linterna encendida, a 6 m sin ella y a un 60 % agachado.
    - **Oído:** se mide en pasos por la casa (el sonido va por pasillos y puertas, no atraviesa paredes). Correr se oye a 11 pasos, andar a 4,5, agachado a 1,2, hablar por el micro a 9, recoger una cinta o una pila a 7, soltar o recoger la cámara a 4.
    - **Grabarla:** mientras la grabas no se mueve, pero al soltarla sabe dónde estaba quien la grababa (si estaba escondido, solo la zona).
  - **Memoria:** lo que percibe es una pista (dónde, cómo de segura, cuándo) que vale 12 s. Lo oído es aproximado (más impreciso cuanto más lejos).
  - **Estados:**
    - `WANDER`: no sabe nada; recorre las habitaciones que lleva más rato sin ver y se para a escuchar. A veces vuelve a por un cadáver.
    - `INVESTIGATE`: va al ruido, no a ti.
    - `SEARCH`: no encuentra a nadie allí; revisa varios puntos cerca, incluidos los escondites cercanos, durante 25 s. Mientras busca canta «¿Dónde estás?» (`voice_where`).
    - `CHASE`: te ve; grita «¡Te estoy viendo!» y va a por ti. Si te pierde 2,5 s, va hacia donde ibas y luego busca.
    - `FOLLOW`: ve a alguien solo y se pone detrás (como antes). A 4 m susurra (ininteligible).
    - `LURK`: te ve de lejos y se esconde tras una esquina cerca de ti, asomando la cabeza.
    - `AMBUSH`: espera donde vas a ir (ver director).
    - `CORPSE`: juega con los cadáveres (sigue igual).
    - Enfurecida (todas las cintas), sabe dónde está todo el que no esté escondido.
  - **El director** (`scripts/entity/director.gd`): la otra mente, la que sí sabe dónde estáis. Si la Visita lleva un rato sin acercarse a nadie (30 s, que bajan a 14 s con las últimas cintas; +6 s en solo), interviene:
    - **Emboscada (70 %):** adivina adónde va alguien (la cinta hacia la que camina o, si no, el sitio que tiene 6-10 pasos por delante) y manda a la Visita a esperar tras una esquina de ese sitio, fuera de su vista. Al acercarse, sale.
    - **Pista vaga (30 %):** «hay alguien por ahí», a 2-4 pasos de un jugador.
    - Cuando una búsqueda fracasa, a veces adivina adónde fuisteis.
  - **Nunca atrapa a través de paredes ni esquinas:** solo si estás a menos de 0,95 m, en su planta, no escondido y con línea libre en los dos sentidos. Se mueve siempre de casilla en casilla y no entra en muebles ni paredes.
  - **Lo que se oye dice lo que sabe:** la canción suena fuerte cuando persigue, lejana cuando busca y calla del todo cuando acecha, sigue o espera emboscada.
- **Esconderse (2026-10-26)** (`scripts/world/hide_spot.gd`):
  - **Dónde:** bajo las camas (ahora con patas y un hueco oscuro), bajo las mesas y dentro de los armarios. E para entrar y E para salir. La vista baja al suelo o, en el armario, se ve por la rendija de las puertas.
  - **Qué te protege:** bajo la cama o en el armario no te ve. Bajo la mesa, solo te ve desde cerca o si llevas la linterna encendida.
  - **Cuándo te encuentra:** al buscar, se agacha a mirar en los escondites cercanos. Te encuentra si te vio entrar, si hablas o si llevas la linterna encendida. Si no, pasa de largo a un palmo. Si te encuentra bajo la cama, su cara aparece a ras de suelo.
  - **Red:** el escondite se replica (`Player.net_hide` = `Hide<n>`) y los demás dejan de ver tu cuerpo.
  - **La alerta de la tele** tiene una quinta regla: «Si pregunta dónde está, no conteste». La versión corrupta dice lo contrario.
- **La tele, rehecha (2026-10-26)** (`tools/gen_tv.py`, `scripts/world/tv_show.gd`, `tv_broadcast.gd`). Referencias consultadas:
  - Local 58: la escalada de lo normal a lo incorrecto y la autoridad que acaba mintiendo.
  - Candle Cove: un programa infantil que no debería existir.
  - Gemini Home Entertainment y Mandela Catalogue: figuras demasiado quietas y caras casi correctas.
  - El asalto a la señal de Max Headroom (Chicago, 1987): una máscara balanceándose delante de una chapa ondulada que gira, con un zumbido.
  - **El programa:** una cinta de un programa local de 1989. Un hombre con el disfraz de Vecinito (pelo mostaza apelmazado y sucio, ojos de plástico locos y amarillentos, sonrisa cosida, pajarita de fieltro, guantes blancos) en un plató que es este mismo salón (el papel pintado y el sofá de la casa).
    - Juega al cucú-tras con los niños y luego al escondite: «Cierra los ojos y cuenta conmigo» con carteles de números a ceras, «Quien no se haya escondido, tiempo ha tenido» y «¿Dónde estás?» buscando tras una casita de cartón.
    - Hay un instante del plató vacío con los guantes sobre el sofá.
    - Por el hueco del cuello del disfraz se ve piel. Rótulos amarillos y la mosca «9».
    - Todo grabado en VHS: desenfoque, sangrado y retraso del color, negros levantados, ruido y ruido de cambio de cabezal abajo.
  - **Cómo se estropea** (5 s mirando):
    - Se para con las manos abajo, la cabeza ladeada y las dos pupilas fijas en ti: «TE ESTOY VIENDO, <TU NOMBRE>».
    - Luego corta a **EN DIRECTO**: este salón ahora, visto desde la tele (una cámara real en la pantalla, en gris y con grano). Te ves a ti mismo, y por encima de tu hombro hay algo con dedos largos que en cada corte está más cerca. Solo existe en esa imagen (capa visual 4, `TvBroadcast.FEED_LAYER`).
    - Entre medias: el disfraz a oscuras con los ojos negros, y un primer plano de la boca cosida con un ojo humano mirando desde dentro.
    - En el directo solo suena un zumbido; al final, sale de la tele un susurro que no se entiende. Después, nieve y carta de ajuste.
  - **Alerta:** sello de Protección Civil (el triángulo azul en el disco naranja), cabecera con un cuadro rojo que parpadea, las reglas desplazándose y un rótulo inferior. La corrupta es roja, el sello tiene cara y a ratos hay un **asalto a la señal**: la cabeza rota del disfraz (le falta un ojo y tiene la boca rajada con dientes) sobre chapa que gira, con zumbido (`intrusion_buzz`).
  - El menú y la pantalla de victoria reproducen el mismo programa (`TvShow.at`).
- **Voces nuevas y monitor (2026-10-26):**
  - **Cómo se hacen las voces** (`tools/gen_entity_audio.py`, `host_voice`):
    - Síntesis por formantes: una vibración glotal o un soplo pasa por tres resonadores que se deslizan de fonema a fonema.
    - Se dobla una octava por debajo, se satura, se reduce de bits y se mete en una sala hueca.
    - Luego pasa por una cinta moribunda: lloro y trémolo, un frenazo de la cinta a mitad de palabra, cortes y siseo.
    - Las palabras están, pero la voz no es del todo de una persona.
  - **Frases y cuándo las dice:**
    - Al despertar cuenta del uno al diez (`voice_count`, cada número más lento y grave) y dice «¡Allá voy!» (`voice_ready`).
    - Al perderte: «¿Dónde te has metido?» (`voice_lost`). Al encontrarte escondido: «¡Te encontré!» (`voice_found`).
    - Merodeando, alterna «¿Dónde estás?», tararear la sintonía con la boca cerrada (`voice_hum`) y una risita de niño con garganta de algo enorme (`voice_giggle`).
    - Cuando te sigue, el susurro ininteligible.
  - **Monitor Alt+F1** (`scripts/ui/entity_monitor.gd`):
    - Diagrama de estados con el modo actual encendido y la última transición en amarillo.
    - Lo que sabe: objetivo, a quién ve, pista (vista u oída, exacta), si te vio esconderte, la paciencia del director y la distancia a ti.
    - Registro de decisiones con su motivo (`Entity.events`) y de lo que ha dicho (`Entity.sounds`), y un botón para escuchar cada sonido.
    - **Mientras está abierto eres inmortal** (`Player.net_god`, replicado; el anfitrión lo respeta en `_try_catch`, `_check_spot` y `Run._on_caught`).
    - Funciona también en la versión exportada. En un cliente solo muestra el estado replicado, porque la mente corre en el anfitrión.
- **La Visita nueva (2026-10-26)** (`tools/gen_entity_v2.py` → `entity_sheet_v2.png`, 192×336 por fotograma). La clásica de tinta (`gen_entity.py`) se conserva (`Net.entity_style`, `Entity.SHEETS`). Desde 0.4.1 el juego usa siempre la 3D y el menú ya no permite elegir.
  - **El mismo ADN:** altísima y delgada, máscara pálida con cuencas huecas y un punto de luz, la mandíbula desencajada con la boca que sigue pecho abajo, brazos de goma hasta las rodillas, dedos largos y pálidos, cuerpo negro apelmazado, pelos rasposos.
  - **Atada al programa:** la cabeza del disfraz de oso echada atrás como capucha (una oreja rota con el relleno a la vista y un ojo loco colgando de un hilo), la máscara cosida a la capucha, el pelo del disfraz ennegrecido con manchas mostaza, la pajarita roja todavía puesta, un guante blanco roto con los dedos atravesándolo y una boca con dientes abierta en el pecho.
  - **Pintada e iluminada como la tele:** pelo y fieltro, dientes húmedos y piel enferma con venas. Conserva un contorno de tinta irregular y grano.
  - Cada pose se dibuja tres veces (respira, se crispa, el pelo se mueve), así que sigue «hirviendo».
- **Ajustes de voz y comportamiento (2026-10-26):**
  - **«¿Dónde estás?»**, rehecho y más perturbador, en tres versiones:
    - Tres voces: el presentador, una octava abajo, y un tono de niño en una garganta enorme.
    - Eco invertido que inspira antes de la frase, un anillo metálico debajo, más destrozado, y el final hundiéndose como una cinta que se para.
    - Lo dice mucho menos (45-75 s merodeando, 22-34 s buscando) y nunca la misma versión dos veces seguidas.
    - La mitad de las veces **lanza la voz**: suena en una habitación a 6-12 pasos de donde está de verdad (`Entity._speak`).
  - **Fuera el susurro** (daba vergüenza ajena):
    - Cuando te sigue no dice nada.
    - En el directo de la tele suena «¡Te estoy viendo!» al revés y ralentizado (`voice_reverse`).
  - **Se esconde más:**
    - Si oye a alguien cerca, la mitad de las veces no sale a buscarlo: se esconde en su camino y espera (`_hide_from_noise`).
    - Si te ve de lejos, suele esconderse antes que cargar.
    - El director interviene antes (22 s de paciencia, 12 s con las últimas cintas).
  - **Desde el techo:** las emboscadas y escondites pueden ser en el techo, sobre una puerta o un punto por el que vas a pasar, 2-4 pasos antes de tu destino (`_pick_ceiling`, `on_ceiling` replicado). Se dibuja colgada boca abajo con la pose a gatas invertida y se deja caer, con un golpe, cuando pasas por debajo. Arriba no puede atraparte.
  - **Monitor Alt+F1 superpuesto:** paneles pequeños y semitransparentes en las esquinas, el centro despejado y el ratón sigue siendo tuyo para jugar. Manteniendo **Alt** aparecen los botones de sonidos y se libera el ratón.
  - Los guantes del programa, cuando se tapa los ojos, se leen como manos: cuatro dedos con pliegues, pulgar, puño enrollado y costuras.
- **Más voces, más emboscadas (2026-10-26):**
  - **Dos tomas de cada sonido** de la Visita (`<nombre>.wav` y `<nombre>2.wav`, `gen_entity_audio.write_variants`). El anfitrión elige una y todos oyen la misma (`Entity._say` → `_play_line`).
  - **Nuevos sonidos:** llanto (`voice_cry`), quejidos de dolor (`voice_moan`), gruñidos de frustración (`voice_frustrated`) y un chillido (`voice_shriek`).
  - **Más perturbador:** «¡Te estoy viendo!» se entiende mucho menos y su segunda toma tartamudea como una cinta que salta. La risita ya no se corta (todas las voces acaban con eco y un desvanecido largo, `finish`).
  - **Volumen:** las voces suenan +3 dB (`Entity.VOICE_DB`); el grito de la última cinta queda aparte.
  - **Cuándo suena cada cosa:**
    - Merodeando: «¿Dónde estás?», tarareo, risita, llanto o quejido.
    - Buscando: «¿Dónde estás?», risita o llanto.
    - Al perderte: «¿Dónde te has metido?» o frustración. Si la búsqueda o la emboscada fracasan, frustración.
    - Si la grabas más de 4 s mientras merodea, al soltarla se queja.
  - **Descubierta esperando:** si la grabas mientras te espera tras una esquina o en el techo, se queda quieta mirándote (la regla se mantiene), a los 2 s chilla y, en cuanto dejas de grabar, va a por ti furiosa (8 s un 35 % más rápida).
  - **Verla mientras se mueve no te delata:** grabarla mientras merodea ya no le dice dónde estás. Solo reacciona así cuando la descubres esperándote.
  - **Emboscadas y escondites más a menudo y más vivos:**
    - Director con 16 s de paciencia (9 s al final) y menos bloqueado por la cercanía.
    - Al oírte se esconde el 70 % de las veces (antes 55 %).
    - Tras una búsqueda o emboscada fallida prepara otra el 75 % de las veces.
    - Escondida, si a los 8 s no llegas, se cambia a otra esquina o al techo más cerca de ti.
- **Menos graves, más silencio (2026-10-26, a petición del usuario):**
  - **Voces:** menos capa de octava baja, filtro paso alto a 220 Hz en todas y el quejido más agudo. Suenan finas, cercanas y raras, no retumbantes.
  - **Llanto:** de sufrimiento, lento y continuo; lamentos largos que se deslizan hacia abajo, con respiraciones lentas y sin sollozos rápidos.
  - **Chillido:** se apaga con eco en lugar de cortarse.
  - **Silencio:**
    - **Solo calla cuando acecha** (emboscada, al acecho, siguiéndote o a tu espalda) y en el silencio tras despertar (decisión del usuario 2026-10-25: antes era demasiado silenciosa). Merodeando habla cada 10-18 s (calla el 10 %); investigando cada 6-10 s; buscando cada 7-12 s; persiguiendo se ríe, gime o suelta risitas cada 4-7 s y la canción suena siempre. Fuera de persecución la canción suena 10-16 s y para 6-12 s.
    - Fuera de una persecución su canción va y viene: una frase de 8-14 s y luego 15-35 s de silencio (solo el zumbido, sus pasos y la casa).
- **Pantalla y opciones (2026-10-26):**
  - **Pantalla completa:** el juego se abre en pantalla completa (`window/size/mode=3`) y F11 la alterna en cualquier momento. Al volver a ventana, recupera 1440×810 centrada. Las ejecuciones de prueba siempre van en ventana.
  - **OPCIONES en el menú:** pantalla, volumen general, música, efectos y chat de voz (deslizadores), micrófono y aspecto de la Visita.
  - **Guardado:** autoload `Settings` (`scripts/core/settings.gd`) en `user://settings.cfg`.
  - **Buses:** `Music` (temas del menú y de la victoria), `Effects` (todo lo demás: `Sfx`, la Visita, la tele, pasos, ambiente) y `Voice` (chat de voz).
- **Cara de la Visita nueva, más perturbadora (2026-10-26):**
  - Cara más larga, la barbilla estirada y un lado más caído. Grietas como de escayola vieja y piel con brillo húmedo.
  - Cuencas amoratadas. En la izquierda, un **ojo humano** real, húmedo, inyectado en sangre y con los párpados en carne viva, que te mira desde dentro de la máscara. La derecha, más baja, es un agujero con el punto de luz y una **lágrima negra**.
  - Sin nariz, solo dos ranuras. La sonrisa desgarrada, **cosida hacia arriba hasta las orejas** como la del disfraz.
- **La Visita «nueva», rehecha desde cero (2026-10-26):** la versión del disfraz iluminado en 3D no gustó (parecía un zombi). La nueva (`tools/gen_entity_v2.py`) parte de lo que tienen en común las figuras de terror analógico que eligió el usuario (marioneta de stop-motion, Mandela Catalogue, máscara roja con dientes, dibujo a tinta):
  - **Plana y recortada**, como un recorte de papel sobre fotos, sin iluminación 3D.
  - **Silueta negra:** cuello largo y fino, cuerpo hecho más de pelo que de cuerpo con hilos y púas negras en los bordes, extremidades larguísimas y **manos negras más grandes que la cabeza**.
  - **La máscara:** pequeña y pálida, de escayola moteada, con una arista de nariz y dos bultitos de oreja (lo que queda del oso). Lleva **ojos de dibujo animado pintados**, demasiado separados, uno más grande y los dos mirándote, y una **sonrisa pintada fina y demasiado ancha**. Pelo negro largo alrededor.
  - **Al lanzarse**, la máscara cede: se enrojece y agrieta, los ojos se vuelven agujeros desgarrados que gotean con un punto de luz, y la boca se abre en un agujero negro con dientes pequeños apiñados que sigue cuerpo abajo.
  - **Agachada ya no está en cuclillas como un gorila:** se dobla por la cintura con las piernas rectas y el cuello colgando.
  - La clásica de tinta sigue disponible en Opciones.
  - **Fuera los chillidos:** al descubrirla esperando grita «¡Te estoy viendo!».
- **Tras la primera partida online (2026-10-26):**
  - **Pausa (Esc):** continuar, opciones (pantalla y volúmenes), menú principal o salir (`scripts/ui/pause_menu.gd`). Jugando solo o como anfitrión pausa la partida para todos (`Run._set_paused`), y los demás ven «EL ANFITRIÓN HA PAUSADO LA PARTIDA». El menú de un invitado no detiene el juego. Red, Epic y voz siguen funcionando durante la pausa.
  - **Casa de dos plantas arreglada:**
    - Faltaba la pared sobre cada puerta (entre el dintel y el techo): por ese hueco se veía la planta de arriba.
    - La rampa de la escalera ahora pasa por el borde de cada peldaño (y empieza un peldaño antes), así que ya no te traba ningún escalón.
    - La Visita en la escalera sabe en qué extremo está (`Level.stair_end_near`) y ya no se queda atascada al bajar.
    - Prueba `--smoke` nueva: subir la escalera andando.
  - **Salto (Espacio):** un saltito (`Tuning.JUMP_VELOCITY`).
  - **Caras de los jugadores:** cara de píxel en el avatar (preocupada; aterrorizada con la boca abierta y sudor cuando la Visita está cerca o al morir), con tres variaciones por jugador. También se ve en el directo de la tele.
  - **Voz:**
    - Ganancia automática (sube los micros flojos hasta 10x, con recorte suave) y +6 dB al reproducirla.
    - **Ya no llega con retraso:** viajaba por un canal que Epic hacía fiable, así que se acumulaba y sonaba lo dicho minutos antes. Ahora es no fiable con numeración propia (descarta lo viejo), y si se acumulan más de 0,15 s se vacía.
  - **Destello al grabarla:** ya no enseña otro dibujo (parecía la antigua). Es un desgarro de la imagen: se estira y se desplaza un instante.
  - **Dormida no está:** antes de que mires la tele no se dibuja ni con la cámara.
  - **Cámara para todos en cooperativo** (por ahora, `Tuning.SCARCE_CAMERAS = false`).
  - **Emboscadas mucho más frecuentes:** director con 9 s de paciencia (5 s al final) y solo frenado si alguien está a 3 pasos; al oírte se esconde el 85 % de las veces; la mitad de las emboscadas son en el techo.
  - **Camina por el techo:** el 30 % de los tramos que merodea los hace por el techo (también va por el techo a su escondite del techo). Si pasas por debajo, se deja caer.
  - **Cara y cuerpo más inquietantes:**
    - Expresiones por pose: sonrisa pintada que se ensancha entre fotogramas, «^ ^» feliz con una sonrisa llena de dientes humanos, mueca con dientes, ojos enormes con pupilas diminutas y boca en «o», y tristeza con cejas pintadas.
    - **Valle inquietante:** iris humanos reales y húmedos dentro de los ojos de dibujo.
    - **Cuerpo deforme:** un hombro caído, un segundo codo doblado al revés en cada brazo, costillas de más bajo el pelo y un bracito extra plegado contra el pecho con una manita pálida.
- **Bots de prueba (2026-10-26):** en el monitor Alt+F1, manteniendo Alt, el botón **+ BOT** añade un compañero controlado por el anfitrión (`scripts/dev/bot.gd`, `Run.spawn_bot`). Recorre la casa: la mitad de las veces va cerca de ti y la otra mitad por su cuenta, así que la Visita puede seguirlo, atraparlo o jugar con su cuerpo. Solo existe en la máquina del anfitrión (sin replicar) y no tiene cámara.
- **El equipo, rehecho (2026-10-26):** los jugadores ya no son cubos. Son las cuatro personas que mandó Canal 9 (`tools/gen_crew.py` → `crew_heads.png`, `crew_patch.png`; `PlayerAvatar.person()` según el color):
  - **Operador** (naranja, gorro de lana, barba de días, ojeras).
  - **Técnica de sonido** (verde azulado, coleta, gafas redondas, cascos al cuello).
  - **Reportero** (rojo, raya al lado, bigote, pecas).
  - **Becario** (amarillo, gorra hacia atrás, pelo rizado, ojos grandes y nerviosos).
  - **Cuerpo:** piezas redondeadas de pocos polígonos, chaqueta del equipo con franja reflectante, parche CANAL 9 a la espalda, batería con piloto naranja, vaqueros y botas con suela.
  - **Cabeza:** una esfera con la cara pintada.
  - **Expresiones:** preocupada; aterrorizada (boca abierta, sudor) si la Visita está cerca o al morir; parpadea cada pocos segundos; y mueve la boca mientras hablan por el micro (`Player.talking`, lo marca `VoiceChat`). Los cadáveres conservan la cara de terror.
- **El equipo, más bajo y natural:** cuerpo al 90 % (`PlayerAvatar.SIZE`), ojo de la cámara a 1,5 m y colisión de 1,62 m. Torso más fino con hombros, cuello hundido en el cuello alto y la cabeza (más redonda) apoyada en él. Codos doblados en los dos brazos: la linterna se lleva delante con el codo flexionado, no con el brazo estirado.
- **Pausa centrada** en la pantalla, con las opciones debajo.
- **Tele y red, retoques (2026-10-26):**
  - **Guantes del osito de verdad:** apuntan hacia donde va el antebrazo, el puño se traga el final de la manga y los dedos se abren hacia delante, con el pulgar hacia la cara. Al taparse los ojos, cada guante cubre un ojo, con los codos bajos y hacia fuera.
  - **La escena del cartón (fea) sustituida:** Vecinito escondido detrás del sofá del plató, con solo la cabeza y los ojos asomando por encima del respaldo y los guantes agarrados al borde, mirando a un lado y a otro («¿DÓNDE ESTÁS?»). El sofá ahora tiene asiento y faldón hasta el suelo.
  - **Retraso de la cámara en cooperativo, corregido:**
    - Espera tras bajarla de 0,7 a 0,35 s.
    - Un invitado ve a la Visita quedarse quieta en cuanto la encuadra, sin esperar la confirmación del anfitrión (`Entity._physics_process`).
    - El anfitrión decide si la grabas con la última vista que enviaste (posición, giro e inclinación), no con la copia suavizada que va con retraso (`Entity._view_of` / `_in_frame`).
    - La voz va en paquetes de 40 ms (la mitad de paquetes).
- **NUEVA MECÁNICA: el flash (2026-10-26, decisión del usuario).**
  - **La cámara ya no congela a la Visita:** solo la muestra. Si la grabas, sigue con lo suyo.
  - **El flash:** clic izquierdo mientras grabas (`Camcorder.flash_fired`; 12 % de batería y 3 s de recarga, con el indicador FLASH en el visor). Destello blanco para todos y pantalla en blanco para quien dispara.
  - **Lo decide el anfitrión** con la última vista enviada (`Run._judge_flash`, `Entity.flash_hits`, alcance de 12 m y línea libre).
  - **Si la alcanza:**
    - Grito de agonía en su propia voz rota (`voice_agony`, dos tomas).
    - Huye a cuatro patas (`Mode.FLEE`, 2,3 veces más rápida) a un sitio lejos de quien disparó y fuera de su vista.
    - Se esconde en silencio 6-12 s.
  - **Vuelve con otra estrategia** (`Entity._comeback`):
    - Por el otro lado (`_flank`: una esquina cerca de ti en el lado opuesto al de su último ataque).
    - Por el techo sobre adonde vas.
    - Siguiéndote en silencio por detrás.
    - A por otro jugador.
  - **Enfurecida:** el flash solo la aturde 1,2 s. Tras cada flash es inmune 1,5 s.
  - **Descubierta esperando:** se queda quieta mirándote; a los 2 s grita «¡Te estoy viendo!» y carga.
- **Animación de la Visita nueva:** caminar en 4 pasos (zancada rígida, brazos que se balancean mal) y **correr a cuatro patas** en 4 zancadas (baja, codos y rodillas abiertos, la máscara entre los hombros, sonriendo). Persigue a cuatro patas (`GALLOP_SPEED_MULT`) y huye del flash igual. Los fotogramas avanzan según la distancia recorrida. La hoja tiene 4 columnas y 9 filas; la clásica usa sus poses de siempre.
- **Regla de la tele cambiada:** «2. El flash de la cámara la ahuyenta».
- **Voces de la Visita** un 22 % más largas (no los gritos) y +7 dB.
- **Jugadores cabezones:** cuerpo al 84 % y cabeza de 0,18 m de radio. Los ojos, iris, párpados, cejas, boca y gafas son piezas separadas sobre la cabeza (`PlayerAvatar._build_face`):
  - Las cejas se arquean con el miedo, los ojos se agrandan y las pupilas se encogen.
  - Miran a un lado y a otro y parpadean.
  - **La boca se abre según el volumen con que hablan por el micro** (`Player.voice_level`, que calcula `VoiceChat`).
- **Dedos del osito** más finos, con nudillo y punta.
- **Iluminación:**
  - Cada tipo de habitación tiene su luz: ámbar en el salón, fluorescente frío que tartamudea en la cocina y el baño, rojiza tenue en los dormitorios, amarilla enfermiza en el pasillo y bombilla desnuda en el trastero.
  - Cada lámpara proyecta un cono hacia el suelo que se ve en la niebla, con rincones más oscuros.
  - Ambiente más oscuro, niebla más cálida, algo más de contraste y menos saturación.
- **Más ajustes (2026-10-26):**
  - **Copiar el código de la sala:** botón COPIAR junto al código, al portapapeles.
  - **El nombre se guarda** en `user://settings.cfg` (`Settings.player_name`).
  - **Nunca prepara un escondite a menos de 3,5 m de nadie** (`HIDE_MIN_DIST`, `Entity._too_close`).
  - **Screamer nuevo:**
    - Sonido `caught` rehecho: golpe que satura, su voz gritando la frase del programa al objetivo, la sintonía desbocada, la cinta rasgándose y parándose.
    - En pantalla: su cara alternando con su cara más cerca a golpes (`Entity.screamer`), sacudida de cámara, zoom de lente (`Camcorder.fov_kick`) y cortes rojos y negros (`Viewfinder`).
  - **Linterna:**
    - Al grabar sale de la cámara, centrada en la imagen (antes salía de la mano y se cortaba abajo a la derecha).
    - Haz central más brillante y estrecho, con un halo amplio y suave alrededor.
  - **Flash:**
    - La Visita se pone roja, se da la vuelta (se ve de espaldas y más oscura mientras huye) y huye mucho más rápido (`FLEE_SPEED_MULT` 3,6).
    - El grito de agonía empieza con su voz grave y salta de golpe a un **grito agudo, casi femenino**, que se quiebra.
  - **Más silencio:**
    - Voces a +4 dB.
    - Menos pasos al galopar y pasos más suaves.
    - La canción suena 6-10 s y calla 25-45 s, también persiguiendo.
    - Merodeando calla el 55 % de las veces.
  - **Descubierta esperando:** a los 2 s suelta un **rugido hambriento y desesperado** (`voice_hunger`, sin palabras) y sale disparada: 1,5 s muy rápida (`BURST_SPEED_MULT` 2,4) y luego furiosa.
  - **SIGILO** (`Mode.STALK`):
    - Si te ve de espaldas, se acerca en silencio y muy rápida hasta ponerse justo detrás de ti y te dice «te estoy viendo» al oído.
    - Mientras te acecha así solo se oye **su respiración en tu nuca** (`neck_breath`, bucle 3D a menos de 5 m, más fuerte cuanto más cerca; decisión del usuario 2026-10-25).
- **Volumen (2026-10-25):** todo lo que suena de la entidad va +4 dB (`Entity.LOUD`, voz `VOICE_DB` 8, tope cercano `MAX_DB` 12, porque Godot limita los AudioStreamPlayer3D a 3 dB); el screamer (sonidos de `Run` al atraparte) queda igual; el grito de furia al coger todas las cintas baja a -7 dB.
- **Con todas las cintas** la imagen de la **videocámara** no se recupera: al mirar por ella queda distorsionada para siempre (`post_fx.gd`, según `cam.raise`: vhs ≥ 0,6, interferencia 0,22, estática 0,12); a simple vista todo se ve normal (decisión del usuario 2026-10-25).
- **Enfurecida (2026-10-25) ya no sabe dónde estás:** antes iba directa a por el más cercano no escondido. Ahora busca más fuerte: cada 7 s (`RAGE_SNIFF_EVERY`) va a husmear a 2-4 pasos de alguien (`Director.pick`/`vague`), oye un 50 % más lejos (`RAGE_HEARING`), al buscar revisa 4 escondites en vez de 2, y si te ve persigue siempre (sin acechos). Sigue siendo más rápida.
- **Antes de sacarte de un escondite se asoma (2026-10-25):** cuando te encuentra escondido (te vio entrar, hablaste o llevabas la linterna) entra en `Mode.PEEK`: pone la cara delante de tus ojos sonriéndote (pose PEEK redibujada el 2026-10-25: cabeza ladeada, sonrisa de oreja a oreja llena de dientes, `face="beam"`, las manos agarrando el borde a los lados, lejos de la cara; antes se tapaba la cara con las manos). En armario, a ~1 m; bajo cama o mesa se mete en el hueco dibujada más pequeña (`peek_low`, ×0,55) con la barbilla en el suelo. Pasa en cualquier escondite: también si te ve bajo una mesa y llega a la abertura, suena «te encontré» y espera `PEEK_TIME` (2 s). Si la flasheas en ese tiempo (cuenta con que su cara esté en el encuadre) huye como siempre; si sales del escondite, te persigue; si no, te atrapa. Solo se ve con la cámara, como siempre.
- **Callejones sin salida con escondite (2026-10-25):** el generador deja a propósito 1 habitación con una sola puerta por planta (2 desde 9 cintas; antes ninguna) y cada habitación así tiene un armario o una cama (`_hideouts_in_dead_ends`; nunca el pasillo; esa puerta nunca se tapia). Si te acorrala allí, te escondes. El smoke lo comprueba (~2,8 por casa de media).
- **Que no campee (2026-10-25):** esperas más cortas (acecho 6-11 s, emboscada del director 14 s en vez de 30), el director embosca menos (55 % en vez de 80 %; tras una búsqueda fallida 35 % en vez de 75 %) y si lleva más de 16 s esperando últimamente (`_camp`, `CAMP_MAX`; baja a la mitad de ritmo mientras se mueve) no vuelve a esconderse a esperar: va a buscar.
- **Flash más difícil de fallar (2026-10-25):** cuenta como acierto cualquier punto del cuerpo (5 alturas × 3 posiciones laterales) y también el punto desde el que ella mira (si te ve por una puerta, el flash le llega); colgada del techo, el cuerpo cuelga desde el techo hacia abajo (antes solo se probaba un punto junto al techo y el dintel de la puerta lo tapaba). El encuadre tiene un 30 % de margen (`FLASH_SLACK`) y el alcance sube a 14 m.
    - Se queda a tu espalda mientras andas. **Si te das la vuelta y la ves, te atrapa; si no te giras en 5 s, también.**
    - Solo un flash la salva: el tuyo si eres rápido o el de un compañero.
- **Al despertar (2026-10-26):** nadie muere nada más acabar la emisión.
  - Aparece **lo más lejos posible de todos** (`_far_from_everyone`, BFS desde cada jugador) y, **cuando ya nadie está ante la tele** (1,5 s después de que el último cierre el aviso, o a los 40 s como mucho; `Entity.cry_pending`, `Run._host_tick`), suena **un único grito desgarrador lejano** (a 0 dB desde el 2026-10-26, antes +6), como si gritara «¡LIBERTAD!», grave y agónico, como si lo torturaran (`wake_cry`: voz que se quiebra, gemido de hombre debajo, llanto de mujer encima, sollozo ahogado y jadeo al final). Ya no hay cuenta atrás ni golpe al despertar.
  - «Te estoy viendo» (`voice_line`, sus dos tomas) suena **al revés**: se reconoce la melodía, no las palabras.
  - Después del grito, **10 s de silencio** (`WAKE_GRACE`, `Entity.quiet` replicado): ni canción, ni voz, ni zumbido. Solo es silencio: caza con normalidad (ve, oye, persigue); el director da su primer empujón a los 4 s.
  - Prueba `--smoke` nueva para esto.
- **Segunda noche: Canal 9 y The Husk (propuesta, pedida por el usuario 2026-11-27):** otro lugar y otra entidad, con reglas opuestas a la Visita.
  - **Lugar:** los estudios de Canal 9 de noche (`StationGenerator`, `HouseLayout.kind = "station"`): una planta, pasillo de fachada + espina, plató con el decorado del programa (sofá, alfombra, paneles con papel pintado, cámaras de estudio, parrilla de focos, «luz fantasma»), archivo de másteres, vestuario con disfraces colgados (`n`) y taquillas, control con monitores que muestran fotogramas del programa, transmisores con LEDs, oficina, camerino, sala de descanso, aseo, almacén. Fluorescentes que tartamudean; salida por el muelle de carga. Puertas sin montante (no trepa). Tablas: nunca aíslan una habitación (`_board_doors(..., "U")`).
  - **The Husk** (`Husk extends Entity`, `HuskModel`): el disfraz de Vecinito vacío (pelo mostaza, sonrisa cosida, un ojo colgando, cremallera abierta, hueco negro en el cuello). **A simple vista se ve; la cámara no** (capa visual 6, `HuskModel.NAKED_LAYER`; en el visor solo su sombra). **No se mueve mientras alguien vivo lo ve** (en su vista, sin nada en medio y con luz: <3,5 m a oscuras, en el haz de la linterna, bajo un fluorescente vivo o con el flash); grabar no es mirar y escondido no miras. Sin mirar es rápido (2,9 m/s + 0,1 por máster, ×0,88 en solo, ×1,3 con todas) y cambia de postura cada vez. **Parpadeo**: tras 5,5–8,5 s mirándolo parpadeas 0,24 s (el anfitrión lo decide, RPC al jugador). No cruza tablas, no trepa, abre puertas despacio. Ve, oye y persigue; empujón vago tras 35 s sin pistas; con todas las cintas sabe dónde estás. Duerme entre los disfraces hasta que alguien coge el primer máster (cintas U-matic desde el principio).
  - **Megafonía** (`StationNight`): campanita + voz ininteligible + subtítulo; da las reglas y, desde `TV_CORRUPT_AT` másteres, miente («Puede dejar de mirarlo…», «Grabe al muñeco…»). Sin red propia: cada máquina reacciona a los mismos eventos.
  - **Red:** el anfitrión decide todo (`net_pos`, `look`, `yaw`, `moving`, `watched` replicados); en los clientes no se mueve ni cambia de pose mientras su jugador lo ve (salvo >2 m de desfase). `Net.night` se manda con `_start`. Sin modo Visita-jugador en esta noche.
  - **Entrar:** botón «NOCHE 1 · LA CASA / NOCHE 2 · LA EMISORA» en el menú y en la sala; tras escapar de la casa, el anfitrión pulsa N. Dev: `--station` (con `--smoke` o `--shots <dir>`: `StationTest`). Sonidos: `tools/gen_husk_audio.py`; texturas: `tools/gen_station.py`.
- **Ideas aprobadas para más adelante (no hacer aún, decisión del usuario 2026-10-26):**
  - **Imitar a un compañero en el visor:** la Visita aparece dibujada con la chaqueta y el color de un compañero.
- No añadir progresión, tienda ni campaña antes de que una noche dé miedo jugándola en grupo.

## Tecnología y organización

- Motor: **Godot 4.7.2** con GDScript y Forward+ (sombras dinámicas, niebla volumétrica). Ejecutable local: `C:\Users\usuario\Desktop\Godot_v4.7.2-stable_win64.exe`. GPU de desarrollo: Intel Iris Xe (integrada; buena referencia de gama baja).
- Proyecto en `game/`; la raíz guarda documentación (`.agents/`, informes) y herramientas (`tools/`).
- **Ronda de arreglos (2026-10-26, tras jugar la 0.2.0):**
  - La barra de herramientas no sale durante el texto de inicio (solo con `input_enabled`). El inventario se abre con **TAB** (antes I); no se abre escondido.
  - Tu cuerpo: sin caderas ni pecho (se veía una masa flotando); al mirar abajo ves piernas y botas (adelanta 20 cm).
  - Puertas: sonidos rehechos como los de verdad (crujido de bisagra por "stick-slip" que resuena en la madera y el metal, el pestillo con dos clics metálicos, el golpe del panel contra el marco); **abren hacia el lado contrario de quien las abre** (`Door.swing_from`: hacia el paso o hacia la habitación); un solo marco por hueco (había dos a un metro, parecía doble puerta).
  - Camas solo individuales (`house_generator`), con el cabecero en un extremo corto (`Level._bed_head`; antes podía tocar el lado largo y la cama salía «partida»).
  - El osito mantiene «TE ESTOY VIENDO, <NOMBRE>» 2 s (antes 1; `TV_DISTURB_TIME` 6).
  - Al esconderte la linterna se apaga sola (y vuelve como estaba al salir): con ella encendida la Visita te encontraba aunque estuvieras callado. Cuando se asoma a tu escondite, **su cara se ve aunque no lleves la cámara levantada** y en el armario abre las puertas (`Camcorder.peeked`).
  - Voz de la Visita: ya no se «lanza» desde otra habitación (`VOICE_THROW_CHANCE` 0: confundía) y se atenúa antes con la distancia (`unit_size` 2,2; pasos 2,5), para saber de dónde viene. Su canción de caja de música desactivada (`ENTITY_SONG` false, el código sigue). El aire de ambiente de la casa, de -10 a -20 dB.
- **Segunda ronda (2026-10-26):**
  - Tu cuerpo justo bajo el ojo (no adelantado) y solo espinillas y botas a la vista (muslos, caderas y pecho en `SELF_LAYER`).
  - Cama sin caras coincidentes (parpadeaban): manta más corta que el piecero, piezas con tamaños distintos, cabecero y piecero un poco salientes.
  - Puertas: sonidos sutiles (un clic suave del pestillo y un soplo; al cerrar, el clic y un golpe sordo; la de la Visita, un gemido grave y bajo de bisagra). Solo abren hacia la habitación si hay sitio libre al lado de la bisagra (`Door._can_open_out`); si no, hacia el paso: nunca tapan un hueco.
  - Armario por dentro en 3D (`HideSpot.make_inside`, solo para quien se esconde): paredes, barra y dos puertas con una rendija de luz; la Visita las abre al asomarse. Sustituye al dibujo plano de la interfaz.
  - **Escondido, solo cuenta la voz de verdad:** el micro abierto captaba respiración o ruido y la Visita te «oía» y te encontraba aunque estuvieras callado. Ahora cada paquete de voz lleva su volumen real (antes de la ganancia) y, escondido, solo te delata si pasa `HIDDEN_VOICE_RAW` (el medidor solo marca «TE OYE» entonces). El director nunca da posiciones de escondidos (elige solo a gente a la vista).
  - Un armario nunca va pegado a la cama (`HouseGenerator._next_to`; 354 casas comprobadas: 0), y la manta ya no lleva el doblez que se montaba con la almohada.
  - Solo: la noche no corre mientras lees el texto de inicio (antes la Visita podía despertar y atraparte ahí). R/M en la pantalla final no hacen nada el primer 1,5 s (una tecla pulsada al acabar podía empezar otra noche).
- **Grito de persecución (2026-10-26, referencia del usuario: la «Bacteria» de los Backrooms):** `chase_scream` (3 tomas, `gen_entity_audio.chase_scream`): un chillido desgarrado de varias gargantas a la vez (una aguda que chilla, una grave que ruge), con el tono dando tirones, modulado en anillo y aplastado para que suene mal/electrónico, saltos de grabación dañada y un jadeo. Rehecho grave (centro espectral ~900 Hz frente a ~3 kHz del primero): una garganta enorme (formantes bajos) que sube forzándose, se quiebra y cae, una octava por debajo, un gruñido debajo, saturado hasta rasgarse, ráfagas con jadeos entre medias. Suena al empezar a perseguirte (en vez de «te estoy viendo») y casi siempre durante la persecución cada 4-7 s; también al descubrirla esperando. Interrumpe lo que esté diciendo.
- **Descubierta esperando:** durante los 2 s que se queda mirándote, a los 0,35 s **estira el cuello** y la cabeza viene hacia ti sonriendo (pose `STRETCH`, fila 10 de `entity_sheet_v2.png`: el cuerpo se queda abajo, cuello largo y fino, cara de oreja a oreja); al acabar grita y sale corriendo.
- **Feedback de jugadores (2026-11-04):**
  - **Volumen de la Visita:** sus sonidos más fuertes bajan (voz `VOICE_DB` 12 → 6, gritos `SCREAM_BOOST` 5 → 2: -9 dB; tope cercano `MAX_DB` 18 → 10; el golpe del cuerpo -6 dB; el screamer de la captura -5 dB; el grito de muerte y el gore -5/-3 dB; el grito de la última cinta -3 dB). El bus «Effects» lleva un limitador (`AudioEffectHardLimiter`, techo -1 dB): los picos ya no saturan.
  - **Última cinta:** en vez de un mensaje corto, un aviso grande en el centro, «¡TIENES TODAS LAS CINTAS!» / «Sal por la puerta por la que entraste» (en plural con equipo; «YOU HAVE ALL THE TAPES!» / «Get out through the door you came in by»), 6 s, y después una línea arriba hasta salir: «▶ Vuelve a la puerta de entrada» (`Run.objective`, `Hud._show_objective`). Si juegas de Visita: «¡Tienen todas las cintas! Van a la puerta de entrada».
  - **Casas más grandes y habitaciones temáticas** (`house_generator.gd`): área +40 % (`430 + 58 × (cintas − 5)`, ancho 20-36, fondo 14-24; de ~13 a ~14 habitaciones de media) y alguna habitación grande de vez en cuando. Además de las fijas (salón, cocina, baño, infantil, dormitorio), el resto sale de una bolsa por planta sin repetir hasta agotarla (`GROUND_THEMES` / `UPPER_THEMES`, `THEMES` con el tamaño mínimo de cada una), cada una pensada para jugar distinto:
    - **Despacho** (`study`, papel verde oscuro): escritorio contra la pared (escondite como la mesa), estanterías de libros en dos paredes y, si es grande, filas de estanterías exentas: pasillos para perder la línea de visión.
    - **Lavadero** (`laundry`, baldosa, tubo frío): lavadoras en fila desde una esquina con el fregadero al final, cestos.
    - **Cuarto de juegos** (`playroom`): el peluche de Vecinito, del tamaño de un niño, desplomado en un rincón (un ojo de botón; del otro cuelgan hilos), mesita para meterse debajo, alfombra, cajas de juguetes y dibujos.
    - **Cuarto de costura** (`sewing`): 2-3 maniquíes de modista por la habitación (en la cámara, a oscuras, parecen gente), mesa de costura, caja de telas.
    - **Despensa** (`pantry`): estanterías en todas las paredes que caben; suele quedar como callejón.
    - **Comedor** con aparador; **trastero** con estantería; **baño** con bañera de patas (agua gris) y lavabo; **cocina** con nevera al final de la encimera.
  - Muebles nuevos en el mapa: `h` estantería, `a` bañera, `m` nevera (en la cocina) o lavadora, `n` maniquí (el peluche en el cuarto de juegos) (`HouseLayout.FURNITURE_CHARS`; `Level._bookcase`, `_bath`, `_appliance`, `_bear`, `_dress_form`). Texturas nuevas `books`, `enamel`, `plush`, `dressform`, `wallpaper_study` (`gen_textures.py`, cada una con su semilla: `python tools/gen_textures.py books enamel …` solo genera esas).
  - **Los problemas de muebles de siempre, cerrados por regla:** un mueble que se construye en una pieza (todos menos cajas, lavadoras y maniquíes, que van casilla a casilla) solo se coloca si su grupo sigue siendo un rectángulo (`_pieces_whole`; antes un grupo en L se construía como su caja y tapaba suelo libre); las filas a lo largo de una pared nunca usan las esquinas (dos paredes no se tocan) y se cortan en las puertas (`_wall_run`); todo pasa por `_try_place` (nunca delante de una puerta, la habitación sigue cruzable); las ventanas se ponen después y solo delante de suelo. El smoke genera 100 casas y comprueba además que todos los grupos son rectángulos, que salen los 13 tipos, que casi ninguna habitación queda vacía y que cada una tiene lo que la define (la cocina su encimera, el despacho sus estanterías, el lavadero sus lavadoras…). El recorrido `--shots` hace una foto de cada tipo nuevo (`07t_*`) y del aviso de la última cinta (`62_objective`, `62b_objective_reminder`).
  - **Publicada la 0.4.3 (2026-11-04)** en itch (build #2301468) con puentes `legacy` desde 0.4.0, 0.4.1 y 0.4.2. El parche previo no salió: `release.py` comparaba `project.godot` como texto y el editor solo había reordenado sus secciones; ahora compara los ajustes (`same_project`), sin importar el orden.
  - Arreglado de paso: al acabar los mejores momentos con un jugador ya desconectado, `Replay._end_playback` daba un error de instancia liberada.
  - Rendimiento: en la vista fija del final del recorrido, 43-45 fps frente a 48 con el tamaño anterior (mismo PC, mismo día), con menos llamadas de dibujo.
- **Baterías en el inventario (2026-10-30):** recogerlas no carga la cámara: van a la bolsa (`Inventory.add_to_bag`; no pasan a las manos, `can_swap`; no hace falta llevar cámara) y **R** (acción `reload`) pone una (+45 %, se oye y la Visita lo oye; 0,9 s de bloqueo). Las de repuesto se ven como «+2» en el visor y junto a las manos en la barra. La primera vez que te quedas sin batería teniendo una de repuesto sale «[R] Recargar batería», también en el visor, hasta que la pones; una sola vez por instalación (`Settings.reload_hint_seen`). En la casa hay `2 + cintas/4 + habitaciones/5` baterías (`Tuning.ROOMS_PER_BATTERY`).
- **0.4.1 (2026-10-29):** la Visita es siempre la 3D, sin opción en el menú (decisión del usuario: `Net.entity_style` = 2 fijo y ya no se guarda; los dibujos siguen para la tele y las pantallas finales; dev: `--entity-style 0|1|2`). El monitor Alt+F1 (IA de la Visita, inmortal, bots, «> JUGADOR / > VISITA») solo existe en builds de depuración (editor) o con `--dev`. Publicada como parche 0.4.1 de la base 0.4.0 y luego como base 0.4.1 en itch (build #2248047), con puente `legacy` desde 0.4.0.
- **Página de itch.io (2026-10-29):** carpeta `itch_page/` con portada 630x500, banner, fondo, 9 capturas y 2 GIFs con la Visita 3D, `description.html` (inglés + español), `README.md` (qué va en cada campo de itch, tema, etiquetas, textos para difundir) y `preview.html`, una simulación de la página. Las imágenes salen de `tools/gen_itch_page.py` a partir de capturas con el HUD en inglés (`--shots … --lang en`).
- **Actualizaciones dentro del juego (2026-10-28, desde la base 0.4.0)** — el mismo sistema que Midgard Survivors:
  - **Base** = build completa de itch (exe + pck); su versión es `application/config/version` (0.4.0). **Parche** = un `.pck` con todo lo cambiado desde la base (`--export-patch … --patches <pck de la base>`; acumulativo: el jugador solo guarda el último), cifrado (`.bin`, `FileAccess.open_encrypted_with_pass`, clave `PATCH_KEY` en el updater) y publicado en el repo **público** https://github.com/Gon-Analista/lost-signal-updates (`manifest.json` + `patches/`); el juego lee `https://raw.githubusercontent.com/Gon-Analista/lost-signal-updates/main/manifest.json`. El código del juego sigue en el repo privado.
  - **`game/autoload/updater.gd`** (primer autoload): en `_init()` monta `user://patches/<parche>.pck` (y el puente debajo, si hay) con `ProjectSettings.load_resource_pack` antes que nada, y recarga las traducciones desde el parche (Godot las carga antes que cualquier autoload). Estado en `user://patches/state.json` (`base`, `version`, `file`, `bridge`, `seen`); si cambia la base, borra los parches viejos. Registro en `user://patches/updater.log`. En `_ready()` pide el manifest (8 s; sin conexión, nada); si hay parche más nuevo para su base abre la ventana; si el manifest es de una base más nueva sin puente, aviso con botón a itch; `broadcast` (mensaje GM) revisado cada 5 min. Desactivado en el editor, en web y con argumentos de prueba; `--update-url <url>` para probar otro manifest, `--update-auto` acepta solo.
  - **Ventana** (`game/ui/update_window.gd`, cargada por ruta): «Canal 9 · servicio técnico», ruido de cinta y cristal CRT, panel oscuro con borde ámbar; versión actual ▶ nueva, tamaño, novedades (NUEVO/MEJORA/ARREGLO) y «ACTUALIZAR AHORA / AHORA NO»; la descarga como cinta que se rebobina (▶ y barra de bloques), verifica sha256, descifra, instala y reinicia el juego.
  - **Pantalla de arranque** (`scenes/boot.tscn`, nueva escena principal): la misma tarjeta LOST SIGNAL que el splash, con cargador de cinta (▶, barra de bloques, «CARGANDO» / «BUSCANDO SEÑAL…»), ruido y saltos de tracking; carga el menú en segundo plano y espera al primer vistazo del updater (como mucho 3,5 s); si se abre la ventana, espera detrás. Con argumentos de prueba pasa directa al menú.
  - **Publicar:** `python tools/release.py full [--push]` (base: exporta, guarda `build/release/base/` y pasa la anterior a `old_bases/`; con `--push`, butler a itch, puentes `legacy` para bases viejas compatibles y manifest nuevo), `patch <ver> [--push] [--force]` (parche contra la base, cifrado, troceado si pasa de 90 MB, manifest con las notas de `tools/release_notes.json`, commit y push con git en `build/updates/`), `status`, `broadcast "<es>" ["<en>"] [--push]`. Preguntar siempre antes de publicar. git del repo de actualizaciones va con `http.sslBackend=schannel` (Avast rompe el OpenSSL de git); `full --manifest-only` publica solo el manifest de una base ya subida. **Publicada la base 0.4.0** (2026-10-28, build itch #2235622, manifest en GitHub). Probado en local (2026-10-28): build completa → parche 0.4.1 → el exe lo detectó, descargó, verificó, descifró, reinició y ejecutó el código parcheado.
- **Jugar de Visita, más (2026-10-27, tras 0.3.4):**
  - **ESPACIO te dejaba en el suelo:** al subir se apagaba la colisión del cuerpo y, con la gravedad, caía a través del suelo durante la subida (la vista acababa a ras de suelo). Ahora subiendo, bajando y en el techo el cuerpo no usa física; la prueba comprueba que la vista queda arriba.
  - **El ataque es una embestida gritando** (CLIC IZQ): 1,3 s a 5,4 m/s hacia donde miras (se puede dirigir), con su chillido; atrapa a quien alcance; después 3 s de espera; si no atrapa a nadie, frenada. **SHIFT es correr sin gritar** (4,6 m/s, pasos fuertes, con aliento); ya no grita sola al correr.
  - **Sus sonidos en sus oídos, mucho más bajos:** su voz -26 dB, pasos -16, zumbido -22, nada de lo suyo puede pasar de -8 dB aunque esté encima (`max_db`), y el golpe al caer del techo, el corazón, la respiración y sentir más bajos.
  - **Ratón tras Alt+Tab (jugando de Visita):** el cuerpo del jugador-Visita está apagado y era él quien recuperaba el ratón con un clic; ahora lo hace `EntityPilot` (un clic lo recupera, y al volver a la ventana se recupera solo).
  - **Alt+F1:** botones «> JUGADOR» y «> VISITA» (con Alt pulsado, el anfitrión): empiezan otra noche al momento como uno del equipo o como la Visita (con al menos 2 bots si no hay nadie más).
  - **Escondida:** dentro del armario ve las puertas a los lados de la rendija como el equipo (`make_inside`), la vista se cierra un poco (62°) y solo mira hacia la abertura (±0,55 rad).
- **0.3.4 (2026-10-27): reaparecía encima de ti tras el flash.** Dos causas: (1) flasheada mientras se asomaba a tu escondite, al salir del modo «asomarse» el juego la devolvía junto al escondite *después* de haberla mandado lejos (ahora el cambio de modo va primero); (2) el sitio estratégico medía la distancia en pasos por la casa (8 pasos de rodeo pueden ser el otro lado de una pared, o justo encima en el piso de arriba): ahora además tiene que estar a ≥7 m en línea recta y ≥5 m en horizontal de cada jugador.
- **Decimosexta ronda (2026-10-27, tras publicar 0.3.2):**
  - **Se quedaba parada mirándote para siempre:** en «SIGUE» (FOLLOW) se queda quieta como una estatua mientras la miras; si no dejabas de mirarla, nunca hacía nada. Ahora, mirada más de 3 s (`STARE_LIMIT`), se harta y va a por ti con arrancada. Y en general, si se queda 9 s sin llegar a ningún sitio cuando debería moverse (camino imposible, punto muerto), se deshace como con el flash y vuelve desde un sitio estratégico (`_watch_stuck`).
  - **La tele del salón, rehecha:** mueble de madera (tapa, laterales, base), frontal de plástico oscuro hundido, marco del tubo alrededor de la imagen, franja inferior con rejilla de altavoz, cuatro botones metálicos, dos ruedas con marca y la placa «VISTAVOX», la parte trasera del tubo en pirámide, patitas, antena de cuernos y un cristal que refleja las luces (`TvBroadcast._build_set`).
- **Decimoquinta ronda (2026-10-27): jugar de Visita, retocado.**
  - **Sus sonidos los hace sola**, como siempre (ya no hay botón de hablar): gritos mientras caza (cada 3,5-6 s, además del de arrancar a correr), «¿dónde estás?», tarareos, llanto, gemidos mientras anda (cada 7-14 s); nada agachada, en el techo ni escondida (`Run._pilot_voice`).
  - En su máquina sus sonidos suenan mucho más bajo (su voz -14 dB, corazón y respiración más bajos).
  - **E** en un escondite: si hay alguien, se asoma y lo atrapa como antes; **si está vacío, se esconde dentro** como un jugador (invisible, muda, no se la puede grabar ni flashear; vista desde dentro mirando afuera); E sale, CLIC IZQ sale y se lanza (`_pilot_unhide`).
  - **C** se agacha de verdad: baja la vista, va lenta y sin ruido y cabe bajo las tablas de los marcos (no se levanta debajo de ellas); para los demás se ve en la pose agachada.
  - **ESPACIO** sube al techo siempre que no esté en una escalera (antes fallaba por la casilla), con solo 0,8 s de espera entre veces.
  - **Ve menos:** menos luz propia, niebla roja desde ~6 m, el calor de los vivos hasta 10 m, «sentir» a 22 m.
  - Su pantalla no aparece hasta que se cierra el texto inicial (antes el «DUERMES…» salía encima).
- **Decimocuarta ronda (2026-10-27):**
  - **El flash la deshace (2D y 3D):** ya no sale corriendo a cuatro patas. Donde está, se pone al rojo, se estira y se aplasta parpadeando (0,75 s, `vanishing`) entre un estallido de brasas y hollín y un desgarro de estática (`_vanish_fx`), y desaparece (`gone`: invisible, muda, no se la puede grabar ni flashear, no atrapa). Mientras, el anfitrión la pone en un **sitio estratégico** (`_strategic_cell`: a 8-15 pasos del más cercano, fuera de la vista de todos, lo más cerca posible de adonde va quien la quemó) y vuelve de allí al cabo de 6-12 s (menos en grupo) con la misma vuelta de siempre (`_comeback`). Con todas las cintas el flash solo la aturde, como antes. En el modo jugador-Visita el flash la sigue cegando.
  - **Persecución:** nunca más lenta que 2,8 m/s (`CHASE_MIN_SPEED`, un poco más que andar; antes al principio iba a 2,2 y parecía que te miraba sin alcanzarte); seguirte de lejos también se acelera.
  - **Entre las tablas:** las tablas clavadas en los marcos tienen su propia capa de colisión (`LAYER_BOARDS`): los cuerpos chocan (te agachas para pasar), pero la cámara, el flash y la vista pasan por los huecos: verla entre las tablas cuenta como grabarla (también puntos bajos del cuerpo).
  - **Dos brazos más** (2D y 3D): un segundo par, más fino y corto, desde abajo de las costillas, que sigue a los otros con retraso, se crispa y a veces se dobla al revés.
  - Grito de persecución mucho más saturado (dos etapas de distorsión y más bit-crush).
  - (Después) La estática al deshacerse, mucho más baja (-12 dB; sonaba atronadora). El grito de persecución, más grave: de un rugido de ~110 Hz a un grito de ~260 Hz (antes 180→420).
- **Decimotercera ronda (2026-10-27):**
  - **Puertas con ventana:** la Visita sube al techo ya a ~2,3 m de la puerta (mira los próximos pasos de su camino, `_transom_ahead`) y sigue arriba 1,6 s después de pasarla (`CEILING_HOLD`) antes de bajar.
  - **Mejores momentos en una tele:** al acabar, una tele (la de la cinta recuperada si escaparon; en el centro con «SIN SEÑAL» en una línea si no) reproduce los clips con la imagen de la noche dentro (la propia vista del mundo, con la cinta); flechas ◀ ▶ a los lados (anfitrión: ←/→ o A/D, se iluminan en todas las pantallas al cambiar), ESPACIO todos seguidos; cada clip se repite hasta que se elige otro; el primero empieza solo. Sin títulos: debajo solo el nombre de a quién pertenece y «2 / 5».
  - **Tu voz en los clips:** se graba siempre que haces ruido (por encima de `VAD_MIN`), no solo cuando el filtro de voz la deja pasar a los demás (solo, o con pulsar para hablar, ahora sale).
  - **Bots en la sala:** botón «BOTS: n» del anfitrión (hasta llenar 4); salen en la lista como «Bot n (IA)». Son tripulantes manejados por la casa (`CrewBot`, en el anfitrión; su cuerpo se replica como el de cualquiera, autoridad del anfitrión): buscan cintas (solo las que ven, a 5 m), van a la furgoneta, huyen o se esconden si la Visita se acerca, la flashean si pueden (cada ~9-12 s) y, escondidos, a veces flashean su cara al asomarse. Sirven para jugar de Visita solo (sala con bots y «MODO: VISITA ES tú») o para llenar la sala. `Player.is_bot`. Dev: `res://scenes/main.tscn -- --bots 3 [--versus-me] --bot-test`.
  - **Visita 3D mucho más inquietante:** proporciones nuevas (piernas más cortas, cuerpo largo con el abrigo hasta las rodillas, cuello de 0,5 m que sobresale hacia delante como el de un buitre y llega a 1,5 m al estirarse; ya no parece un avestruz), respiración (las costillas se hinchan), la cabeza da tirones a ángulos imposibles y los mantiene, el cuerpo se tuerce de golpe, a veces un fotograma con una rodilla o un codo doblado al revés, fotogramas retenidos de más, dedos que se crispan uno a uno. **Solo te mira si va a por ti** (persigue, acecha, sigue, se asoma, come, está en el techo o descubierta); si no, mira hacia donde va y echa vistazos (antes parecía que te veía sin hacerte nada). **Más expresiones:** al hablar la boca se abre y cierra con su voz, cerca y yendo a por ti la sonrisa se parte, y de vez en cuando pone un instante una cara que no toca. En el techo cuelga más abajo y la cara mira hacia abajo, a ti (antes la cabeza se metía en el techo).
  - Alt+F1 (monitor de la Visita) vuelve a funcionar en el juego publicado.
- **Duodécima ronda (2026-10-27):** sin ojos blancos: los agujeros de la máscara son solo oscuridad, en 3D y en el dibujo (la embestida conserva su chispa de luz); en 3D, hombros estrechos y caídos y el abrigo de tiras cayendo desde el cuello sobre los hombros (antes formaba un bloque de hombros cuadrados), más pelo y abrigo con tiras más finas.
- **Undécima ronda (2026-10-27): cara nueva, en las dos versiones.** La máscara de dibujo infantil (ojos de caricatura) da paso a una máscara de yeso vieja de cara de niño-oso «casi bien»: rasgos esculpidos demasiado humanos, agrietada, desconchada, mugre en cada hueco, manchas marrones que bajan de los ojos y la boca, colorete y labios pintados un poco desplazados, dientes humanos pequeños y amarillos (`tools/gen_entity_mask.py`: color con agujeros + mapa de relieve + un ojo). Expresiones: sonrisa cerrada en una rendija (de pie/andando), ojos cosidos con sonrisa de dientes (alcanzar), sonrisa de dientes (ladeada, gateo, galope), sonrisa partida (asomarse, cuello), rendija triste con más manchas (agachada), grito estirado (carrera), y en la embestida roja con agujeros negros y una chispa de luz, la boca rasgada hasta pasada la barbilla.
  - **3D:** la máscara es una concha curva (malla propia con nariz y frente) con relieve por mapa de normales; detrás de los agujeros, oscuridad (en la embestida, una chispa de luz). La cabeza se orienta a ti en el mundo aunque el cuello esté doblado (sin quedar torcida).
  - **Dibujo «nueva»:** `gen_entity_v2.py` pinta la misma máscara (iluminada por su relieve) con los agujeros oscuros; las demás partes del dibujo no cambian. La tele usa el dibujo, así que también la lleva. La «clásica» queda como estaba.
- **Décima ronda (2026-10-27): la Visita en 3D (opcional).** En Opciones, «LA VISITA: 3D» (tercera opción tras NUEVA y CLÁSICA; `Net.entity_style` 2, `Entity.is_3d()`); las dos versiones dibujadas siguen igual.
  - `EntityModel`: la misma criatura que el dibujo «nueva» como marioneta de stop-motion: la máscara de yeso (ver undécima ronda: `tools/gen_entity_mask.py`), cuerpo negro mate demasiado largo y fino, un abrigo de tiras negras colgando, pelo largo negro (tarjetas que cuelgan hacia abajo aunque el cuerpo se doble o esté en el techo, sin tapar nunca la máscara), filamentos en los miembros, brazos larguísimos y manos enormes con dedos de tres falanges y garras.
  - Se anima por poses (una por `Entity.Pose`, con ciclo de andar, galope a cuatro patas, carrera con los brazos hacia ti, cuello que crece, techo boca abajo) a saltos de stop-motion (~10 por segundo, temblando un poco cada vez; a tirones al perseguir). La cabeza siempre se gira hacia quien la mira. Mira hacia donde va; quieta, hacia ti. Al asomarse a un escondite y al embestir, la cara se coloca donde estaría la del dibujo (`anchor_face`). Quemada/enfurecida: brillo rojo en el negro. Solo la cámara la ve (misma capa que el dibujo).
  - En las repeticiones se reproduce también en 3D (`Entity.model_args` se graba). La tele y lo demás siguen usando el dibujo.
  - Dev: `--entity-3d` (esa partida en 3D) y `res://scenes/main.tscn -- --model-shots <dir>` (todas las poses iluminadas, de frente y de lado).
- **Novena ronda (2026-10-27): la vista de la Visita, acabada.**
  - **Su ojo** (`shaders/entity_sight.gdshader`, en lugar del PostFX del equipo): la imagen pasa por una rampa propia (negro, sangre seca, rojo vivo, blanco hueso), la lente abomba un poco (más cazando), el aire tiembla, los colores se separan hacia los bordes, el borde de la vista se cierra y late con su corazón; tramado y niveles como el resto (mismo registro de píxel). Cegada por el flash: blanco que se quema a rojo y la imagen nada. Dormida: casi negro, una respiración roja. Sintiendo (Q): todo se oscurece y respira rojo.
  - **El calor de los vivos** (`entity_heat.gdshader` como `material_overlay` en sus cuerpos, solo en su máquina): brillan blanco-hueso por los bordes, respirando, y se apagan con la distancia (15 m). Con Q, `entity_heat_xray.gdshader` los muestra a través de las paredes. Los muertos están fríos.
  - **Su cuerpo:** corazón audible (`pilot_heart`, de ~60 a ~140 pulsaciones según caza o cercanía, y el borde de la vista late con él), su respiración (más fuerte cazando o sin aliento), balanceo al andar (lento acechando, a sacudidas cazando), golpe al subir/bajar del techo (`pilot_land`), FOV que se abre al cazar y al embestir, sonido propio al sentir (`pilot_sense`). Sonidos e iconos en `tools/gen_pilot.py`.
  - **Pantalla (`PilotHud`) rehecha:** arriba a la izquierda una figura por cada superviviente (tachada si cae) y las cintas; abajo en el centro la barra de aliento y cinco iconos dibujados (agarrar, hablar, techo, sentir, mirar) que se oscurecen mientras se recargan, con los segundos y un destello al estar listos; los ruidos son ondas (o una flecha en el borde si vienen de detrás); los sentidos, solo la distancia. Sin nombres sobre las cabezas para la Visita.
  - F3 (información de depuración) solo funciona en ejecuciones de depuración (`OS.is_debug_build()`); Alt+F1 sí está en el juego publicado (el usuario prueba con él).
- **Octava ronda (2026-10-27): voces en las repeticiones y «La Visita es un jugador».**
  - **Repeticiones:** ahora se oyen las voces del chat de ese momento (cada máquina guarda los paquetes mu-law que recibe y los suyos propios, `Replay.note_voice`, y los reproduce desde la cabeza de cada muñeco) y se ve el cuerpo cuando la Visita lo arrastra o lo lanza (cada fotograma guarda la posición de los cadáveres; un muñeco con la misma pose que `Corpse`).
  - **Modo nuevo en la sala:** el botón de modo del anfitrión va rotando «MODO: NORMAL» → «MODO: VISITA AL AZAR» → «MODO: VISITA ES <nombre>» (uno por jugador). Al azar nunca repite al mismo dos noches seguidas si hay más gente. `Net.game_mode`, `Net.entity_choice`; `Net.entity_peer` viaja con `_start`. Hacen falta 2 jugadores o más (si no, noche normal).
  - **Quien es la Visita** no tiene cuerpo en la casa (su `Player` queda oculto, sin colisión, `alive = false`, sin cámara, fuera de `alive_players()`): juega en primera persona con `EntityPilot` (solo en su máquina) y `PilotHud`. Su voz solo la oyen los muertos; él oye a todos. Si se desconecta, la IA retoma a la Visita.
    - **Vista de entidad:** ve en la oscuridad, todo en rojos y con niebla roja a partir de ~10 m (`PILOT_FOG`), viñeta roja. Oye a través de las paredes: un anillo rojo donde alguien corre (14 m), habla (12 m) o hace un ruido del mundo (18 m: cintas, puertas, flashes, cámaras; vía `Sfx.listeners`). A los escondidos no los ve (bajo una mesa solo de cerca, `Player.entity_view`).
    - **Controles:** WASD andar (2,3 m/s), C acechar (1,3, sin pasos, el aliento en la nuca), SHIFT cazar (4,8 m/s durante 3,5 s de aliento, se recupera en ~8 s; grita al arrancar, como mucho cada 8 s), ESPACIO techo (0,6 s para subir/bajar; 2 m/s, por encima de los muebles y por la ventana rota de las puertas, no por las cerradas sin ventana; sin ruido), CLIC IZQ atrapar (embestida corta de 0,3 s; atrapa a quien esté a 1,6 m delante y a la vista; desde el techo cae sobre quien esté debajo, 1,5 m), Q sentirlos (3 s viendo dónde están todos a 30 m, cada 35 s; los vivos oyen un susurro), E abrir/cerrar puertas (despacio, crujiendo) o mirar en un escondite (quien esté dentro ve su cara 2 s: si le flashea se salva; si no, lo atrapa).
    - **Equilibrio:** en línea recta el equipo (4,2 m/s sin límite) se escapa; la Visita gana con sigilo, el techo, callejones y puertas. Fallar un agarre la frena 1,3 s; después de atrapar a alguien, 2,5 s comiendo y 1,5 s lenta; el flash la ciega 2,5 s (1,2 s con todas las cintas) y la deja inmune 8 s; cada cinta la hace un 3 % más rápida; con todas, +50 % de aliento y «sentir» a mitad de espera. La alerta de la tele entra como mucho al minuto (la Visita espera dormida).
    - **Red:** su máquina la mueve sin esperar a la red y manda posición, giro, techo y modo 30 veces por segundo (`Run._pilot_state`); el anfitrión la coloca (salvo comiendo o asomada a un escondite) y lo reparte con el sincronizador de siempre; agarres, búsquedas, puertas, frases y flashes los decide el anfitrión (`Run.pilot_attack`, `_pilot_search`, `_pilot_door`, `_pilot_taunt`, `_pilot_burned`) y le avisa (`_pilot_event`). En `Entity`: `pilot_id`, `piloted_here`, sin mente propia (`_pilot_host_tick`).
    - **Pantallas:** intro propia («ERES LA VISITA» + controles); los demás ven «LA VISITA ES <nombre>» en la suya; final «LA CASA ES TUYA» / «SE HAN ESCAPADO» para ella y «La Visita era <nombre>» para los demás.
  - Pruebas: `--smoke` comprueba al jugador-Visita (anda, techo, agarre fallido, flash, agarre); `--net-test host --net-versus` + `--net-test client`: el invitado es la Visita y atrapa al anfitrión en red. Dev: `--smoke --pilot-shot <dir>`, `--menu-shot <png> --lobby --versus`.
- **Séptima ronda (2026-10-27):**
  - Texto inicial: el paso 1 es «INVESTIGA LA EXTRAÑA MÚSICA» (no dice que te sientes: lo descubres en la tele). El texto está en una sola línea con `\n`: `tools/i18n.py` lee línea a línea y no recogía cadenas partidas en varias líneas (el texto inicial no estaba traducido al inglés; ahora sí).
  - **Aviso de la tele más sutil:** título «COMUNICADO» (antes «AVISO DE EMERGENCIA»), sin cuadro rojo parpadeando, tono a -24 dB, y las reglas dichas de forma indirecta, como una nota a los vecinos: «ESTA NOCHE HAY VISITA», «NO LA BUSQUE CON LOS OJOS», «A LA VISITA NO LE GUSTAN LAS FOTOS» (el flash), canción, «te estoy viendo» y no contestar, «BUENAS NOCHES». El aviso corrupto final no cambia.
  - **Puertas para clips:** ya se le puede cerrar la puerta en la cara a la Visita (antes no se cerraba con ella a 2,2 m); solo la sujeta si está en el mismo hueco. Ventana rota encima en el 85 % de las puertas (`TRANSOM_CHANCE`), pero siempre queda al menos una puerta entera por casa.
  - **Mejores momentos (`Replay`, `ReplayUI`):** al acabar la noche (ganando o perdiendo) sale abajo la lista «MEJORES MOMENTOS» (hasta 5); el anfitrión pulsa ESPACIO para verlos todos seguidos o 1-5 para uno, y ESPACIO para parar; se reproducen a la vez en todas las máquinas.
    - Cada máquina graba lo que ve a 12 Hz (jugadores: posición, cámara, pose, linterna; el dibujo de la Visita tal cual; puertas; luz; sonidos del mundo vía `Sfx.play_3d`/`Sfx.heard`; flashes; muertes) y solo guarda los últimos 10 s y los segundos alrededor de cada momento. Las grabaciones nunca viajan por red: el anfitrión avisa de cada momento al instante (`Run._moment` → `_mark_moment`, mismo id en todos), al final elige (`Replay.pick`: por puntuación, uniendo los que se solapan hasta 16 s) y manda solo los ids.
    - Momentos (puntuación, segundos antes/después): atrapado 100, escapa 90, te encuentra escondido 70, flash en la cara 65, cae del techo 60, la pillas al acecho 55, por los pelos (a <1,4 m en persecución y sobrevives 4 s) 50, puerta en la cara 45, deslumbras a un amigo 40, la última cinta 35.
    - Se ve desde los ojos de quien lo vivió («CÁMARA DE …», PLAY, fecha y hora de la cinta), con la Visita siempre dibujada (en la cinta se ve), muñecos de los jugadores y la casa como estaba (puertas, apagón); al parar todo vuelve a su estado. Dev: `--smoke --replay-shot <dir>` guarda capturas de un clip.
  - Registros: `debug/file_logging/max_log_files=20` (Godot guardaba 5 y las pruebas borraban el registro de un cuelgue). Las pruebas se lanzan con `--log-file <scratchpad>` para no pisar los registros del jugador.
- **Sexta ronda (2026-10-27, tras cooperativo):**
  - **Se lleva el cuerpo:** tras atrapar a alguien (si queda alguien vivo) coge el cadáver y lo arrastra 9-16 pasos lejos (nunca cerca de nadie), sin hacer caso a nadie ni poder atrapar mientras tanto (`_taking_away`), y lo deja allí: el resto tiene tiempo de alejarse.
  - Persecución algo más lenta (`CHASE_SPEED_MULT` 1,75). Chat de voz aún más fuerte (objetivo 0,22, ×10, reproductor +12 dB).
  - **Conexión perdida:** si el «peer» desaparece en partida (el otro se colgó o Epic cortó), vuelve al menú con «Se perdió la conexión con la sala» en vez de seguir sin red (en el registro del anfitrión de un cuelgue se veía eso: un aluvión de «No multiplayer peer»).
  - Texto inicial corto y didáctico: tres pasos (sentarse a ver la tele, encontrar N cintas, volver a la furgoneta), «Algo vive en esta casa. Solo la cámara lo ve.» y una línea de controles. Dev: `--intro-shot <png>`.
  - «¡LIBERTAD!» más bajo y lejano (-8 dB, apagado por las paredes, 1,5 kHz).
- **Puertas, última palabra (2026-10-26):** tras pensar cada fotograma, `Entity._door_guard()`: dentro del hueco de una puerta cerrada **con ventana rota** va siempre por el techo (aunque un cambio de modo, verte o una persecución lo hubieran bajado); una cerrada **sin ventana** nunca la atraviesa: la abre (solo esas) y retrocede hasta que se abra. Gritos (persecución, agonía, hambre) +5 dB sobre la voz (`SCREAM_BOOST`); el de persecución más saturado y algo aplastado.
- **Quinta ronda (2026-10-26):**
  - Sofá de 3 plazas (o una butaca) centrado frente a la tele y a 2 casillas; te sientas en la del centro primero; el encuadre (`seat_fov`) se calcula para que la tele ocupe media pantalla a esa distancia. La cámara de encima de la tele **flashea a la figura** al final de la imagen en directo: estallido de luz, sonido de flash, grito de agonía, y la figura, roja, sale corriendo (enseña el flash).
  - Subtítulos de la tele más grandes (22 px con contorno) y la pantalla filtrada en lineal (las letras pequeñas se rompían).
  - **El apagón llega con la mitad de las cintas** (`Run.blackout_at()`: ⌈cintas/2⌉, antes siempre 2).
  - Rendija del armario más abierta (puertas a 0,5 rad).
  - Volumen: todo lo de la Visita +4 dB más (`LOUD` 8, voz 12, tope 18) salvo el screamer, el grito de furia y el «¡LIBERTAD!» (fijo a 0 dB); sus pasos un poco más bajos (sin `LOUD`). Chat de voz más fuerte (ganancia objetivo 0,17, máx ×8, reproductor +8 dB, tope 12).
  - En el techo, la cara sigue siendo un recorte que te mira (billboard aparte con la cabeza del fotograma); el cuerpo plano contra el techo, sin su cabeza.
- **Ver la tele sentado (2026-10-26, tutorial interactivo):** E en la tele te sienta en el sofá frente a ella (`TvBroadcast.seat_for`: las celdas del sofá por orden de jugador; el resto detrás), siempre en el mismo sitio: no puedes andar ni levantarte hasta que sale el aviso (entonces «[E] Levantarse»), solo mirar un poco (±0,5 rad) y no puedes subir la cámara; la vista se estrecha sobre la pantalla (`SEAT_FOV` 22, ojos a 1 m). El panel a pantalla completa ya solo sale para leer el texto del aviso; el programa y lo que pasa se ven en la propia tele.
  - Encima de la tele hay una **videocámara** apuntando al sofá: es de donde sale la imagen «EN DIRECTO» (encuadrada sobre ti), y se le enciende la luz roja cuando la emite. En esa imagen la figura se te acerca por detrás y, al final, **sale corriendo** fuera del cuarto: la cámara la ve; tú, no (enseña que solo las cámaras la ven).
  - Sofá con textura nueva de pana gastada (antes un cuadriculado que parecía «falta textura»).
- **Cuarta ronda (2026-10-26):**
  - Grito de persecución **humano**: un hombre gritando desesperado, la voz forzándose de ~180 a ~420 Hz y quebrándose arriba, ronca, con una segunda garganta un pelo desafinada y una octava baja suave, jadeos entre ráfagas (3 tomas).
  - **Ya no repta como una araña:** persiguiéndote corre **de pie** (ciclo de andar rápido) a `CHASE_SPEED_MULT` 2,0 (≈2,5 m/s al principio, igual la grabes o no; ×1,25 sin que la miren); solo va a cuatro patas **huyendo del flash**, y las poses de gatear (huida y bajo las tablas) son ahora de persona a cuatro patas (brazos bajo los hombros, rodillas bajo la cadera).
  - **Corriendo hacia ti grita con la cara:** pose `RUN` (fila 11 de `entity_sheet_v2.png`, `face="scream"`): ojos enormes con pupilas diminutas, la mandíbula caída en un agujero negro con dientes, los brazos estirados hacia ti, la cabeza adelantada y ladeada. El movimiento es perturbador: la zancada va a tirones (un fotograma retenido de más y luego dos de golpe, 0,05–0,22 s), la cabeza da sacudidas y a veces todo el cuerpo se ladea de golpe (`_jerk_t`, `_twitch`).
  - **En el techo:** pegada a él con todo el cuerpo extendido, la cara mirando abajo y la cabeza hacia ti (sprite horizontal, ya no colgando boca abajo).
  - **Grabarla no la avisa:** el «descubierta esperando» (mirada, cuello estirado, grito y carrera) solo pasa si te ve mientras la grabas (`_sees_now`); y ya no suena el golpe de cinta al verla por la cámara.
  - El aire de ambiente se apaga mientras miras la tele.
- **Tercera ronda (2026-10-26, tras jugar 0.2.2 en cooperativo):**
  - **Flash más débil en compañía:** cuesta 30 % (20 % solo), recarga 6 s (3 s solo), alcance 12 m; tras un flash la Visita ignora los siguientes `FLASH_IMMUNE` + 4 s por cada otro jugador vivo (no se puede encadenar), huye 0,6× y vuelve antes (recuperación ×0,35 con 4).
  - **Montantes:** ahora el 70 % de las puertas lo tienen y el hueco es mayor: esas puertas son más bajas (dintel 1,9 m, hoja 1,84) y el hueco va de 2,0 a 2,54 m, sin parteluz y con poco cristal, para que se vea que la Visita pasa por ahí.
  - Puertas: la zona para usarlas es una franja en el lado de la hoja (no todo el hueco); abierta, la hoja no choca.
  - La Visita nunca se queda atascada sujetando a alguien (si lleva >6 s «comiendo», se suelta; y si el atrapado ya estaba muerto, se suelta al momento).
  - Muerto, tu voz solo la oyen los otros muertos (antes se seguía enviando a todos).
  - Al espectar a alguien escondido, su vista está a la altura del escondite (la cabeza de los demás sigue su escondite / agacharse).
- **Tu propio cuerpo (2026-10-26):** en primera persona ves tus caderas, piernas y botas al mirar abajo, y la sombra de tu cuerpo (`PlayerAvatar.set_self_view`): la cabeza, los brazos (las manos son las de primera persona) y el pecho van en `SELF_LAYER`, que tu cámara no dibuja (la cámara de la tele sí). El cuerpo va 5 cm por detrás del ojo y avanza bajo él al mirar abajo (hasta 32 cm), para que se vean los pies. Escondido, tú no te dibujas, pero **los demás te ven ahí** (decisión del usuario 2026-10-26): bajo la cama o la mesa tu cuerpo está tumbado boca abajo con la cabeza justo en el borde, mirando fuera, los codos junto a la cabeza (`PlayerAvatar.lying`, `lie_back` según la profundidad del mueble, `HideSpot.depth`); en el armario las puertas te tapan. Tu nombre baja a la altura del escondite. Esto es solo visual: la Visita sigue sin verte bajo la cama o en el armario.
- **Puertas (2026-10-26)** (`scripts/world/door.gd`, `Level._plan_doors/_build_doors`): el 75 % de los pasos de puerta («D») tienen puerta normal de altura completa (el 45 % empieza abierta). Sobre un 35 % hay un **montante con el cristal roto** (`TRANSOM_CHANCE`, `Level._add_transom`): la pared encima del dintel queda abierta, con su marco, el parteluz colgando y dientes de cristal en las esquinas (decisión del usuario 2026-10-26: nada de puertas de establo). Se abren/cierran con **E** (decisión: E en vez de arrastrar con el ratón, más claro en cooperativo, sin trampas de físicas y fácil de sincronizar); giran 90° hacia el paso en 0,5 s, con sonido (`door_open`, `door_close`). El anfitrión decide (`Run._request_door`) y lo replica (`Door.set_open`).
  - **Anti-abuso:** no se puede usar mientras gira ni 0,9 s después (`COOLDOWN`); no cierra si hay alguien en el hueco ni con la Visita a menos de 2,2 m («Algo la sujeta desde el otro lado»); abrir/cerrar hace ruido (la Visita lo oye). La Visita nunca se queda atascada: si una puerta cerrada le corta el paso, la abre despacio chirriando (`door_creak`, 1,1 s) y espera; si la puerta tiene el montante roto, no la abre: pasa por la ventana rota, por el techo (`on_ceiling`), y la deja cerrada.
  - Cerrada, la hoja está en la capa del mundo: tapa el paso, la vista de la Visita, la voz (se ahoga) y el flash. Los bots abren las puertas que encuentran.
- **Flash en cooperativo (2026-10-26):** antes el anfitrión no veía ni oía el flash de los invitados (el RPC excluía al anfitrión); ahora todos lo ven (luz con sombras + un destello en la cámara de quien dispara) y lo oyen, y quien dispara no lo recibe dos veces. **Flashear a un amigo:** si está en tu encuadre, a menos de 14 m, sin nada en medio y mirándote, se le pone la pantalla blanca ~2 s con una mancha morada y un pitido en los oídos (`Run._dazzle`, `dazzle`, `tinnitus`); de espaldas no le afecta.
- **Inventario y barra de herramientas (2026-10-26)** — base para las 4 herramientas (se planearán aparte; idea: con 4 jugadores cada uno necesita usar una para cumplir el objetivo):
  - `Inventory` (`scripts/player/inventory.gd`): mano izquierda, mano derecha y 6 huecos de mochila; objetos por id (`"flashlight"`, `"camcorder"`; iconos en `items.png`, `tools/gen_items.py`). **Solo funciona lo que está en una mano**: la linterna solo alumbra desde una mano (F la enciende/apaga: `Player.light_on`), la cámara solo graba desde una mano (cualquiera). Al empezar: linterna en la izquierda, cámara en la derecha. Coger una cámara la pone en una mano libre o en la mochila; soltarla (G) la quita. Las manos se replican (`net_left`/`net_right`): los demás ven en tu avatar lo que llevas en las manos.
  - **I** abre el inventario (se puede seguir andando; no se mira ni se usa nada): arrastra cualquier objeto a cualquier hueco para intercambiarlos, también una mano con la otra. I o Esc lo cierran (`InventoryUI`).
  - **Barra** abajo en el centro con las dos manos (la batería de la cámara debajo de su icono, un punto si la linterna está encendida). Minimalista: aparece al cambiar o usar algo o al mover la rueda del ratón, y se desvanece a los 2,5 s.
  - Las manos en primera persona (`ViewModel`) llevan lo que diga el inventario, en el lado que toque (espejado); la cámara sube al ojo desde la mano que la tenga.
  - **Gestos que no cortan la acción:** al recoger algo la mano libre baja rápido a por ello (0,34 s, la vista se inclina un poco, sonido `grab`); una cinta se guarda (`tape_pocket`); una batería se mete en la cámara: la cámara viene al centro girada y la otra mano encaja la batería (`battery_insert`: deslizar, clic, doble pitido). Si subes la cámara a mitad, se corta.
  - Baterías y cintas con modelo nuevo (`GearModels.battery()/tape()`): pack gris acanalado con banda naranja, contactos y luz verde que parpadea (se ve en la oscuridad); cinta VHS con ventana, dos bobinas y etiquetas.
- **MIC:** medidor vertical a la izquierda, a media altura (se llena hacia arriba; «TE OYE» / «¡TE ENCUENTRA!» a su lado).
- **Muebles con más detalle (2026-10-26):** sofá con patas, cojines de asiento y de respaldo; cama con colchón, manta que cuelga y doblez, almohadas (dos en la doble), cabecero con remate y piecero; mesa con faldón; encimera con puertas, pomos de latón y zócalo; armario con dos puertas, tiradores, zócalo y cornisa; mueble de la tele con estantes y un vídeo VHS con su luz verde; cajas con cinta de embalar. Texturas de muebles a 64 px/m (`linen`, `brass`, `plastic` nuevas).
- **Guantes del osito rehechos (2026-10-26):** ya no son tubos sueltos («salchichas»): `gen_tv.draw_glove` dibuja cada guante como UNA forma acolchada (palma redonda, tres dedos gruesos y pulgar que salen de ella, inflados juntos con un mapa de alturas por distancia al borde), contorno fino, pliegues cortos entre dedos, tres costuras en el dorso y puño enrollado; `curl` los dobla al agarrarse al sofá y `flat` los tumba (los guantes abandonados en el sofá).
- **Menú:** la tele es un dibujo nuevo (`tools/gen_menu_tv.py`, `menu_tv.png`): mueble de nogal, marco con labio, cristal con brillo y sombra interior, franja de mandos con rejilla de altavoz, marca VISTAVOX, ventanita del canal «09», dos mandos metálicos, piloto rojo, antenas y patas. El título es un logo (`gen_branding.py logo()`, `title.png`, también en el splash): LOST SIGNAL con las letras separadas en rojo y cian, franjas desgarradas, líneas, nieve y un brillo ámbar; debajo «● ANALOG HORROR». En el menú salta y parpadea con los fallos de la tele.
- **Gráficos ALTOS/BAJOS (2026-10-26, decisión del usuario: «menos pixelado», el juego le iba bien en un PC flojo):** por defecto el mundo se dibuja a **960×540** (`Settings.graphics = "high"`, `Main._set_render_scale`: el `WorldView` mide 480×270×2 y se dibuja a ½, así la interfaz sigue en 480×270), con MSAA 2× y sombras de borde suave (bajo). «GRÁFICOS: BAJOS (480x270)» en Opciones vuelve a lo de antes (sin MSAA, sombras duras), para PCs muy modestos; se aplica al empezar la siguiente partida. Si la ventana no es múltiplo entero de la resolución del mundo, se escala suave (lineal) en vez de nearest, para que los píxeles no tiemblen. Las líneas de la cinta (scanlines, cortes) siguen a 270 líneas por imagen (`line_px` en `post.gdshader`); el grano y el tramado van a resolución completa.
- **Pasada de acabado (2026-11-19):**
  - **Controles y accesibilidad** (`scripts/ui/access_options.gd`, en Opciones del menú como página propia y en las opciones de la pausa): sensibilidad del ratón (×0,25–×2,5 sobre `Tuning.MOUSE_SENS`, `Settings.look_scale()`, también para la Visita jugable), eje Y invertido y **MENOS DESTELLOS** (`Settings.reduce_flashes`, `flash_scale()`): baja el ruido de imagen, los golpes de la cinta, los cortes rojos del susto y el blanco del flash propio; el deslumbramiento por el flash de un compañero sigue cegando, pero en gris. Solo presentación local. No hay ajuste de FOV a propósito: el ángulo de visión cuenta para saber si alguien mira a la Visita.
  - **Aviso de fotosensibilidad** la primera vez, en la pantalla de arranque (`Settings.photosensitivity_seen`; una tecla sigue tras 1,2 s). Dev: `--boot-shot <png> --notice`.
  - **Corte de cinta entre escenas** (`TapeCut`, `shaders/tape_cut.gdshader`): arranque → menú, menú → partida y vuelta al menú salen de negro con bandas de estática y un siseo. Capa sobre la raíz, no autoload (project.godot no viaja en un parche). No toca el post-proceso del mundo.
  - **Teclado:** en el menú y en la pausa, una flecha elige el primer botón; flechas, Enter y Esc lo recorren todo (los deslizadores con izquierda/derecha).
  - **Créditos** en el menú (CRÉDITOS). Dev: `--menu-shot <png> --credits` / `--access`; `--shots <dir> --pause-only` saca solo la pausa.
- **Texturas a 64 px por metro (antes 32)** con más detalle (`tools/gen_textures.py`, ruido fractal enlosable `fbm`): papel pintado con ornamento más fino, estrellas de cinco puntas y lunas en el cuarto infantil, manchas de agua con línea de marea, desconchones más sutiles, grietas finas, rozaduras, zócalo con veta y golpes; tablones con veta, nudos, clavos y juntas; baldosas biseladas con tonos distintos, algunas rajadas, juntas sucias; techo con gotelé y manchas con cerco; puerta con molduras, cerrojo y arañazos; alfombra con pelo y zonas gastadas. El estilo sigue siendo pixel art (filtro nearest, colores posterizados).
- **Render:** el mundo 3D vive en un `SubViewport` de 480×270 (`WorldView/World` en `main.tscn`), escalado con nearest; el post-proceso va dentro de ese SubViewport. La interfaz se dibuja encima a la resolución real de la ventana (`stretch/mode="canvas_items"`, base 480×270, escala entera, ventana 1440×810) para que el texto sea nítido. El SubViewport tiene `audio_listener_enable_3d` activado (sin eso no se oye el audio 3D). Sin MSAA/FXAA, sombras duras (`soft_shadow_filter_quality=0`), proyector de linterna nearest, atlas de sombras 2048. Texturas importadas sin compresión, con mipmaps y sin detección 3D (`[importer_defaults]`), para que el pixel art no se emborrone.
- **Estructura del código:**
  - `data/tuning.gd`: todos los números de juego y las capas de física.
  - `scripts/world/house_generator.gd`: genera la casa (semilla + número de cintas) como `HouseLayout`.
  - `scripts/world/house_layout.gd`: la casa como datos: una rejilla de caracteres por planta (leyenda en el archivo), habitaciones, escaleras y decoración; responde a casillas `Vector3i(x, planta, z)`, caminos BFS con escaleras y validación.
  - `scripts/world/level.gd`: construye la casa a partir del `HouseLayout`. Una malla con una superficie por material, un colisionador trimesh, muebles, escaleras, lámparas y los puntos del mapa.
  - `scripts/entity/corpse.gd`: el cuerpo de un atrapado (tumbado, arrastrado o volando), replicado desde el anfitrión.
  - `scripts/entity/director.gd`: el director de tensión (emboscadas y pistas vagas).
  - `scripts/world/hide_spot.gd`: escondites (cama, mesa, armario).
  - `scripts/world/tv_show.gd`: el orden del programa de la tele (fotograma y rótulo en cada momento) y los índices de `tv_show.png`.
  - `scripts/core/run.gd`: estado de la noche (autoritativo) con fase, cintas, escalada, captura y huida.
  - `scripts/entity/entity.gd`: la Visita. Capa visual 2, que solo renderiza la cámara al grabar.
  - `scripts/player/`: jugador (`player.gd`) y videocámara (`camcorder.gd`).
  - `scripts/ui/`: post-proceso, visor, HUD, pantallas y overlay F3.
  - `shaders/post.gdshader`: una sola pasada a pantalla completa (tramado, cuantización y VHS).
  - `scripts/core/`: también `controls.gd` (acciones de entrada, remapeables) y `sfx.gd` (caché de audio).
- **Fuente:** VT323 (Google Fonts, licencia SIL OFL 1.1; `game/assets/fonts/` con `OFL.txt`), fuente por defecto del proyecto. Tamaños en coordenadas base de 480×270: 13 para la interfaz y 10 para el overlay F3. La televisión tiene un área para leer el aviso a tamaño completo ([E] Leer el aviso).
- **Assets placeholder generados:** `python tools/gen_textures.py`, `tools/gen_entity_v2.py` (la Visita nueva; tarda ~2 min), `tools/gen_entity.py` (la clásica), `tools/gen_tv.py` (el programa de la tele y el sello de la alerta; tarda ~1 min), `tools/gen_music.py` (música; antes que `gen_entity_audio.py`), `tools/gen_audio.py` y `tools/gen_entity_audio.py` (requiere scipy). Después hay que importar con `godot --headless --path game --import`.
- **Pruebas de desarrollo** (todas tras `--`):
  - `godot --headless --path game -- --smoke`: comprueba que la entrada llega al mundo 3D y las reglas (grabar congela, sin grabar te alcanza desde su cuarto, la cuota abre la salida), 100 casas generadas, cintas sin meterse en paredes, cadáveres, y la mente de la Visita: no sabe dónde estás, oye ruidos, no atrapa a través de paredes, no te encuentra escondido salvo si hablas, el director prepara emboscadas y nunca te pierde más de ~30 s. Imprime líneas `SMOKE ok` / `SMOKE FAIL` y su código de salida indica si falló algo.
  - `godot --path game -- --shots <carpeta absoluta>`: recorrido que busca sus propios puntos de vista en la casa generada (habitaciones por tipo, escalera, tablones, la Visita acechando, un cadáver lanzado…) y guarda unas 35 capturas. Imprime el mapa (`MAP`) y una línea `PERF`.
  - `--seed N` fija la casa y la colocación; `--tapes N` el número de cintas (y el tamaño de la casa).
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
  - Los nodos sincronizados tienen el mismo nombre en todas las máquinas: `P<id>`, `Entity`, `Level/TV`; las cintas, `Tape<n>` / `Battery<n>`; las cámaras sueltas, `Camcorder<n>` / `Fallen<id>`; los cadáveres, `Level/Corpse<id>`; los escondites, `Level/Hide<n>`. Todos generan la misma casa con la misma semilla y número de cintas.
  - Prueba: `godot --headless --path game res://scenes/dev/eos_check.tscn` → `EOS_CHECK ok code=…` (verificado el 2026-10-25).
  - Trampas conocidas:
    - `application/config/version` vacío hace fallar `EOS_Initialize`.
    - Liberar la plataforma dentro del tick de EOS cierra el juego con signal 11.
    - El Client ID del portal lleva `9Ii`.
- **Modelo online previsto:** host autoritativo. `Run` y el movimiento de la entidad corren en el host, que necesita de cada jugador `filming` y la transformación de su cámara. Visibilidad, sombra, audio y post-proceso son locales.
- Plataforma objetivo inicial: Windows. Se publica en itch.io con butler (ver «Publicar»).
- **Idiomas (2026-10-25):** inglés y español, con sistema gettext pensado para añadir más.
  - El juego está escrito en español: el texto en español es la clave (`msgid`). El inglés es `game/locale/en.po` (completo: 186 textos). `locale/fallback="es"`: lo que falte en un idioma sale en español.
  - `tools/i18n.py` recoge todos los textos de `game/scripts` (`tr()`, `tr_n()` con plurales, `TranslationServer.translate()` y las líneas marcadas con `# i18n`), regenera `game/locale/messages.pot` y pone al día cada `.po` conservando lo traducido; `--check` lista lo que falta (el release se niega a publicar si falta algo). Los scripts de `scripts/dev/` (tests, tours) no se traducen.
  - Idioma al abrir: el de Windows si el juego lo tiene (`OS.get_locale_language()`), si no inglés. En Opciones del menú, «IDIOMA / LANGUAGE» recorre los idiomas cargados y rehace el menú; se guarda en `settings.cfg` (`Settings.language`, `""` = el del sistema). Dev: `--lang en|es`.
  - Texto dentro de imágenes: solo la cartulina «¡ALLÁ VOY!» del programa de la tele; `tools/gen_tv.py` genera `tv_show.<idioma>.png` (`READY_TEXT`, «HERE I COME!») y `project.godot` la cambia por idioma (`translation_remaps`). El splash es neutro (LOST SIGNAL · ANALOG HORROR).
  - Añadir un idioma: copiar `messages.pot` a `game/locale/<código>.po`, poner `Language:` y la regla de plurales, traducir, añadirlo en `project.godot` (`internationalization/locale/translations`), su nombre en `Settings.NATIVE` si falta, y su cartulina en `READY_TEXT`. Las voces de la Visita están en español deformado (no se entienden: no hace falta doblarlas).
  - Ajustes de antes del cambio de nombre: `Settings._migrate()` copia `settings.cfg` de la carpeta antigua (`app_userdata/Señal Perdida`) la primera vez.
- **Publicar (itch.io, butler):** `python tools/release.py full` construye en limpio `build/itch_windows/` (exe, pck, DLLs de Epic y README.txt bilingüe; comprueba que no haya nada más ni nada con pinta de clave), el zip `build/LostSignal-windows.zip` y guarda la base para parches; con `--push` sube a `nearq/lost-signal:windows` con `--userversion` = `application/config/version` y muestra `butler status`. `--hidden` solo en el primer push de un canal. Siempre una sola carpeta (`build/itch_windows`) y un solo zip (`build/LostSignal-windows.zip`), que se reemplazan en cada build (decisión del usuario 2026-10-26: no acumular builds); si el juego está abierto desde esa carpeta, el script pide cerrarlo. Publicadas: 0.1.0 (2026-10-25, build #2213895) , 0.2.0 (2026-10-26, build #2220662: idiomas, nombre nuevo, gráficos 960x540, inventario, puertas, flash en cooperativo, cuerpo propio y escondidos visibles) y **0.2.1** (2026-10-26: arreglos de puertas, camas, armario 3D, voz escondido) y **0.2.2** (2026-10-26, build #2221369: la sala de 2+ jugadores ya cabe en pantalla, Esc vuelve atrás) y **0.3.0** (2026-10-26, build #2222438: tele con sofá y tutorial del flash, grito de persecución humano, carrera de pie con cara gritando, puertas con montante grande, flash más débil en cooperativo, armario 3D, apagón a mitad de cintas, volúmenes) y **0.3.1** (2026-10-26: nunca atraviesa una puerta con ventana, gritos más fuertes y saturados). **Preguntar al usuario antes de cada publicación**; si dice «súbelo», publicar directo. Desde 0.4.0 hay **actualizaciones dentro del juego** (ver «Actualizaciones»): las versiones normales salen como parche; build completa en itch solo cuando hace falta. butler: `%APPDATA%/itch/broth/butler/versions/<v>/butler.exe`, con sesión ya iniciada (nunca leer ni mostrar `~/.config/itch/butler_creds`). Nota: el `.pck` lleva `eos/credentials.cfg` (las credenciales de cliente de Epic que el juego necesita para el online; son de cliente, pensadas para ir en el juego).

## Cómo evaluar una propuesta visual o jugable

Revisar el conjunto con las capturas (`--shots`) y jugando:

- ¿La casa se siente real y abandonada antes que «de terror»?
- ¿A simple vista hay tensión sin ver nada?
- ¿El visor da miedo por lo que muestra y no solo por el ruido?
- ¿Las reglas de la Visita se entienden sin explicación?
- ¿Produciría una reacción que alguien querría compartir?

La referencia de calidad es una noche corta, completa y convincente: un lugar creíble, una regla que se aprende con miedo, una televisión que da escalofríos cuando cambia y un final que deja silencio.
