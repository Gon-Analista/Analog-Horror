class_name Tuning
extends RefCounted
## Feel and balance numbers of the prototype, in one place so they are not
## scattered through the logic (dev_guidelines §4).

# Physics layers (bit values).
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_INTERACT := 4
## The boards nailed across doorways: bodies bump into them (you crouch
## under), but eyes, cameras and flashes go through the gaps between them.
const LAYER_BOARDS := 8

# Player
const WALK_SPEED := 2.6
const SPRINT_SPEED := 4.2
const FILM_SPEED := 1.7
const CROUCH_SPEED := 1.3
const STAND_HEIGHT := 1.55
const CROUCH_HEIGHT := 0.9       # passes under the boarded doorways (boards from 1.0 m)
const CROUCH_EYE := 0.7
const JUMP_VELOCITY := 3.4       # a little hop (a step, a doorstep)
const ACCEL := 18.0
const DECEL := 22.0
const MOUSE_SENS := 0.0022
const FOV := 75.0
const FILM_FOV := 52.0
const INTERACT_RANGE := 2.0
const SEAT_FOV := 22.0            # sat watching the TV, the view narrows onto it
const SEAT_EYE := 1.0             # eye height sat on the sofa
const READ_RANGE := 2.5          # walking further closes the broadcast

# Camcorder
const CAMCORDER_RAISE_TIME := 0.22
const BATTERY_DRAIN := 2.8       # % per second while filming (a full battery: ~36 s)
const BATTERY_PICKUP := 45.0     # % restored by a battery
const ROOMS_PER_BATTERY := 5     # one more battery in the house for every this many rooms
const FILM_RANGE := 22.0         # metres at which the camcorder still sees it
const FLASH_RANGE := 12.0        # metres the camcorder's flash reaches
const FLASH_SLACK := 1.3         # the flash lights a bit beyond the frame
const DOOR_CHANCE := 0.75         # doorways that get a door
const TRANSOM_CHANCE := 0.85     # of those, with a broken window over them (the entity goes through it)
const DOOR_OPEN_CHANCE := 0.45   # doors that start open
const FLASH_BLIND_TIME := 2.2    # a friend's flash in your eyes: white for this long
const ENTITY_SONG := false        # its music box tune near it (off for now: user 2026-10-26; the code stays)
# Its soot (EntitySoot): an aura only the camcorder sees, and marks on the floor.
## The marks on the floor are seen with the naked eye too: the one trace it
## leaves in the real world, like the bodies (a proposal: false keeps them
## for the camcorder only).
const SOOT_NAKED_EYE := true
const SOOT_SETTLE := 1.4          # a print shows this long after it passed (where it was, not where it is)...
const SOOT_LIFE := 50.0           # ...and is gone after this long
const SOOT_MARKS := 56            # prints on the floor at once (the oldest go first)
const SOOT_STEP := 0.62           # one footprint every this many metres walking...
const SOOT_HAND_STEP := 0.8       # ...one handprint on all fours
const SOOT_AURA := 128            # smoke puffs alive at once around it
const VOICE_THROW_CHANCE := 0.0   # its voice coming from another room (off: it was confusing)
const HIDDEN_VOICE_RAW := 22      # hidden, a voice this loud (mic RMS x1000) gives you away; quieter does not
const PEEK_TIME := 2.0           # found hiding: it shows its face this long before it takes you
const AMBUSH_TIME := 14.0        # a director's ambush waits this long at most
const CAMP_MAX := 16.0           # lying in wait more than this lately: it goes looking instead
const RAGE_SNIFF_EVERY := 7.0    # enraged: it goes to sniff around somebody this often
const RAGE_HEARING := 1.5        # enraged: it hears this much further
const FLASH_COST := 20.0         # % of battery per flash
const FLASH_COST_COOP := 30.0    # ...in company (several camcorders between you)
const FLASH_COOLDOWN := 3.0      # seconds to recharge between flashes
const FLASH_COOLDOWN_COOP := 6.0 # ...in company
const FLASH_IMMUNE := 1.5        # after a flash, another one does nothing for this long
const FLASH_IMMUNE_PER_FRIEND := 4.0  # ...plus this per other player alive (no chain-flashing)
const FLASH_STAGGER := 1.2       # enraged, a flash only stuns it this long
const FLEE_TIME := 6.0           # it runs from the flash at most this long...
const FLEE_SPEED_MULT := 3.6     # ...on all fours, very fast...
const RECOVER_MIN := 6.0         # ...then lies low, silent, this long before it comes back
const RECOVER_MAX := 12.0
const GALLOP_SPEED_MULT := 1.35  # (on all fours: only fleeing the flash now)
const CHASE_MIN_SPEED := 2.8      # ...but never slower than this (a little faster than you walk)
const CHASE_SPEED_MULT := 1.75   # chasing you it runs, upright (2.5 m/s at first: faster than filming, slower than sprinting)

# Entity
const ENTITY_SPEED := 1.25
const ENTITY_SPEED_PER_TAPE := 0.3
const ENTITY_UNSEEN_MULT := 1.6  # nobody even looks its way
const ENTITY_WAKE_TIME := 120.0  # the alert cuts in by itself after this
const TV_DISTURB_AT := 2.5       # seconds watching the show before it starts going wrong
const TV_DISTURB_TIME := 6.0     # ...and how long it takes to go wrong before the alert
const ALERT_GRACE := 20.0        # time to read the alert before it wakes (if you keep reading)
const ENTITY_KILL_RANGE := 0.95
const WAKE_GRACE := 10.0         # after it wakes (far from everyone): this long without a sound
const FLICKER_RANGE := 6.0       # lamps start failing this close to it
const FLASHLIGHT_FAIL_RANGE := 4.0
const STATIC_RANGE := 9.0        # viewfinder interference

# Solo (playing alone is harder: nobody films it while you search)
const SOLO_BATTERY_MULT := 0.5   # drain multiplier: twice the battery life
const SOLO_ENTITY_SPEED_MULT := 0.9
const SOLO_PICKUP_RADIUS := 1.4  # E picks up what you stand next to, without aiming

# Entity behaviour
const FOLLOW_FAR := 6.0          # following: catches up from further than this...
const FOLLOW_STRIKE := 2.2       # ...and lunges from closer than this
const LONE_RANGE := 7.0          # nobody else this close: "alone"

# Entity senses: it only knows where you are if it sees or hears you
const SIGHT_DARK := 6.0          # metres it sees you with your flashlight off...
const SIGHT_LIGHT := 14.0        # ...and on (it sees the light)
const SIGHT_CROUCH_MULT := 0.6   # crouched, you are harder to make out
const SIGHT_CONE := 0.34         # cos of half its field of view (~140 degrees)...
const SIGHT_FEEL := 2.5          # ...but this close it notices you from any side
const TABLE_SIGHT := 2.5         # under a table, it sees you from this close (or by your light)
const HEAR_RUN := 11.0           # steps through the house (along corridors, not through walls)
const HEAR_WALK := 4.5
const HEAR_CROUCH := 1.2
const HEAR_VOICE := 9.0          # talking (proximity voice)
const NOISE_PICKUP := 7.0        # taking a tape or a battery
const NOISE_CAMERA := 4.0        # dropping or picking up the camcorder
const MEMORY := 12.0             # seconds a clue stays worth following
const LOSE_AFTER := 2.5          # out of its sight this long, the chase becomes a search
const SEARCH_TIME := 25.0
const WANDER_SPEED_MULT := 0.75
const SEARCH_SPEED_MULT := 0.85
const DIRECTOR_PATIENCE := 9.0  # seconds without it near anyone before the director steps in...
const DIRECTOR_PATIENCE_MIN := 5.0  # ...down to this with the last tapes
const CORNER_PATIENCE := 7.0
const HIDE_MIN_DIST := 3.5       # it never sets up to wait closer than this to anyone
const CEILING_WALK_CHANCE := 0.3 # each stretch it roams, the chance it does it on the ceiling     # lying in wait this long with nobody coming: it moves closer
const FOUND_OUT_STARE := 2.0     # caught on camera lying in wait: it stares this long, then shrieks...
const FURY_TIME := 8.0           # ...and comes for you this long...
const FURY_SPEED_MULT := 1.35    # ...this much faster
const BURST_TIME := 1.5          # and the first moments of that charge...
const BURST_SPEED_MULT := 2.4    # ...far faster still, to catch you off guard
const STALK_SPEED_MULT := 2.6    # stealth: silent and fast up behind you...
const STALK_DISTANCE := 0.9      # ...this far behind your back...
const STALK_REACTION := 0.35     # ...turn round and see it: this long, then it has you...
const STALK_LIMIT := 5.0         # ...don't turn round: it has you anyway after this

# Voice
const VOICE_LURE_TIME := 1.5     # it goes for whoever spoke in the last seconds...
const VOICE_LURE_MULT := 0.55    # ...as if they were this much closer

# Run
const TAPES_DEFAULT := 5         # the host picks 5-12 in the lobby (HouseGenerator)
const TV_CORRUPT_AT := 3         # tapes taken when the broadcast turns
const RAGE_HOLD := 1.2           # with all the tapes taken, filming only holds it this long
const RAGE_SPEED_MULT := 1.2     # ...and then it comes a little faster
const BLACKOUT_AT := 2           # tapes taken when the power goes (all but the exit's lamp)
const CAMCORDER_COOLDOWN := 0.35
## One camcorder per two players (true) or one each (false, for now: the
## user wants everyone to have one in co-op while the game is tested).
const SCARCE_CAMERAS := false  # after lowering the camcorder, before it can go up again

# "La Visita es un jugador" (versus): one player controls it (EntityPilot).
# Balance: in a straight line the crew outruns it (4.2 against a 3.5 s
# burst of 4.8 and a lunge); it wins by stealth, the ceiling, dead ends and
# doors; the flash and hiding are the crew's answers.
const PILOT_WALK := 2.3
const PILOT_SNEAK := 1.1          # C, crouched: silent steps, under the boards (and the breath on your neck)
const PILOT_SPRINT := 4.6         # SHIFT, running: fast, loud steps, but no scream (that is the charge)...
const PILOT_STAMINA := 3.5        # ...for this many seconds...
const PILOT_STAMINA_REGEN := 0.45 # ...back at this much a second (~8 s empty to full)
const PILOT_SPEED_PER_TAPE := 0.03  # each tape taken: this much faster (fraction)
const PILOT_CEILING_SPEED := 2.0
const PILOT_CLIMB_TIME := 0.6     # up to (or down from) the ceiling, not moving
const PILOT_CEILING_COOLDOWN := 0.8
const PILOT_CHARGE_TIME := 1.3    # the attack: a screaming charge, this long...
const PILOT_CHARGE_SPEED := 5.4   # ...this fast (it steers with the view)...
const PILOT_ATTACK_COOLDOWN := 3.0  # ...then this long before the next
const PILOT_GRAB_RANGE := 1.6     # ...and whoever is this close in front at the end is taken
const PILOT_DROP_RANGE := 1.5     # dropping from the ceiling onto someone below
const PILOT_MISS_TIME := 1.3      # a missed grab: this long slowed...
const PILOT_MISS_SLOW := 0.3      # ...to this
const PILOT_AFTER_MEAL := 1.5     # after a catch: this long slowed (on top of the catch itself)
const PILOT_STUN := 2.5           # the flash: blinded and crawling this long...
const PILOT_STUN_ENRAGED := 1.2
const PILOT_STUN_SLOW := 0.35
const PILOT_FLASH_IMMUNE := 8.0   # ...then the next flashes do nothing for this long
const PILOT_SENSE_COOLDOWN := 35.0  # Q: it feels where everyone is...
const PILOT_SENSE_TIME := 3.0       # ...for this long (the hidden only if they talk)
const PILOT_SENSE_RANGE := 22.0
const PILOT_SCREAM_COOLDOWN := 8.0  # its shriek when it breaks into a run
const PILOT_SEARCH_RANGE := 2.2
const PILOT_SEARCH_COOLDOWN := 2.5
const PILOT_EYE := 1.85
const PILOT_SNEAK_EYE := 0.85
const PILOT_FOV := 85.0
const PILOT_FOG := 0.14           # its sight fades into red past ~6 m (it saw too much)
const PILOT_HEAR_RUN := 14.0      # it hears (a red ring, through walls) running this far...
const PILOT_HEAR_VOICE := 12.0    # ...talking...
const PILOT_HEAR_SOUND := 18.0    # ...and things (tapes, doors, flashes, camcorders)
