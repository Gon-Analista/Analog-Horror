# Guías de desarrollo: Analog Horror (título provisional)

Estas reglas orientan cambios de código, escenas, contenido y recursos. Léelas junto con `Informe_terror_analogico.md` y `.agents/project_context.md`.

## 1. Prioridades del proyecto

- Respeta el ADN de `project_context.md`: el juego debe parecer evidencia, no una película de terror. Si falta una decisión, elige la opción más pequeña que acerque a una vertical slice online jugable y que dé miedo en grupo.
- Prefiere una partida corta y completa a añadir sistemas que todavía no mejoran el loop principal.
- La estética VHS/pixel es una herramienta. No resuelvas un problema de tensión o de idea subiendo efectos; resuélvelo en diseño, ritmo, sonido o información.
- Evita añadir dependencias, servicios, plugins o arquitecturas nuevas si Godot, EOS y el código existente resuelven el problema.
- Las decisiones de concepto, monstruo, lore y tono las toma el usuario. Si propones algo, márcalo como propuesta.

## 2. Estructura y arquitectura

- El proyecto de Godot está en `game/`; abre y ejecuta esa carpeta, que contiene `project.godot`. La raíz guarda documentación (`.agents/`, informe) y herramientas (`tools/`).
- Usa Godot 4.7.2 y GDScript salvo que el usuario decida cambiar la tecnología. Tipado estático (`var x: int`, retornos tipados) siempre que ayude a evitar inferencias ambiguas.
- Organización: `game/scenes/` (escenas; `dev/` para pruebas), `game/scripts/core/` (estado de la partida, entrada, audio), `world/` (casa, objetos, luces), `player/`, `entity/`, `ui/` (presentación), `net/` (red y EOS), `dev/` (pruebas automáticas), `game/shaders/`, `game/assets/` (texturas, audio), `game/data/` (balance y mapas), `game/locale/` (traducciones). El detalle de cada archivo está en `project_context.md` («Tecnología»).
- Los nodos que un diseñador querría ajustar en el editor (cámara, linterna, entorno, sonidos de la entidad) viven en escenas `.tscn`. Lo que se genera a partir de datos (la casa desde el mapa ASCII, los placeholders de primitivas) se construye por código.
- Cada sistema tiene una responsabilidad concreta: jugador, interacción, tareas/procedimiento, anomalías, director de tensión, red, voz, UI. No crees un `main.gd` que lo haga todo.
- Haz cambios locales y coherentes con los patrones ya usados. No reformatees ni renombres archivos ajenos al cambio.
- Usa rutas `res://` / `user://`. No dejes rutas absolutas del PC en runtime.
- Mantén scripts y datos en UTF-8 y comprueba que los acentos de textos visibles no se corrompan.

## 3. Red y online (regla central)

- **Todo se construye para online desde el principio.** Jugar solo será una sesión online de un jugador por la misma ruta de código.
- El online ya existe: `Net` (sesión), `Run` (eventos del anfitrión por RPC) y `MultiplayerSynchronizer` en jugadores, Visita y tele. Toda mecánica nueva debe decidir quién es su autoridad, qué se replica y qué es solo presentación local, y probarse con `--net-test` o con dos ventanas en red local.
- **Host autoritativo:** el host decide el estado de la partida, las tareas, las anomalías, la IA, los daños, las muertes y las tiradas aleatorias. Los clientes envían intenciones (moverse, interactuar, usar) y reciben estado. No confíes en un valor calculado por un cliente para algo que afecte a otros.
- **Aleatoriedad replicable:** las variaciones de cada partida (qué instrucción se corrompe, qué anomalía aparece, a quién afecta) salen de una semilla del host. Si un efecto es solo visual y local, debe estar claro que es local.
- **Asimetría deliberada:** cuando un jugador deba ver u oír algo que los demás no perciben (un pilar del diseño), hazlo explícito en el código (RPC dirigido a ese peer) y documenta por qué. Nunca dependa de una desincronización accidental.
- Usa la API de multijugador de alto nivel de Godot (`MultiplayerAPI`, `MultiplayerSpawner`, `MultiplayerSynchronizer`, RPC) sobre el peer de EOS P2P. Mantén un **peer ENet local de desarrollo** para lanzar varias instancias en el mismo PC sin EOS; el juego no debe depender de él en builds de lanzamiento.
- Sincroniza solo lo necesario y con la frecuencia adecuada: transformaciones del jugador interpoladas, eventos de juego por RPC fiable, nada de sincronizar cada frame valores que se pueden derivar.
- Gestiona siempre: unirse a mitad de partida (o impedirlo explícitamente), desconexión de un cliente, caída del host (fin limpio de la partida y vuelta al lobby), latencia y pérdida de paquetes. Ningún estado debe quedar colgado.
- **EOS** (`epic_sdk/`, C SDK 1.19.1, no se sube a git): Connect para identidad (sin obligar a cuenta de Epic), Lobbies para crear/buscar/invitar, P2P con relé para el transporte, RTC para voz. Toda llamada a EOS pasa por la capa `game/scripts/net/`; el resto del juego no llama al SDK directamente.
- Las credenciales del producto viven en `game/eos/credentials.cfg` (ignorado por git). No las escribas en código, escenas, logs ni mensajes.
- **Voz por proximidad:** el volumen de cada participante se ajusta según distancia y oclusión desde la capa de voz; los equipos diegéticos (radios, intercomunicadores) pueden enrutar la voz. Silenciar, ajustar volumen y push-to-talk deben existir desde la primera versión con voz.

## 4. Datos y contenido

- Centraliza balance, tiempos, definiciones de tareas, instrucciones del procedimiento y anomalías en recursos de datos (`game/data/`, `Resource` o diccionarios dedicados); evita números mágicos repartidos por la lógica.
- Al añadir una tarea, anomalía, documento o evento, completa su ciclo: definición, comportamiento en el host, replicación, presentación (visual y sonora), traducción y prueba en red.
- Mantén consistentes los identificadores entre datos, escenas, red y guardado. Usa identificadores estables en minúsculas con guion bajo.
- **Lore con respuestas:** toda pista, documento, fecha o anomalía debe encajar con `.agents/lore.md` (por crear). No añadas rarezas sin relación con el misterio de fondo.
- Conserva placeholders identificados como tales. No sustituyas silenciosamente arte, audio o texto final por contenido temporal.

## 5. Recursos, arte y audio

- Pixel art en 3D: renderiza a la resolución interna definida en el proyecto y escala con factor entero y filtrado nearest. Las texturas importan con filtro nearest; revisa mipmaps para que no emborronen.
- Geometría low-poly y texturas pequeñas coherentes entre sí (misma densidad de píxeles por unidad de mundo). Anota en `project_context.md` la escala de mundo y la densidad elegidas cuando se fijen.
- Los efectos VHS/CRT se implementan como post-proceso configurable por intensidad y controlado por el director de tensión, no fijos al máximo.
- La oscuridad debe ser real pero jugable: revisa siempre en una pantalla normal y en una captura de stream comprimida que lo importante se distingue cuando el diseño lo pide.
- Alinea sonido, animación y evento. Cuida volumen, repetición y mezcla para que la voz de los compañeros se oiga sobre el ambiente.
- Todo audio y música debe ser original o con licencia que permita streaming y monetización sin reclamaciones. Registra el origen y licencia de cada recurso externo.
- Al añadir assets, revisa dimensiones, pivote, escala, orientación, colisión, transparencia y lectura en la escena real. No basta con que el archivo exista.

## 6. Jugabilidad, tensión y feedback

- Los controles en primera persona deben sentirse inmediatos (ratón sin aceleración, sensibilidad configurable, FOV configurable). La incomodidad debe venir de la ficción, no del control.
- La tensión crece de forma comprensible siguiendo la curva normalidad → anomalía → evidencia → patrón → implicación → silencio. Ninguna escalada sin propósito de diseño.
- Los jumpscares son excepciones contadas y ganadas. Antes de añadir uno, comprueba que la tensión previa existe y que después hay silencio.
- Cada interacción necesita feedback claro (visual o sonoro) para que el jugador sepa que actuó; la ambigüedad se reserva para la anomalía, nunca para el control.
- Respeta lobby, inicio, pausa (en online no pausa el mundo), muerte/espectador, final de partida y vuelta al lobby. No dejes estados, menús superpuestos o datos residuales al cambiar de pantalla.
- Piensa en el directo: lo que ocurre debe poder entenderse viéndolo en un stream, y las situaciones deben provocar que los jugadores hablen entre sí.

## 7. UI y accesibilidad de lectura

- **El texto se dibuja a la resolución real de la ventana, nunca dentro del SubViewport pixelado** (allí no se lee). Fuente del proyecto: VT323. Tamaño mínimo 13 en coordenadas base (unos 39 px en pantalla a 1440×810), con contorno o fondo cuando va sobre la escena.
- HUD mínimo; la información preferentemente diegética (pantallas, papeles, radios, luces). Lo que sea UI pura (menús, ajustes, lobby) mantiene la estética de material institucional de época.
- Los textos que el jugador debe leer (manual, instrucciones) tienen que ser legibles a la resolución interna; si no, se muestran en primer plano al interactuar.
- Ajustes mínimos desde el principio: sensibilidad, FOV, volúmenes (general, efectos, voz), dispositivo de micrófono, push-to-talk, intensidad de efectos VHS/parpadeos y brillo.
- Acciones importantes navegables con teclado; mando como objetivo posterior sin romper la navegación.

## 8. Cambios y mantenimiento

- Antes de editar, localiza la escena, script o dato que realmente controla el comportamiento. Sigue el flujo desde la entrada (y su paso por la red) hasta lo que ven y oyen todos los jugadores.
- Prefiere funciones pequeñas y nombres descriptivos. Evita estado global nuevo si el sistema puede recibir los datos que necesita; no añadas señales, singletons o managers duplicados.
- Maneja recursos opcionales, fallos de EOS y valores ausentes sin bloquear el arranque; informa de errores con mensajes útiles y vinculados a lo afectado.
- No suprimas errores o avisos con silencios generales. Corrige la causa o deja una explicación concreta si el aviso es intencional.
- Mantén los cambios revisables y explica qué archivos se modificaron y cómo se comprobó (incluido si se probó con varias instancias en red).
- Cuando una decisión del usuario o un dato técnico importante quede fijado, regístralo en `project_context.md` de forma breve.

## 9. Rendimiento y optimización

El público objetivo incluye PCs modestos y streamers que juegan mientras emiten: el juego debe ir fluido en una gráfica integrada (la de desarrollo es una Intel Iris Xe).

- **La resolución interna es la primera optimización:** el 3D se renderiza a 480×270, así que el coste por píxel (niebla volumétrica, SSAO, sombras en pantalla) es bajo. No subirla sin decisión del usuario.
- **Presupuestos orientativos por fotograma:** menos de 150 draw calls y menos de 6 luces con sombra activas en pantalla. Mide siempre con F3 (overlay de rendimiento) antes y después de cambios visuales.
- **Geometría:** la arquitectura se fusiona en una malla con una superficie por material (`Level`); no añadir un nodo por pared o baldosa. Para objetos repetidos (sillas, cajas, cintas en masa) usar `MultiMeshInstance3D` o mallas fusionadas.
- **Sombras:** la casa proyecta sombras desde una copia fusionada en una sola superficie (`HouseShadow`), así que cada pasada de sombra es una llamada de dibujo y no una por material (bajó de ~310 a ~64 llamadas). Las lámparas solo activan su sombra cerca del jugador (`Level.update_shadows`, 6,5 m): una sombra omni vuelve a dibujar la casa seis veces.
- **Luces:** sombras solo en la linterna y en las lámparas que funcionan cerca del jugador; las luces decorativas, sin sombra. Usa `distance_fade` en las lámparas. Sombras duras y atlas de 2048: es más barato y encaja con el pixel art.
- **Texturas:** pequeñas, sin compresión, nearest + mipmaps (configurado en `[importer_defaults]`). Mantén una densidad de 32 px por metro.
- **Post-proceso:** una sola pasada a pantalla completa (`post.gdshader`). Añadir efectos al mismo shader con uniformes, no apilar más `ColorRect` que lean la pantalla.
- **Lógica:** nada pesado cada fotograma. Recalcula caminos con frecuencia limitada (la entidad: cada 0,25 s con BFS sobre la rejilla), evita crear objetos o arrays en `_process`, cachea recursos (`Sfx`, materiales de `Level`) y usa señales o eventos en vez de sondear cuando se pueda.
- **Red (cuando llegue):** sincroniza estado mínimo con la frecuencia mínima (ver §3).
- Si un cambio baja el rendimiento, indícalo con las cifras de F3 (antes y después).

## 10. Criterio de terminado

Un cambio está listo cuando cumple su objetivo dentro del juego, **funciona en una sesión online con al menos dos instancias** (host y cliente; mientras dure el prototipo para un jugador, al menos sin romper la separación autoridad/presentación), mantiene la identidad de terror analógico, no introduce errores de arranque y no rompe el flujo de la partida. Comprobación mínima: `--smoke` sin fallos y, si el cambio es visual, revisar `--shots`. Si algo no se pudo verificar, indícalo con precisión.

## 11. Idiomas (i18n)

- El juego se escribe en **español** (idioma fuente) y se traduce con el flujo gettext de Godot: catálogos `game/locale/<código>.po`. El **inglés es prioritario** porque la mayoría de los grandes creadores de terror juegan en inglés.
- **Todo texto visible al jugador pasa por `tr()`** con el texto español literal como msgid: `tr("Cerrar")`. En funciones `static`, `TranslationServer.translate("...")`. No traducir ids, claves de guardado, nombres de nodos, rutas ni líneas de depuración.
- Formato: traducir la plantilla y después formatear: `tr("Turno %s") % valor`, nunca `tr("Turno %s" % valor)`. No concatenar fragmentos traducidos; una sola plantilla con marcadores. Plurales con `tr_n`.
- El texto diegético (manuales, alertas, carteles) también se traduce. Si está horneado en una textura, generar una variante por idioma con *translation remaps*, o mejor dibujarlo en tiempo real.
- Las voces grabadas o sintetizadas necesitan versión por idioma o subtítulos; planificarlo al añadir cada línea.
