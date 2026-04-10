extends Resource
class_name AIPreset


@export var ai_id: String = ""
@export var brain_script: Script
@export var detection_range: float = 6.0
@export var lose_target_delay: float = 3.0
@export var desired_range: float = 0.0
@export var ideal_range_min: float = 0.0
@export var ideal_range_max: float = 0.0
@export var kite_trigger_distance: float = 0.0
@export var panic_enter_distance: float = 0.0
@export var panic_exit_distance: float = 0.0
@export var retreat_speed_multiplier: float = 1.0
@export var allow_retreat: bool = false
@export var allow_patrol: bool = false
@export var prioritize_player: bool = true
@export var low_health_phase_threshold: float = 0.0
@export var low_health_phase_ai_id: String = ""


func instantiate_brain() -> RefCounted:
	if brain_script == null:
		return null
	return brain_script.new()
