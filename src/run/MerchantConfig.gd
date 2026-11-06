class_name MerchantConfig
extends RefCounted
## The `merchant` block of data/run.json (MAP2-A, MAP.md section 4.4): what the merchant sells and for how much.
##   card_price      gold for any card in the stock
##   removal_base    gold for the first card removal bought this run
##   removal_step    gold added for every removal already bought (`RunState.merchant_removals`)
##   relic_stock     relics on offer (relic prices come from `relics.prices` by tier)
##   shop_only_slots how many of those hold only shop-only relics (`sources` exactly ["merchant"]); the rest are normal merchant stock
##   card_stock      cards on offer
## `validate_block` is pure (tests feed it anything); the accessors read the shipped config through RunConfig.

const KEYS: Array[String] = ["card_price", "removal_base", "removal_step", "relic_stock", "shop_only_slots", "card_stock"]
const MAX_PRICE := 99999
const MAX_STOCK := 9


## Human-readable problems with a `merchant` block; empty means valid.
static func validate_block(block: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(block) != TYPE_DICTIONARY:
		errors.append("'merchant' must be an object {%s}" % ", ".join(KEYS))
		return errors
	var b: Dictionary = block
	for key: Variant in b.keys():
		if not KEYS.has(String(key)):
			errors.append("merchant: unknown key '%s'" % str(key))
	for key: String in KEYS:
		if not b.has(key):
			errors.append("merchant: missing '%s'" % key)
	for key: String in ["card_price", "removal_base"]:
		if b.has(key) and (not _is_whole(b[key]) or int(b[key]) < 1 or int(b[key]) > MAX_PRICE):
			errors.append("merchant.%s must be a whole number in [1, %d]" % [key, MAX_PRICE])
	if b.has("removal_step") and (not _is_whole(b["removal_step"]) or int(b["removal_step"]) < 0 or int(b["removal_step"]) > MAX_PRICE):
		errors.append("merchant.removal_step must be a whole number in [0, %d]" % MAX_PRICE)
	if b.has("relic_stock") and (not _is_whole(b["relic_stock"]) or int(b["relic_stock"]) < 1 or int(b["relic_stock"]) > MAX_STOCK):
		errors.append("merchant.relic_stock must be a whole number in [1, %d]" % MAX_STOCK)
	if b.has("card_stock") and (not _is_whole(b["card_stock"]) or int(b["card_stock"]) < 0 or int(b["card_stock"]) > MAX_STOCK):
		errors.append("merchant.card_stock must be a whole number in [0, %d]" % MAX_STOCK)
	if b.has("shop_only_slots"):
		if not _is_whole(b["shop_only_slots"]) or int(b["shop_only_slots"]) < 0:
			errors.append("merchant.shop_only_slots must be a whole number of 0 or more")
		elif _is_whole(b.get("relic_stock")) and int(b["shop_only_slots"]) > int(b["relic_stock"]):
			errors.append("merchant.shop_only_slots (%d) is above relic_stock (%d)" % [int(b["shop_only_slots"]), int(b["relic_stock"])])
	return errors


## The shipped block ({} when the file has none).
static func block() -> Dictionary:
	return RunConfig.get_config().get("merchant", {})


## The merchant part of a RunChoices context from the shipped data: the block, the relic prices by tier and the free rerolls granted.
## `free_rerolls` is 0 until a relic grants some (the `merchant.free_rerolls` modifier, MAP2-B): the run flow sets it from the owned relics.
static func shipped_context() -> Dictionary:
	return {"config": block(), "prices": (RelicConfig.block().get("prices", {}) as Dictionary), "free_rerolls": 0}


static func _is_whole(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and not is_nan(float(value)) and not is_inf(float(value)) and float(value) == floorf(float(value))
