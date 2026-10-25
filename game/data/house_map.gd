class_name HouseMap
extends RefCounted
## Prototype house (14 Olmos St.), one character per 1 m cell (north is up):
##   # wall · X front door (exit) · . wood floor · , tile floor · D doorway
##   k counter · t table · s sofa · b bed · w wardrobe · V television
##   L ceiling lamp · l dead lamp · T tape spot · B battery · P player · E entity

const ROWS: Array[String] = [
	"######################",
	"#kkk,,B#w....T#bb...w#",
	"#,,,,,,#..L...#bb.L.E#",
	"#,,L,,,D......D......#",
	"#,,tt,T#..ss..#T.....#",
	"#,,tt,,#......###D####",
	"###D####......#,,,,,,#",
	"#w.....#.....TD,,l,,,#",
	"#..L...D..V...#,,,,,T#",
	"#bb...T#....l.#,,,,kk#",
	"###D######D###########",
	"#..L.....B.....l.....#",
	"#........P..........T#",
	"#########X############",
]
