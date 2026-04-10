extends "res://game/ai/brains/ai_brain_base.gd"


func decide(perception: Dictionary, delta: float) -> Dictionary:
	var blackboard = _blackboard()
	if blackboard == null:
		return make_command("stop")

	if _is_script_locked() or blackboard.forced_behavior == "idle":
		return _idle_command()

	if bool(perception.get("is_executing_attack", false)):
		enter_state("attack")
		return make_command("stop")

	if _player_detected(perception):
		_update_alert_target(perception)
		if bool(perception.get("primary_attack_ready", false)) and bool(perception.get("player_in_primary_range", false)):
			enter_state("attack")
			return make_command("attack", {
				"mode": "primary",
				"skill_id": str(perception.get("primary_skill_id", "")),
			})

		enter_state("chase")
		return make_command("move_to", {"position": perception.get("player_position", blackboard.last_seen_target_position)})

	if blackboard.is_alerted:
		_tick_alert(delta)
		if blackboard.alert_timeout > 0.0:
			enter_state("lose_target")
			return make_command("move_to", {"position": blackboard.last_seen_target_position})

		blackboard.clear_target_state()
		return _return_home_command("lost_target")

	blackboard.clear_target_state()
	if not bool(perception.get("at_home", false)):
		return _return_home_command("idle_return")
	return _idle_command()
