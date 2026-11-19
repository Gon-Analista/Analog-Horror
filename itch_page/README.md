# Página de itch.io: Lost Signal - Analog Horror

Todo lo necesario para dejar lista la página https://nearq.itch.io/lost-signal.
Abre **`preview.html`** para ver cómo quedaría. Con el botón de arriba cambias entre la página del juego y la portada tal como sale en el catálogo, y entre escritorio y móvil.

> Si el navegador bloquea las imágenes al abrirlo con doble clic, sírvelo desde la carpeta: `python -m http.server 8766` y abre http://127.0.0.1:8766/preview.html.

## Contenido

| Archivo | Para qué |
|---|---|
| `assets/cover_630x500.png` | **Portada** (Edit game → *Cover image*). Hay una versión al doble, `cover_1260x1000.png`; súbela si itch la acepta, se ve mejor en pantallas nítidas. |
| `assets/banner_960.png` | **Banner** (Edit theme → *Banner*). Es transparente y sustituye al título de la página. |
| `assets/background_2560x1440.jpg` | **Fondo** (Edit theme → *Background*): el pasillo casi a oscuras, detrás de la columna. |
| `assets/screenshots/01…09.png` | **Capturas** (Edit game → *Screenshots*), en este orden. Las 3 primeras son las que más se ven. |
| `assets/gifs/*.gif` | GIFs para meter en la descripción: `only_the_camera` y `the_show_goes_wrong`. |
| `description.html` | Texto de la descripción, en inglés arriba y en español abajo. |
| `preview.html` | La simulación. Se genera a partir de `preview_template.html` y `description.html`. |

## 1. Edit game (panel de itch → tu juego → Edit)

| Campo | Valor |
|---|---|
| Title | `Lost Signal - Analog Horror` |
| Project URL | `lost-signal` (ya está) |
| Short description or tagline | `Channel 9 is still on the air. Bring a camcorder and up to three friends.` |
| Classification | Games |
| Kind of project | Downloadable |
| Release status | **In development**: la pantalla final dice «demo». |
| Pricing | **$0 or donate**, con *suggested donation* de $2. Gratis da más jugadores y más streamers, que es lo que recomienda `Investigacion_viralidad.md`. |
| Uploads | `LostSignal-windows.zip` ya está subido con butler (canal `windows`). Comprueba que tenga marcado **Windows** y nada más. |
| Description | Ver «Descripción», más abajo. |
| Genre | Survival (itch no tiene «Horror» como género: va en las etiquetas). |
| Tags (máx. 10) | `horror`, `analog-horror`, `co-op`, `multiplayer`, `first-person`, `found-footage`, `psychological-horror`, `vhs`, `scary`, `creepy` |
| AI generation disclosure | Contesta tú. Las texturas, el audio y los modelos salen de los scripts de `tools/` (generación procedural), pero si usaste IA generativa en algo (imágenes de referencia, voces, textos…), márcalo. |
| App store links | Vacío. |
| Custom noun | Vacío. |
| Community | **Comments** activado. |
| Visibility | **Public** cuando esté todo. Antes, *Draft* o *Restricted* para revisarla. |

**Metadata** (Edit game → *Metadata*, más abajo):

| Campo | Valor |
|---|---|
| Average session | About a half-hour (cada noche dura entre 15 y 20 minutos) |
| Languages | English, Spanish |
| Inputs | Keyboard, Mouse |
| Multiplayer | Ad-hoc networked multiplayer · Player count 1 – 4 |
| Accessibility | Ninguna marcada |

**Install instructions** (en *Edit game*, cuando el canal es descargable):

> Unzip and run LostSignal.exe. If Windows SmartScreen warns you, click "More info → Run anyway" (the game is not signed yet). Updates are installed from inside the game.

## 2. Edit theme (abre la página del juego estando conectado → *Edit theme*)

| Opción | Valor |
|---|---|
| Background | `#060607` + imagen `background_2560x1440.jpg`, centrada arriba, sin repetir |
| Background 2 (la columna) | `#0e0e11` |
| Text | `#cfcdc4` |
| Link | `#f5c542` (el ámbar del juego) |
| Button | `#d6342c` (el rojo del REC) |
| Border | `#2a2a30` |
| Fuente del texto | La primera de esta lista que salga en el desplegable: **IBM Plex Mono** → Space Mono → Roboto Mono → Source Code Pro → Courier Prime → Inconsolata. Si no hay ninguna monoespaciada, **Lato** (la de itch, se lee bien). |
| Fuente de los títulos | La primera que salga: **VT323** (la del juego) → Silkscreen → Share Tech Mono → Press Start 2P (muy ancha: solo si no hay otra) → la misma del texto. |

> La lista de fuentes del editor de itch es limitada y cambia con el tiempo. El título ya va dentro del banner, así que la fuente de los títulos solo afecta a los encabezados de la descripción («▶ THE NIGHT»…). Cuando sepas cuáles has elegido, cámbialas en `preview_template.html` (`--font-body` y `--font-head`, y la línea de Google Fonts) y regenera la vista previa.
| Banner | `banner_960.png`, centrado |
| Screenshots | En la columna de la derecha |

Si cambias un color aquí, cámbialo también en `preview_template.html` (variables `:root` del principio) y regenera la vista previa para que se parezca.

## 3. Descripción

1. Abre `description.html` en el navegador (o `preview.html`).
2. Selecciona el texto, desde «October 14, 1989» hasta el final de la parte en español, y pégalo en el editor de la descripción de itch. Se mantienen las negritas, las listas, la cita y la tabla.
3. Los 2 GIFs no se copian: en el editor de itch, pon el cursor donde va cada uno y usa el botón de imagen para subirlo:
   - `only_the_camera.gif`: arriba del todo.
   - `the_show_goes_wrong.gif`: al final de la lista de «THE NIGHT».
4. Revisa los títulos (▶ THE NIGHT, etc.). Si el editor los pegó como texto normal, márcalos como *Heading 2*.

## 4. Antes de hacerla pública

- [ ] Portada, capturas, banner, fondo y colores puestos. Mira la página real en el móvil.
- [ ] Descarga el zip desde la página en otra PC (o en una carpeta limpia) y juega una partida online con alguien.
- [ ] Release status *In development*, precio *$0 or donate*.
- [ ] Pública. Luego, primer **devlog** (*Edit game → Devlog*): «Lost Signal 0.4.0: the first night», con `the_show_goes_wrong.gif`.

## Para difundir (textos cortos)

- **X / Bluesky (EN):** `📼 Lost Signal is a free online co-op analog horror game for 1–4 players (alpha). Raise the camcorder... it's right there. nearq.itch.io/lost-signal #analoghorror #indiegame` + `only_the_camera.gif`
- **TikTok / Shorts:** el clip de «a simple vista vacío → cámara → está ahí» (como `only_the_camera.gif`).
- **Reddit** (r/analoghorror, r/IndieGaming, r/HorrorGaming): título `I made a free co-op horror game where the monster only shows up on a VHS camcorder` + GIF. Lee las reglas de cada sub sobre autopromoción.

## Regenerar

Las imágenes se sacan de capturas del juego, con el HUD en inglés:

```
godot --path game -- --shots <carpeta> --seed 7 --lang en
godot --path game -- --smoke --lang en --pilot-shot <carpeta>
python tools/gen_itch_page.py <carpeta>      # imágenes + preview.html
python tools/gen_itch_page.py --pages        # solo preview.html (tras editar description.html)
```
