class_name TextFit
extends RefCounted
## Pure text-fit rule for fixed-size HUD labels: wrap to at most `max_lines`;
## if that does not fit, shrink the font one pixel at a time down to
## `min_size`; only then truncate with an ellipsis. No nodes involved, so it
## is unit-testable with any Font.

const ELLIPSIS: String = "…"
const BREAK_FLAGS: int = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE


## Number of wrapped lines `text` takes at `font_size` in `width` pixels.
static func line_count(text: String, font: Font, font_size: int, width: float) -> int:
	if text.is_empty():
		return 1
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1, BREAK_FLAGS)
	return maxi(1, roundi(size.y / font.get_height(font_size)))


## Returns {text, font_size, lines, truncated, fits}. `fits` is false only if
## even the ellipsised text cannot fit (e.g. width too small for one glyph).
static func fit(text: String, font: Font, width: float, max_lines: int, base_size: int, min_size: int) -> Dictionary:
	var low: int = mini(min_size, base_size)
	var size: int = base_size
	while size >= low:
		var lines := line_count(text, font, size, width)
		if lines <= max_lines:
			return {"text": text, "font_size": size, "lines": lines, "truncated": false, "fits": true}
		size -= 1
	# Last resort: longest prefix (plus ellipsis) that fits at the minimum size.
	var lo: int = 0
	var hi: int = text.length()
	while lo < hi:
		var mid: int = (lo + hi + 1) / 2
		var candidate := text.substr(0, mid).strip_edges() + ELLIPSIS
		if line_count(candidate, font, low, width) <= max_lines:
			lo = mid
		else:
			hi = mid - 1
	var result := text.substr(0, lo).strip_edges() + ELLIPSIS
	var lines_after := line_count(result, font, low, width)
	return {"text": result, "font_size": low, "lines": lines_after, "truncated": true, "fits": lines_after <= max_lines}
