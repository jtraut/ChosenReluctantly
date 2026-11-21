class_name FormulatedBot
extends RefCounted
## SIM2a-2: the one door the wave sim asks before its own choice policy. `choose` returns the option id the "formulated" bot takes, or "" to say "not mine: use today's policy".
## Under any other profile ("", "plan", "report") it returns "" for everything, so the sim's random draws and choices are exactly today's.
##   PENDING_REWARD, PENDING_RELIC, PENDING_RELIC_SWAP   DraftPolicy (SIM2a-1: it was written but never called by the sim until this slice)
##   PENDING_MERCHANT*, PENDING_REST_REMOVE, PENDING_EVENT_REMOVE   FormulatedShop (the same scorer)
##   PENDING_NODE   FormulatedRoute, only when `route_formulated` (the profile is on and no -Route was given; `-Route first` keeps the first route)
## `free_size` is the class's starting deck size (the deck that is free of the skip bar).

const PROFILE := "formulated"
## SIM2a-3 attribution switches (debug only, default empty = nothing changes): "shop" hands every merchant choice back to today's policy; "removal" stops merchant removals being bought
## and hands every removal list back to today's policy. Set from `--sim-formulated-off=shop,removal`.
static var off: Dictionary = {}


static func choose(profile: String, route_formulated: bool, choice: String, options: Array, state: RunState, free_size: int) -> String:
	if profile != PROFILE:
		return ""
	match choice:
		RunState.PENDING_REWARD:
			return DraftPolicy.reward_choice(options, state.deck, free_size)
		RunState.PENDING_RELIC:
			return DraftPolicy.relic_choice(options, state.deck)
		RunState.PENDING_RELIC_SWAP:
			return DraftPolicy.giveup_choice(options, state.deck)
		RunState.PENDING_MERCHANT_SWAP:
			if off.has("shop"):
				return ""
			return DraftPolicy.giveup_choice(options, state.deck)
		RunState.PENDING_MERCHANT:
			if off.has("shop"):
				return ""
			return FormulatedShop.shop_choice(options, state, free_size, off.has("removal"))
		RunState.PENDING_MERCHANT_REMOVE, RunState.PENDING_REST_REMOVE, RunState.PENDING_EVENT_REMOVE:
			if off.has("removal") or (off.has("shop") and choice == RunState.PENDING_MERCHANT_REMOVE):
				return ""
			return FormulatedShop.removal_choice(options, state)
		RunState.PENDING_NODE:
			if route_formulated:
				var picked: int = FormulatedRoute.pick(state.map, state.path, state.hp_fraction(), state.gold, state.deck)
				return "node:%d" % picked if picked >= 0 else ""
	return ""
