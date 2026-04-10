extends "res://game/ai/brains/ai_brain_base.gd"


func decide(perception: Dictionary, delta: float) -> Dictionary:
	var blackboard = _blackboard()
	var preset = _preset()
	if blackboard == null or preset == null:
		return make_command("stop")

	if _is_script_locked() or blackboard.forced_behavior == "idle":
		return _idle_command()

	if bool(perception.get("is_executing_attack", false)):
		enter_state("attack")
		return make_command("stop")

	if _player_detected(perception):
		_update_alert_target(perception)
		blackboard.desired_range = preset.desired_range

		var movement_mode: String = _get_ranged_movement_mode(perception, preset, blackboard)
		match movement_mode:
			"panic":
				enter_state("panic")
				if bool(perception.get("fallback_attack_ready", false)) and bool(perception.get("player_in_fallback_range", false)):
					enter_state("attack")
					return make_command("attack", {
						"mode": "fallback",
						"skill_id": str(perception.get("fallback_skill_id", "")),
					})
				return make_command("move_away", {
					"from_position": perception.get("player_position", blackboard.last_seen_target_position),
					"speed_multiplier": preset.retreat_speed_multiplier,
				})
			"retreat":
				enter_state("retreat")
				return make_command("move_away", {
					"from_position": perception.get("player_position", blackboard.last_seen_target_position),
					"speed_multiplier": preset.retreat_speed_multiplier,
				})
			"hold":
				enter_state("hold")
				if bool(perception.get("primary_attack_ready", false)) and bool(perception.get("player_in_primary_range", false)):
					enter_state("attack")
					return make_command("attack", {
						"mode": "primary",
						"skill_id": str(perception.get("primary_skill_id", "")),
					})
				return make_command("stop")
			_:
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


func _get_ranged_movement_mode(perception: Dictionary, preset, blackboard) -> String:
	var distance_meters: float = float(perception.get("distance_to_player_meters", INF))
	var ideal_min_distance: float = preset.ideal_range_min
	var ideal_max_distance: float = preset.ideal_range_max

	if ideal_min_distance <= 0.0:
		ideal_min_distance = maxf(preset.desired_range, 0.0)

	if ideal_max_distance <= 0.0:
		ideal_max_distance = maxf(ideal_min_distance, 0.1)

	var kite_trigger_distance: float = preset.kite_trigger_distance
	if kite_trigger_distance <= 0.0:
		kite_trigger_distance = ideal_min_distance * 0.7

	var panic_enter_distance: float = preset.panic_enter_distance
	var panic_exit_distance: float = preset.panic_exit_distance
	if panic_exit_distance <= 0.0:
		panic_exit_distance = panic_enter_distance + 0.5

	if blackboard.ranged_panic_active:
		if distance_meters > panic_exit_distance:
			blackboard.ranged_panic_active = false
	elif panic_enter_distance > 0.0 and distance_meters <= panic_enter_distance:
		blackboard.ranged_panic_active = true

	if blackboard.ranged_panic_active:
		return "panic"

	if blackboard.ranged_kiting_active:
		if distance_meters >= ideal_min_distance:
			blackboard.ranged_kiting_active = false
	elif distance_meters <= kite_trigger_distance:
		blackboard.ranged_kiting_active = true

	if distance_meters > ideal_max_distance:
		blackboard.ranged_kiting_active = false
		return "chase"

	if preset.allow_retreat and blackboard.ranged_kiting_active:
		return "retreat"

	return "hold"
