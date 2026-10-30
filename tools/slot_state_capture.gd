extends Node
## Renders the HUD with a mix of ready and cooling slots (no gameplay needed).
## godot --path . res://tools/SlotStateCapture.tscn -- 1280 720 screenshots/slots.png
func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var w: int = int(args[0]) if args.size() > 0 else 1280
	var h: int = int(args[1]) if args.size() > 1 else 720
	var out: String = args[2] if args.size() > 2 else "screenshots/slots.png"
	var sub := SubViewport.new()
	sub.size = Vector2i(w, h)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub)
	var bg := ColorRect.new()
	bg.color = Color("#58886a")
	bg.size = Vector2(w, h)
	sub.add_child(bg)
	var hud: Hud = (load("res://scenes/ui/Hud.tscn") as PackedScene).instantiate()
	sub.add_child(hud)
	await get_tree().process_frame
	# Slot i: [current card, next card]; one family each so all three frame colours and a mixed slot show. Fractions: 0 = ready.
	var fractions: Array[float] = [0.0, 0.2, 0.55, 0.9, 0.0]
	var pairs: Array = [
		["fire_fireball", "rogue_quick_slash"], ["rogue_quick_slash", "fire_fireball"], ["neutral_deep_sigh", "fire_hot_head"],
		["fire_blaze_and_bail", "neutral_backward_leap"], ["neutral_healing_potion", "rogue_nap_time"],
	]
	for i in range(5):
		var ids: Array[String] = [String(pairs[i][0]), String(pairs[i][1])]
		var slot := CardSlot.new("attack_single", 4.0, ids)
		slot.current_card_id = ids[0]
		slot.draw_pile = [ids[1]]
		slot.cooldown_remaining = 0.0
		if fractions[i] > 0.0:
			slot.last_cooldown_duration = 4.0
			slot.cooldown_remaining = 4.0 * (1.0 - fractions[i])
		hud.slot_widgets[i].update_from_slot(slot)
	for i in range(10):
		await get_tree().process_frame
	var img: Image = sub.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	img.save_png(out)
	get_tree().quit()
