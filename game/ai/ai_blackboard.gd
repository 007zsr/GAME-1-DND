extends RefCounted
class_name AIBlackboard


var current_target: Node2D = null
var last_seen_target_position: Vector2 = Vector2.ZERO
var home_position: Vector2 = Vector2.ZERO
var is_alerted: bool = false
var alert_timeout: float = 0.0
var forced_target: Node2D = null
var script_locked: bool = false
var forced_behavior: String = ""
var desired_range: float = 0.0
var return_reason: String = ""
var phase_tag: String = ""
var current_state: String = "idle"
var ranged_kiting_active: bool = false
var ranged_panic_active: bool = false


func reset_for_spawn(spawn_home_position: Vector2) -> void:
	home_position = spawn_home_position
	script_locked = false
	forced_behavior = ""
	phase_tag = ""
	clear_runtime_state()


func clear_runtime_state(keep_phase_tag: bool = false) -> void:
	clear_target_state()
	desired_range = 0.0
	return_reason = ""
	current_state = "idle"
	ranged_kiting_active = false
	ranged_panic_active = false
	if not keep_phase_tag:
		phase_tag = ""


func clear_target_state() -> void:
	current_target = null
	last_seen_target_position = Vector2.ZERO
	is_alerted = false
	alert_timeout = 0.0


func set_alert_target(target: Node2D, target_position: Vector2, timeout_seconds: float) -> void:
	current_target = target
	last_seen_target_position = target_position
	is_alerted = true
	alert_timeout = maxf(timeout_seconds, 0.0)
