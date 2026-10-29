extends CanvasLayer
class_name DebugOverlay
## F3-toggled overlay: FPS, every slot's cooldown, and deck contents. Off by
## default - this is a diagnostic tool, not part of the normal HUD.

@onready var label: Label = $Label

var player: Player = null


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible:
		return
	var lines: Array[String] = []
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	if player != null and player.card_slots != null:
		for i in range(CardSlotController.SLOT_TYPE_ORDER.size()):
			var slot_type := CardSlotController.slot_type_at_index(i)
			var slot: CardSlot = player.card_slots.get_slot(slot_type)
			if slot == null:
				continue
			lines.append(
				"[%d] %s  cd=%.2f/%.2f  draw=%d discard=%d  current=%s  next=%s" % [
					i + 1,
					slot_type,
					slot.cooldown_remaining,
					slot.last_cooldown_duration,
					slot.draw_pile.size(),
					slot.discard_pile.size(),
					_card_label(slot.current_card_id),
					_card_label(slot.preview_card_id()),
				]
			)
		var deck_check := player.card_slots.deck_check()
		lines.append("Unique cards (have/need):")
		lines.append_array(deck_check.summary_lines())
	label.text = "\n".join(lines)


## "id (Full Name)" so names the HUD had to shrink or truncate are still readable here.
func _card_label(card_id: String) -> String:
	if card_id == "":
		return "-"
	var card_name := str(CardDatabase.get_card(card_id).get("name", ""))
	return "%s (%s)" % [card_id, card_name] if card_name != "" else card_id
