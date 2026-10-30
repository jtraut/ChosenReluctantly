extends CanvasLayer
class_name DebugOverlay
## F3-toggled overlay: FPS, every slot's cooldown, and deck contents. Off by
## default - this is a diagnostic tool, not part of the normal HUD.
##
## The unique-card counts come straight from DeckCheck's data (never parsed back out of its text):
## "Movement 5/3 ok" in a quiet colour, a shortfall as "Movement 2/3  SHORT -1" in red and bold. The
## words "ok" and "SHORT" carry the meaning too, so it does not rely on colour.

const OK_COLOR := "#8fe388"
const SHORT_COLOR := "#ff6b5e"
const DIM_COLOR := "#9aa5b1"
const PANEL_PADDING := 8.0
## An enemy within this many metres of the cursor's ground point is "under the cursor"; otherwise the nearest to the player.
const CURSOR_PICK_RADIUS := 1.6

@onready var label: RichTextLabel = $Label
@onready var panel: Panel = $Panel

var player: Player = null
var _last_text: String = ""


func _ready() -> void:
	visible = false
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)


## Sits under the scaled HUD pieces above it (the boss bar block): see HudLayout.debug_overlay_top.
func _apply_layout() -> void:
	var top: float = HudLayout.debug_overlay_top(get_viewport().get_visible_rect().size, UiConfig.hud())
	label.position.y = top + PANEL_PADDING
	panel.position.y = top
	_last_text = ""  # the next _process rebuilds the backing panel around the label


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
		for i in range(lines.size()):
			lines[i] = lines[i].replace("[", "[lb]")
		lines.append("[color=%s]Unique cards (have/need):[/color]" % DIM_COLOR)
		lines.append_array(count_lines(player.card_slots.deck_check()))
	lines.append_array(_defense_lines())
	var text := "\n".join(lines)
	if text != _last_text:
		_last_text = text
		label.text = text
		# fit_content sizes the label to its text; the backing panel follows it.
		panel.position = label.position - Vector2(PANEL_PADDING, PANEL_PADDING)
		panel.size = label.get_combined_minimum_size() + Vector2(PANEL_PADDING * 2.0, PANEL_PADDING * 2.0)


## The armor and resistance lines: the enemy under the cursor (else the nearest to the player), then the player's armor.
func _defense_lines() -> Array[String]:
	var lines: Array[String] = []
	var world: Node = player.get_parent() if player != null else null  # enemies are siblings of the player (also inside a capture SubViewport)
	var enemies: Array[Enemy] = []
	if world != null:
		for child: Node in world.get_children():
			var enemy := child as Enemy
			if enemy != null and not enemy.health.is_dead():
				enemies.append(enemy)
	var positions: Array[Vector3] = []
	for enemy: Enemy in enemies:
		positions.append(enemy.global_position)
	var origin: Vector3 = player.global_position if player != null else Vector3.ZERO
	var aim: Variant = player.get_aim_point() if player != null else null
	var pick: Dictionary = pick_target(aim, origin, positions, CURSOR_PICK_RADIUS)
	lines.append("[color=%s]Defense:[/color]" % DIM_COLOR)
	if pick["index"] >= 0:
		var target: Enemy = enemies[int(pick["index"])]
		var name_: String = target.display_name() if target is Boss else target.enemy_id
		lines.append(target_line(String(pick["mode"]), name_, target.tier, target.health.get_armor(), target.health.get_armor_reduction(), target.health.resistances))
	else:
		lines.append("Target: none")
	if player != null:
		lines.append(player_line(player.health.get_armor(), player.health.get_armor_reduction()))
	return lines


## Which enemy the defense lines describe: {"index": int, "mode": "cursor" or "nearest"}; index -1 with no enemies.
## `aim` is the cursor's ground point (a Vector3, or null without one). Ground plane only (height is ignored).
static func pick_target(aim: Variant, origin: Vector3, positions: Array[Vector3], radius: float) -> Dictionary:
	var best: int = -1
	var best_dist: float = INF
	if aim is Vector3:
		for i in range(positions.size()):
			var d: float = Vector2(positions[i].x - (aim as Vector3).x, positions[i].z - (aim as Vector3).z).length()
			if d <= radius and d < best_dist:
				best = i
				best_dist = d
		if best >= 0:
			return {"index": best, "mode": "cursor"}
	best_dist = INF
	for i in range(positions.size()):
		var d2: float = Vector2(positions[i].x - origin.x, positions[i].z - origin.z).length()
		if d2 < best_dist:
			best = i
			best_dist = d2
	return {"index": best, "mode": "nearest"}


## "Resist: all elements 50%", "Resist: fire 50%, water 10%", or "Resist: none".
static func resist_summary(resistances: Dictionary) -> String:
	var best: float = EnemyHpBar.max_resistance(resistances)
	if best <= 0.0:
		return "Resist: none"
	if BossHpBar.resists_uniformly(resistances):
		return "Resist: all elements %d%%" % roundi(best * 100.0)
	var parts: Array[String] = []
	for key: Variant in resistances:
		if float(resistances[key]) > 0.0:
			parts.append("%s %d%%" % [str(key), roundi(float(resistances[key]) * 100.0)])
	return "Resist: " + ", ".join(parts)


## "Under cursor: boss_guardian (boss)  Armor 50 (50% off physical)  Resist: all elements 50%".
static func target_line(mode: String, name_: String, tier: String, armor: float, armor_reduction: float, resistances: Dictionary) -> String:
	var who: String = "Under cursor" if mode == "cursor" else "Nearest"
	var rank: String = "" if tier == "" else " (%s)" % tier
	return "%s: %s%s  Armor %d (%d%%)  %s" % [who, name_, rank, roundi(armor), roundi(armor_reduction * 100.0), resist_summary(resistances)]


static func player_line(armor: float, armor_reduction: float) -> String:
	return "Player: Armor %d (%d%%)" % [roundi(armor), roundi(armor_reduction * 100.0)]


## One BBCode line per slot and per group: "Movement 5/3 ok", or "Movement 2/3  SHORT -1" in red bold.
static func count_lines(deck_check: DeckCheck) -> Array[String]:
	var lines: Array[String] = []
	for entry: Dictionary in deck_check.slots:
		lines.append(count_line(str(entry["display_name"]), entry))
	for entry: Dictionary in deck_check.groups:
		lines.append(count_line("%s group" % str(entry["name"]), entry))
	return lines


static func count_line(name_: String, entry: Dictionary) -> String:
	var have: int = int(entry["count"])
	var need: int = int(entry["required"])
	var short: int = int(entry["short"])
	if short > 0:
		return "[color=%s][b]%s %d/%d  SHORT -%d[/b][/color]" % [SHORT_COLOR, name_, have, need, short]
	return "[color=%s]%s %d/%d ok[/color]" % [OK_COLOR, name_, have, need]


## "id (Full Name)" so names the HUD had to shrink or truncate are still readable here.
func _card_label(card_id: String) -> String:
	if card_id == "":
		return "-"
	var card_name := str(CardDatabase.get_card(card_id).get("name", ""))
	return "%s (%s)" % [card_id, card_name] if card_name != "" else card_id
