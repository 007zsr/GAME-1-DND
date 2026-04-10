extends Node
class_name EnemyAIController

const AIBlackboardScript = preload("res://game/ai/ai_blackboard.gd")
const AIRegistryScript = preload("res://game/ai/ai_registry.gd")

var actor: Node = null
var blackboard = AIBlackboardScript.new()
var current_ai_id: String = ""
var current_preset = null
var current_brain: RefCounted = null


func setup(actor_node: Node) -> void:
	actor = actor_node
	if blackboard == null:
		blackboard = AIBlackboardScript.new()
	if actor != null and actor.has_method("get_home_position"):
		blackboard.home_position = actor.get_home_position()


func configure_for_spawn(initial_ai_id: String) -> void:
	if actor == null:
		return
	blackboard.reset_for_spawn(actor.get_home_position())
	if not initial_ai_id.is_empty():
		switch_ai(initial_ai_id, false)


func physics_tick(delta: float) -> void:
	if actor == null or current_preset == null or current_brain == null:
		return

	_maybe_switch_low_health_phase()
	var perception: Dictionary = actor.collect_ai_perception(current_preset, blackboard)
	var command: Dictionary = current_brain.decide(perception, delta)
	_execute_command(command, delta)


func switch_ai(new_ai_id: String, preserve_attack_cooldown: bool = false, keep_phase_tag: bool = false) -> void:
	if actor == null or new_ai_id.is_empty():
		return

	var preset = AIRegistryScript.get_preset(new_ai_id)
	if preset == null:
		return

	current_ai_id = new_ai_id
	current_preset = preset
	current_brain = preset.instantiate_brain()
	if current_brain == null:
		push_error("Failed to instantiate AI brain for ai_id: %s" % new_ai_id)
		return

	blackboard.clear_runtime_state(keep_phase_tag)
	blackboard.home_position = actor.get_home_position()
	if blackboard.phase_tag.is_empty():
		blackboard.phase_tag = _derive_phase_tag(new_ai_id)

	actor.set_ai_id_runtime(new_ai_id)
	actor.set_detection_range_meters(preset.detection_range)
	actor.reset_ai_runtime_state(preserve_attack_cooldown, true)
	current_brain.setup(self)


func on_faction_changed(preserve_attack_cooldown: bool = false) -> void:
	if actor == null:
		return
	blackboard.clear_runtime_state(true)
	actor.reset_ai_runtime_state(preserve_attack_cooldown, true)


func set_script_locked(locked: bool) -> void:
	blackboard.script_locked = locked
	if locked and actor != null:
		actor.reset_ai_runtime_state(true, true)


func get_blackboard():
	return blackboard


func get_current_ai_id() -> String:
	return current_ai_id


func get_current_preset():
	return current_preset


func _execute_command(command: Dictionary, delta: float) -> void:
	if actor == null or command.is_empty():
		return

	match str(command.get("action", "")):
		"move_to":
			actor.execute_move_to_position(command.get("position", actor.get_home_position()), delta)
		"move_away":
			actor.execute_move_away_from_position(
				command.get("from_position", actor.get_home_position()),
				delta,
				float(command.get("speed_multiplier", 1.0))
			)
		"attack":
			var skill_id := str(command.get("skill_id", ""))
			if not skill_id.is_empty() and actor.has_method("request_skill_use"):
				actor.request_skill_use(skill_id, {
					"attack_mode": str(command.get("mode", "primary")),
				})
			elif actor.has_method("request_skill_use_by_mode"):
				actor.request_skill_use_by_mode(str(command.get("mode", "primary")))
			else:
				actor.begin_attack(str(command.get("mode", "primary")))
		"return_home":
			actor.execute_return_home(delta)
		"stop":
			actor.execute_stop()
		_:
			actor.execute_stop()


func _maybe_switch_low_health_phase() -> void:
	if actor == null or current_preset == null:
		return

	if current_preset.low_health_phase_ai_id.is_empty():
		return

	if current_ai_id == current_preset.low_health_phase_ai_id:
		return

	var threshold: float = current_preset.low_health_phase_threshold
	if threshold <= 0.0:
		return

	if actor.get_health_ratio() <= threshold:
		switch_ai(current_preset.low_health_phase_ai_id, true, true)


func _derive_phase_tag(ai_id: String) -> String:
	if ai_id.contains("phase2"):
		return "phase_two"
	if ai_id.contains("phase1"):
		return "phase_one"
	return ""
