class_name HouseMap
extends RefCounted
## Prototype house (14 Olmos St.), one character per 1 m cell (north is up):
##   # wall · W window (outer wall) · X front door (exit) · D doorway
##   U boarded doorway (crouch to pass under the boards)
##   . wood floor · , tile floor · r rug
##   k counter · t table · s sofa · b bed · w wardrobe · V television · c boxes
##   L ceiling lamp · l dead lamp · T tape spot · B battery · P player · E entity

const ROWS: Array[String] = [
	"###W######W######W####",
	"#kkk,,B#w....T#bb...w#",
	"#,,,,,,#..L...#bb.L.E#",
	"#,,L,,,D......D......#",
	"#,,tt,T#..ss..#T....c#",
	"#,,tt,,#.rrrr.###D####",
	"###D####crrrr.#,,,,,,#",
	"#w.....#.rrrrTU,,l,,,W",
	"W..L...D..V...#,,,,,T#",
	"#bb...T#....l.#,,,,kk#",
	"###U######D###########",
	"#..L.....B.....l....c#",
	"#........P..........T#",
	"####W####X#####W######",
]

## Rooms with their own wallpaper: wall faces looking into these cells.
const ZONES := {
	"wallpaper_kid": Rect2i(1, 7, 6, 3),
	"wallpaper_bed": Rect2i(15, 1, 6, 4),
}

## Hand-placed wall decor: the open cell it is seen from, the wall it hangs
## on (direction), and its texture.
const DECOR := [
	{"cell": Vector2i(2, 7), "dir": Vector2i(0, -1), "tex": "drawing"},
	{"cell": Vector2i(5, 9), "dir": Vector2i(0, 1), "tex": "drawing_scribbled"},
	{"cell": Vector2i(12, 11), "dir": Vector2i(0, -1), "tex": "drawing"},
]
