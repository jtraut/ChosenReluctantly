class_name C1eHudNamesTest
extends GdUnitTestSuite
## C1-e: every card name fits its HUD slot at the three target resolutions, as the real labels lay
## it out (not just as TextFit predicts): the wrapped text must fit the label's height, in both the
## "current card" row and the "Next:" row, and a name that cannot fit must end in an ellipsis
## rather than being cut off silently.

const RESOLUTIONS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]
const NEW_NAMES: Array[String] = [
	"Slash, Then Bleed", "Four Quick Stabs", "Fireball, Incoming", "Wall of Mild Fire", "Walk Through Everyone",
	"Reluctant Lunge", "Nope, Leaping Away", "Heal By Hurting", "Eventual Healing",
]


func _all_names() -> Array[String]:
	var names: Array[String] = []
	for card: Variant in CardDatabase.all_cards():
		var card_name: String = String((card as Dictionary).get("name", ""))
		if card_name != "" and not names.has(card_name):
			names.append(card_name)
	for new_name: String in NEW_NAMES:
		if not names.has(new_name):
			names.append(new_name)
	return names


func test_every_card_name_fits_the_slot_rows_at_all_resolutions() -> void:
	for vp: Vector2 in RESOLUTIONS:
		var sub := SubViewport.new()
		sub.size = Vector2i(vp)
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(sub)
		var hud: Hud = (load("res://scenes/ui/Hud.tscn") as PackedScene).instantiate()
		sub.add_child(hud)
		await get_tree().process_frame
		var w: CardSlotWidget = hud.slot_widgets[0]
		for card_name: String in _all_names():
			w._set_name(card_name)
			w._set_preview("Next: " + card_name)
			await get_tree().process_frame
			for label: Label in [w.name_label, w.preview_label]:
				var shown_lines: int = label.get_line_count()
				var fits_height: bool = label.get_line_count() * label.get_line_height() <= label.size.y + 0.5
				assert_bool(fits_height).override_failure_message("'%s' in %s at %s: %d lines of %d px do not fit %d px" % [
					card_name, label.name, vp, shown_lines, label.get_line_height(), roundi(label.size.y)]).is_true()
				# Nothing cut off silently: the visible lines hold the whole text, or it ends in the ellipsis.
				var whole: bool = label.get_visible_line_count() >= shown_lines
				assert_bool(whole or label.text.ends_with(TextFit.ELLIPSIS)).override_failure_message("'%s' in %s at %s is cut off without an ellipsis" % [card_name, label.name, vp]).is_true()
		sub.queue_free()
