class_name Tuning
extends RefCounted
## Feel and balance numbers of the prototype, in one place so they are not
## scattered through the logic (dev_guidelines §4).

# Physics layers (bit values).
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_INTERACT := 4

# Player
const WALK_SPEED := 2.6
const SPRINT_SPEED := 4.2
const FILM_SPEED := 1.7
const ACCEL := 18.0
const DECEL := 22.0
const MOUSE_SENS := 0.0022
const FOV := 75.0
const FILM_FOV := 52.0
const INTERACT_RANGE := 2.0

# Camcorder
const CAMCORDER_RAISE_TIME := 0.22
const BATTERY_DRAIN := 1.4       # % per second while filming
const BATTERY_PICKUP := 45.0     # % restored by a battery
const FILM_RANGE := 22.0         # metres at which filming still freezes it

# Entity
const ENTITY_SPEED := 1.25
const ENTITY_SPEED_PER_TAPE := 0.3
const ENTITY_UNSEEN_MULT := 1.6  # nobody even looks its way
const ENTITY_WAKE_TIME := 25.0   # wakes on the first tape or after this
const ENTITY_KILL_RANGE := 0.95
const FLICKER_RANGE := 6.0       # lamps start failing this close to it
const FLASHLIGHT_FAIL_RANGE := 4.0
const STATIC_RANGE := 9.0        # viewfinder interference

# Run
const TAPES_SPAWNED := 6
const TAPES_NEEDED := 5
const TV_CORRUPT_AT := 3         # tapes taken when the broadcast turns
