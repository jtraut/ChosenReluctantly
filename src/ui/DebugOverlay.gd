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
					slot.current_card_id if slot.current_card_id != "" else "-",
					slot.preview_card_id() if slot.preview_card_id() != "" else "-",
				]
			)
	label.text = "\n".join(lines)
