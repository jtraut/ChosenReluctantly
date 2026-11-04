class_name CombatEventsRelay
extends Node
## Autoload (named CombatEvents; the class_name is CombatEventsRelay so code that must also compile in a `-s` script
## run without autoloads, like the bot-sim, can type it and find it through CombatLink). A relay for combat events (no game state of its own beyond a short cast history and a game clock), so
## systems that care about what just happened (effect conditions now, relics in BD2) listen here instead of wiring
## to each other. Only `card_cast` exists so far; the other relay events are BD2's.
##
## The clock is game time (this node's _process delta), so it respects pause and hit-stop slow-mo, and a seeded
## sim repeats. `reset()` runs when a scene (run, room, arena) loads and on a restart.

## A card was cast: its slot type, card id, and tags (derived + keywords, see CardTags). Emitted after the card's
## effects ran, next to CardSlotController.card_cast.
signal card_cast(slot_type: String, card_id: String, tags: Array[String])

var history := CastHistory.new()
var _now: float = 0.0


func _process(delta: float) -> void:
	step(delta)


## Advances the game clock by `delta`. _process calls it every frame; a headless sim that runs ticks without frames (the
## bot-sim) calls it itself, so its casts get real timestamps.
func step(delta: float) -> void:
	_now += delta


## Game seconds since the last reset.
func now() -> float:
	return _now


## Records the cast into the history and emits card_cast. CardSlotController calls this after the effects ran, so
## a card's own conditions never see its own cast.
func notify_card_cast(slot_type: String, card_id: String) -> void:
	var tags: Array[String] = CardDatabase.tags_for(card_id)
	history.record(_now, slot_type, card_id, tags)
	card_cast.emit(slot_type, card_id, tags)


## The player dodged. D39: by default (data/player.json dodge.counts_as_movement_cast false) nothing happens, because the dodge
## is a pure escape and is not a Movement cast. With the flag on it enters the history as a Movement cast (card id "dodge"),
## so cast_within conditions see it. This is the only place the rule lives; Player just reports the dodge.
func notify_dodge() -> void:
	if PlayerConfig.dodge_counts_as_movement_cast():
		history.record(_now, "movement", "dodge", ["Dash"] as Array[String])
		card_cast.emit("movement", "dodge", ["Dash"] as Array[String])


func reset() -> void:
	history.clear()
	_now = 0.0
