class_name Inventory
extends RefCounted
## What a player carries: one thing in each hand (that is what works: the
## flashlight lights only in a hand, the camcorder films only from a hand)
## and a few more in the bag. Local to each player; what the hands hold is
## replicated by Player (net_left / net_right) for the others to see.
## Items are ids (strings): "flashlight", "camcorder"... ("" = empty).

signal changed

const BAG_SIZE := 6
const HANDS: Array[String] = ["left", "right"]
## Icon cell in items.png (tools/gen_items.py) for each item.
const ICONS := {"": 0, "flashlight": 1, "camcorder": 2, "battery": 3, "tape": 4}
const ICON_SIZE := 32

var left := ""
var right := ""
var bag: Array[String] = []


func _init() -> void:
	bag.resize(BAG_SIZE)
	bag.fill("")


## Its name for the player (tooltips, the toolbar).
static func item_name(item: String) -> String:
	match item:
		"flashlight":
			return TranslationServer.translate("Linterna")
		"camcorder":
			return TranslationServer.translate("Videocámara")
		"battery":
			return TranslationServer.translate("Batería")
	return ""


## Its icon: the region of items.png.
static func icon_region(item: String) -> Rect2:
	return Rect2(int(ICONS.get(item, 0)) * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)


## Slots: "left", "right", "bag0" ... "bag5".
func get_slot(slot: String) -> String:
	match slot:
		"left":
			return left
		"right":
			return right
	return bag[int(slot.substr(3))]


func set_slot(slot: String, item: String) -> void:
	match slot:
		"left":
			left = item
		"right":
			right = item
		_:
			bag[int(slot.substr(3))] = item


func slots() -> Array[String]:
	var out: Array[String] = ["left", "right"]
	for i in BAG_SIZE:
		out.append("bag%d" % i)
	return out


func in_hand(item: String) -> bool:
	return item != "" and (left == item or right == item)


func has(item: String) -> bool:
	return in_hand(item) or bag.has(item)


func count(item: String) -> int:
	return bag.count(item) + int(left == item) + int(right == item)


## Spare batteries only go in the bag: nothing to hold them for.
func can_swap(a: String, b: String) -> bool:
	return not (HANDS.has(a) and get_slot(b) == "battery") and not (HANDS.has(b) and get_slot(a) == "battery")


## Moves what is in `a` to `b` and the other way round.
func swap(a: String, b: String) -> void:
	if a == b:
		return
	var item := get_slot(a)
	set_slot(a, get_slot(b))
	set_slot(b, item)
	changed.emit()


## Into a free hand (the right first) or else the bag. The slot it went
## to, or "" if there was no room.
func add(item: String, prefer := "right") -> String:
	var order: Array[String] = [prefer, "left" if prefer == "right" else "right"]
	for i in BAG_SIZE:
		order.append("bag%d" % i)
	for slot in order:
		if get_slot(slot) == "":
			set_slot(slot, item)
			changed.emit()
			return slot
	return ""


## Into the bag. False if it is full.
func add_to_bag(item: String) -> bool:
	var i := bag.find("")
	if i < 0:
		return false
	bag[i] = item
	changed.emit()
	return true


func remove(item: String) -> void:
	for slot in slots():
		if get_slot(slot) == item:
			set_slot(slot, "")
			changed.emit()
			return
