class_name HpBarLayout
extends RefCounted
## UX1c: crowd layout for the world-space enemy HP bars. In a pile of 6 or more the bars (and their status pips) stand on top of each other.
## This is the pure math: given where each bar would stand on the screen plane, how far each must be raised (screen-up, world units) so no
## two footprints overlap. Display only: it moves a bar's quad, never an enemy, and it uses no RNG.
##
## Coordinates are in the camera plane: x = along the camera's right axis, y = along its up axis (the camera is orthographic, so world
## units there are screen units up to one scale). The bars that stand lowest on the screen keep their place (they belong to the enemies in
## front); a bar that would overlap one already placed is lifted just above it.


## `anchors`: each bar's (x, y) in the camera plane. `footprint`: a bar's (width, height) with its pips. `gap`: the clear space kept between two
## footprints. `max_rows`: the most a bar is lifted, in footprint heights (a pile deeper than that keeps some overlap rather than a tower).
## Returns one offset per anchor, in the same order, each >= 0. Ties are broken by x then index, so the result never depends on input order luck.
static func stack_offsets(anchors: Array[Vector2], footprint: Vector2, gap: float, max_rows: int) -> Array[float]:
	var offsets: Array[float] = []
	offsets.resize(anchors.size())
	offsets.fill(0.0)
	if anchors.size() < 2 or footprint.x <= 0.0 or footprint.y <= 0.0:
		return offsets
	var order: Array[int] = []
	for i in range(anchors.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var pa: Vector2 = anchors[a]
		var pb: Vector2 = anchors[b]
		if not is_equal_approx(pa.y, pb.y):
			return pa.y < pb.y
		if not is_equal_approx(pa.x, pb.x):
			return pa.x < pb.x
		return a < b)
	var limit: float = float(maxi(max_rows, 0)) * (footprint.y + gap)
	var placed: Array[Rect2] = []
	for index: int in order:
		var anchor: Vector2 = anchors[index]
		var lift: float = 0.0
		for _pass in range(anchors.size()):
			var moved: bool = false
			for rect: Rect2 in placed:
				var spot := Rect2(Vector2(anchor.x - footprint.x * 0.5, anchor.y + lift), footprint)
				if overlaps(spot, rect, gap) and rect.end.y + gap - anchor.y > lift + 0.0001:
					lift = rect.end.y + gap - anchor.y
					moved = true
			if not moved:
				break
		lift = minf(lift, limit)
		offsets[index] = lift
		placed.append(Rect2(Vector2(anchor.x - footprint.x * 0.5, anchor.y + lift), footprint))
	return offsets


## True when the two rectangles overlap sideways and are closer than `gap` vertically (bars only ever move up, so only the vertical gap matters).
static func overlaps(a: Rect2, b: Rect2, gap: float) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x and a.position.y < b.end.y + gap and b.position.y < a.end.y + gap


## One smoothing step toward `target` (rate in 1/s): no pop when a pile forms or breaks up, and it lands exactly instead of creeping.
static func smooth(current: float, target: float, rate: float, delta: float) -> float:
	if rate <= 0.0 or absf(target - current) < 0.002:
		return target
	return lerpf(current, target, 1.0 - exp(-rate * delta))
