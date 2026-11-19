class_name TvShow
extends RefCounted
## The tape of ¡Te estoy viendo! as a running order: which frame of
## tv_show.png (tools/gen_tv.py, same order) and which caption at each
## moment of the programme. A hide-and-seek show for children: peekaboo,
## "close your eyes and count with me", "ready or not, here I come",
## "where are you?", and once, the set left empty. Used by the TV, the
## menu's television and the escape screen.

const SHEET := "res://assets/textures/tv_show.png"
const SEALS := "res://assets/textures/tv_seal.png"
const FRAME := Vector2i(320, 240)

const COVER_A := 0
const COVER_B := 1
const PART := 2
const OPEN_A := 3
const OPEN_B := 4
const LEAN := 5
const STATIC_A := 6
const STATIC_B := 7
const COUNT_1 := 8   # ...to COUNT_1 + 9 for ten
const READY := 18
const SEEK_A := 19
const SEEK_B := 20
const STARE := 21
const STARE_DARK := 22
const CLOSE := 23
const EMPTY := 24
const INTRUDE_A := 25  # four frames
const BARS := 29

const NUMBERS := ["UNO", "DOS", "TRES", "CUATRO", "CINCO", "SEIS", "SIETE", "OCHO", "NUEVE", "DIEZ"]  # i18n

## [seconds, frames, frames per second, caption]
static var _order: Array = []
static var _length := 0.0


## The language changed: the captions are translated again next time.
static func forget() -> void:
	_order = []


static func _build() -> void:
	if not _order.is_empty():
		return
	var peek := TranslationServer.translate("¡TE ESTOY VIENDO!")
	var where_v := TranslationServer.translate("¿DÓNDE ESTÁ VECINITO?")
	_order = [
		[1.6, [COVER_A, COVER_B], 3.0, where_v],
		[0.3, [PART], 1.0, ""],
		[1.6, [OPEN_A, OPEN_B], 3.0, peek],
		[0.9, [LEAN], 1.0, peek],
		[0.3, [PART], 1.0, ""],
		[1.6, [COVER_A, COVER_B], 3.0, where_v],
		[0.3, [PART], 1.0, ""],
		[1.8, [OPEN_A, OPEN_B], 3.0, peek],
		[2.2, [COVER_A, COVER_B], 3.0, TranslationServer.translate("CIERRA LOS OJOS Y CUENTA CONMIGO")],
	]
	for i in 10:
		_order.append([0.6, [COUNT_1 + i], 1.0, TranslationServer.translate(NUMBERS[i])])
	_order.append_array([
		[2.4, [READY], 1.0, TranslationServer.translate("QUIEN NO SE HAYA ESCONDIDO, TIEMPO HA TENIDO")],
		[3.0, [SEEK_A, SEEK_B], 2.0, TranslationServer.translate("¿DÓNDE ESTÁS?")],
		[1.5, [EMPTY], 1.0, TranslationServer.translate("¿DÓNDE ESTÁS?")],
		[1.8, [OPEN_A, OPEN_B], 3.0, peek],
	])
	_length = 0.0
	for seg: Array in _order:
		_length += seg[0]


## [frame, caption] at `t` seconds into the (looping) programme.
static func at(t: float) -> Array:
	_build()
	var x := fmod(t, _length)
	for seg: Array in _order:
		if x < seg[0]:
			var frames: Array = seg[1]
			return [frames[int(x * seg[2]) % frames.size()], seg[3]]
		x -= seg[0]
	return [OPEN_A, ""]


static func region(frame: int) -> Rect2:
	return Rect2(frame * FRAME.x, 0, FRAME.x, FRAME.y)
