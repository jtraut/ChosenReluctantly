class_name CastInput
extends RefCounted
## The press / hold / release model for card slot keys. Pure logic (no Node, no Input),
## so tests drive it directly; Player feeds it from _unhandled_input.
##
## "release" mode (default): pressing a slot key starts a preview of that slot; releasing
## that same key asks for one cast. Only one preview exists at a time: pressing another
## slot key switches the preview to it, and the first key's later release is ignored.
## "press" mode: pressing asks for a cast at once and there is never a preview.
## The model only says WHICH slot to cast; whether the slot is actually ready is the
## caller's check (CardSlotController.try_use refuses a slot on cooldown), so releasing
## a slot that is not ready just clears the preview.
##
## cancel() drops the preview without a cast (death, Game Over, pause, a settings
## screen, or the setting changing mid-hold).

const NONE := -1

## Slot index being previewed (release mode), or NONE.
var preview_slot: int = NONE


func is_previewing() -> bool:
	return preview_slot != NONE


## A slot key went down. Returns the slot to cast right now (press mode) or NONE.
func press(slot_index: int, cast_on_release: bool) -> int:
	if cast_on_release:
		preview_slot = slot_index
		return NONE
	preview_slot = NONE
	return slot_index


## A slot key came up. Returns the slot to cast (release mode, and only if it is the
## key being previewed) or NONE.
func release(slot_index: int) -> int:
	if preview_slot == NONE or preview_slot != slot_index:
		return NONE
	preview_slot = NONE
	return slot_index


## Drops the preview without casting. True when there was one.
func cancel() -> bool:
	var had_preview := preview_slot != NONE
	preview_slot = NONE
	return had_preview
