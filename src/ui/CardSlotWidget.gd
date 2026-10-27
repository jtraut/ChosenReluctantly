extends VBoxContainer
class_name CardSlotWidget
## One of the 5 bottom-HUD slot widgets: key hint, revealed card name, a
## cooldown bar, and a preview of the next card. Pure display - reads a
## CardSlot each frame, writes nothing back.

@onready var key_label: Label = $KeyLabel
@onready var name_label: Label = $NameLabel
@onready var cooldown_bar: ProgressBar = $CooldownBar
@onready var preview_label: Label = $PreviewLabel


func set_key_hint(text: String) -> void:
	key_label.text = text


func update_from_slot(slot: CardSlot) -> void:
	if slot == null or not slot.has_cards():
		name_label.text = "—"
		preview_label.text = ""
		cooldown_bar.max_value = 1.0
		cooldown_bar.value = 0.0
		return

	var card_data := CardDatabase.get_card(slot.current_card_id)
	name_label.text = card_data.get("name", slot.current_card_id)

	var preview_id := slot.preview_card_id()
	if preview_id == "":
		preview_label.text = "Next: —"
	else:
		var preview_card := CardDatabase.get_card(preview_id)
		preview_label.text = "Next: %s" % str(preview_card.get("name", preview_id))

	cooldown_bar.max_value = maxf(slot.last_cooldown_duration, 0.01)
	cooldown_bar.value = slot.cooldown_remaining
