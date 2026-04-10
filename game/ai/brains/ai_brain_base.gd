extends RefCounted
class_name AIBrainBase


var controller: Node = null


func setup(ai_controller: Node) -> void:
	controller = ai_controller


func decide(_perception: Dictionary, _delta: float) -> Dictionary:
	return make_command("stop")


func make_command(action: String, data: Dictionary = {}) -> Dictionary:
	var command := {"action": action}
	for key in data.keys():
		command[key] = data[key]
	return command


func enter_state(state_id: String) -> void:
	var blackboard = _blackboard()
	if blackboard != null:
		blackboard.current_state = state_id


func _actor() -> Node:
	if controller == null:
		return null
	return controller.actor


func _blackboard():
	if controller == null or not controller.has_method("get_blackboard"):
		return null
	return controller.get_blackboard()


func _preset():
	if controller == null or not controller.has_method("get_current_preset"):
		return null
	return controller.get_current_preset()


func _current_ai_id() -> String:
	if controller == null or not controller.has_method("get_current_ai_id"):
		return ""
	return controller.get_current_ai_id()


func _is_script_locked() -> bool:
	var blackboard = _blackboard()
	return blackboard != null and blackboard.script_locked


func _player_detected(perception: Dictionary) -> bool:
	return bool(perception.get("can_target_player", false)) and bool(perception.get("player_in_detect_range", false))


func _update_alert_target(perception: Dictionary) -> void:
	var blackboard = _blackboard()
	var preset = _preset()
	if blackboard == null or preset == null:
		return

	var player: Node2D = perception.get("player")
	var player_position: Vector2 = perception.get("player_position", Vector2.ZERO)
	blackboard.set_alert_target(player, player_position, preset.lose_target_delay)


func _tick_alert(delta: float) -> void:
	var blackboard = _blackboard()
	if blackboard == null:
		return
	blackboard.alert_timeout = maxf(blackboard.alert_timeout - delta, 0.0)


func _return_home_command(reason: String) -> Dictionary:
	var blackboard = _blackboard()
	if blackboard != null:
		blackboard.return_reason = reason
	enter_state("return")
	return make_command("return_home")


func _idle_command() -> Dictionary:
	enter_state("idle")
	return make_command("stop")
