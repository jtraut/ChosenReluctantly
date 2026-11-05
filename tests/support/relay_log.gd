class_name RelayLog
extends RefCounted
## Records every CombatEvents relay event as {name, args...} so a test can assert what was relayed and in what order.

var events: Array[Dictionary] = []
var _connections: Array = []


func _init(relay: CombatEventsRelay) -> void:
	_listen(relay.hit_landed, func(target: Node, amount: float, damage_type: String, kind: StringName, origin: String, position: Vector3) -> void:
		events.append({"name": "hit_landed", "target": target, "amount": amount, "damage_type": damage_type, "kind": kind, "origin": origin, "position": position}))
	_listen(relay.enemy_killed, func(target: Node, position: Vector3, origin: String, statuses: Array[String]) -> void:
		events.append({"name": "enemy_killed", "target": target, "position": position, "origin": origin, "statuses": statuses}))
	_listen(relay.status_applied, func(target: Node, status_id: String, stacks: int, source: Node, origin: String, position: Vector3) -> void:
		events.append({"name": "status_applied", "target": target, "status_id": status_id, "stacks": stacks, "source": source, "origin": origin, "position": position}))
	_listen(relay.status_ended, func(target: Node, status_id: String, reason: String, source: Node, origin: String, position: Vector3) -> void:
		var died_handler_ran: bool = bool(target.get("died_handler_ran")) if is_instance_valid(target) else false
		events.append({"name": "status_ended", "target": target, "status_id": status_id, "reason": reason, "source": source, "origin": origin, "position": position,
				"queued_for_free": is_instance_valid(target) and target.is_queued_for_deletion(), "died_handler_ran": died_handler_ran}))
	_listen(relay.attack_fired, func(attack_id: String, aim_point: Vector3) -> void:
		events.append({"name": "attack_fired", "attack_id": attack_id, "aim_point": aim_point}))
	_listen(relay.dash_ended, func(start: Vector3, end: Vector3, card_id: String) -> void:
		events.append({"name": "dash_ended", "start": start, "end": end, "card_id": card_id}))
	_listen(relay.player_damaged, func(amount: float, origin: String) -> void:
		events.append({"name": "player_damaged", "amount": amount, "origin": origin}))
	_listen(relay.zone_started, func(zone_id: int, shape: String, position: Vector3) -> void:
		events.append({"name": "zone_started", "zone_id": zone_id, "shape": shape, "position": position}))
	_listen(relay.zone_ended, func(zone_id: int, shape: String, position: Vector3) -> void:
		events.append({"name": "zone_ended", "zone_id": zone_id, "shape": shape, "position": position}))
	_listen(relay.room_started, func(index: int, room_type: String) -> void:
		events.append({"name": "room_started", "index": index, "type": room_type}))
	_listen(relay.room_cleared, func(index: int, room_type: String) -> void:
		events.append({"name": "room_cleared", "index": index, "type": room_type}))


## The recorded events with this name.
func named(event_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		if String(event["name"]) == event_name:
			result.append(event)
	return result


func names() -> Array[String]:
	var result: Array[String] = []
	for event: Dictionary in events:
		result.append(String(event["name"]))
	return result


func _listen(relay_signal: Signal, handler: Callable) -> void:
	relay_signal.connect(handler)
	_connections.append([relay_signal, handler])


## Disconnects from the relay (the relay is an autoload and outlives the test).
func stop() -> void:
	for pair: Array in _connections:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	_connections.clear()
