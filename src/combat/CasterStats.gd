class_name CasterStats
extends RefCounted
## BD3b: the three live facts a caster condition or a `scale` block reads about the caster, as pure helpers so the evaluator, the
## synergy glow and the bot share one answer. Each is safe with a missing or freed caster (0 stacks, full HP).


## Stacks of `status_id` the caster holds on itself (0 when it holds none or has no status manager). Reads the same
## Hurtbox -> status_manager link `apply_status` with target "self" writes to.
static func self_stacks(caster: Node, status_id: String) -> int:
	if caster == null or not is_instance_valid(caster) or not caster.has_node("Hurtbox"):
		return 0
	var hurtbox := caster.get_node("Hurtbox") as Hurtbox
	if hurtbox == null or hurtbox.status_manager == null:
		return 0
	return hurtbox.status_manager.stacks_of(status_id)


## How many cards in `deck_card_ids` (copies each count) carry `tag` (a derived tag or a keyword; CardDatabase.has_tag).
static func deck_tag_count(deck_card_ids: Array, tag: String) -> int:
	var count: int = 0
	for card_id: Variant in deck_card_ids:
		if CardDatabase.has_tag(String(card_id), tag):
			count += 1
	return count


## The caster's current HP as a fraction of its max (1.0 when it has no Health, so "below" is false for a caster that cannot be hurt).
static func hp_fraction(caster: Node) -> float:
	if caster == null or not is_instance_valid(caster) or not caster.has_node("Health"):
		return 1.0
	var health := caster.get_node("Health") as Health
	if health == null or health.get_max_health() <= 0.0:
		return 1.0
	return clampf(health.get_current_health() / health.get_max_health(), 0.0, 1.0)


## BD3b-C2: true when the caster's armor is above its base, that is, something (a buff, a relic, equipment) is giving it bonus armor right now.
static func has_bonus_armor(caster: Node) -> bool:
	if caster == null or not is_instance_valid(caster) or not caster.has_node("Health"):
		return false
	var health := caster.get_node("Health") as Health
	return health != null and health.get_armor() > health.base_armor
