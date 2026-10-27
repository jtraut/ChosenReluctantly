extends CanvasLayer
class_name Hud
## Bottom HUD: 5 card slot widgets + a health bar. Polls Player each frame -
## no signals to wire up, nothing to keep in sync by hand.

@onready var health_bar: ProgressBar = $Root/HealthPanel/HealthBar
@onready var health_label: Label = $Root/HealthPanel/HealthLabel
@onready var slot_widgets: Array[CardSlotWidget] = [
	$Root/SlotBar/Slot1, $Root/SlotBar/Slot2, $Root/SlotBar/Slot3, $Root/SlotBar/Slot4, $Root/SlotBar/Slot5,
]

var player: Player = null


func _ready() -> void:
	for i in range(slot_widgets.size()):
		slot_widgets[i].set_key_hint(str(i + 1))


func set_player(p: Player) -> void:
	player = p


func _process(_delta: float) -> void:
	if player == null:
		return
	var health := player.health
	health_bar.max_value = health.max_health
	health_bar.value = health.current_health
	health_label.text = "%d / %d" % [roundi(health.current_health), roundi(health.max_health)]

	if player.card_slots == null:
		return
	for i in range(CardSlotController.SLOT_TYPE_ORDER.size()):
		var slot_type := CardSlotController.slot_type_at_index(i)
		slot_widgets[i].update_from_slot(player.card_slots.get_slot(slot_type))
