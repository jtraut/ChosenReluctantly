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
	var text := "\n".join(lines)
	if text != _last_text:
		_last_text = text
		label.text = text
		# fit_content sizes the label to its text; the backing panel follows it.
		panel.position = label.position - Vector2(PANEL_PADDING, PANEL_PADDING)
		panel.size = label.get_combined_minimum_size() + Vector2(PANEL_PADDING * 2.0, PANEL_PADDING * 2.0)


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
