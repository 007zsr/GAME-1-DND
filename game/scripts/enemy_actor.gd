extends Node2D

const GameLayers = preload("res://game/scripts/game_layers.gd")
const OverheadDisplayScene = preload("res://game/scenes/overhead_display.tscn")
const OverheadDisplayScript = preload("res://game/scripts/overhead_display.gd")
const SkillExecutor = preload("res://game/skills/skill_executor.gd")
const SkillRegistry = preload("res://game/skills/skill_registry.gd")
const SkillRuntime = preload("res://game/skills/skill_runtime.gd")

signal enemy_died(enemy: Node2D)

const ENABLE_ATTACK_AREA_DETECTION := false

var enemy_config: Dictionary = {}
var enemy_data: Dictionary = {}
var village: Node2D
var meters_to_pixels: float = 16.0
var home_position: Vector2 = Vector2.ZERO
var actor_kind: String = "enemy"
var faction_id: String = "enemy"
var ai_id: String = ""
var detection_range_meters: float = 0.0
var attack_cooldown_remaining: float = 0.0
var fallback_attack_cooldown_remaining: float = 0.0
var attack_timer_remaining: float = 0.0
var attack_phase: String = ""
var current_attack_mode: String = "primary"
var current_attack_direction: Vector2 = Vector2.RIGHT
var attack_has_fired: bool = false
var current_skill_id: String = ""
var current_skill_execution_state: Dictionary = {}
var last_skill_execution_state: Dictionary = {}
var skill_runtime_state: Dictionary = {}
var skill_mode_bindings: Dictionary = {}
var last_requested_skill_id: String = ""
var last_executed_skill_id: String = ""
var uses_sprite_visuals: bool = false
var visual_base_modulate: Color = Color.WHITE
var current_visual_direction: String = "down"
var current_visual_anchor_offset: Vector2 = Vector2(0.0, -8.0)
var current_visual_configured_sprite_frames_path: String = ""
var current_visual_sheet_path: String = ""
var current_visual_mirror_right_from_left: bool = false
var current_visual_mirror_left_from_right: bool = false
var overhead_display: Node

@onready var ai_controller: Node = $AIController
@onready var body: ColorRect = $Body
@onready var visual_sprite: AnimatedSprite2D = $VisualSprite
@onready var hurtbox_area: Area2D = $HurtboxArea
@onready var hurtbox_shape: CollisionShape2D = $HurtboxArea/CollisionShape2D
@onready var detect_area: Area2D = $DetectArea
@onready var detect_shape: CollisionShape2D = $DetectArea/CollisionShape2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var attack_arc: Polygon2D = $AttackArc
@onready var name_label: Label = $NameLabel
@onready var health_label: Label = $HealthLabel


func _ready() -> void:
	attack_arc.visible = false
	attack_arc.z_as_relative = false
	attack_arc.z_index = GameLayers.Z_EFFECTS
	_ensure_overhead_display()
	_disable_legacy_overhead_labels()
	if ai_controller != null:
		ai_controller.setup(self)


func setup_enemy(config: Dictionary, village_node: Node2D, spawn_position_meters: Vector2, world_meters_to_pixels: float, initial_ai_id: String = "", initial_faction_id: String = "enemy") -> void:
	setup_actor(config, village_node, spawn_position_meters, world_meters_to_pixels, initial_ai_id, initial_faction_id)


func setup_actor(config: Dictionary, village_node: Node2D, spawn_position_meters: Vector2, world_meters_to_pixels: float, initial_ai_id: String = "", initial_faction_id: String = "enemy") -> void:
	enemy_config = config.duplicate(true)
	village = village_node
	meters_to_pixels = world_meters_to_pixels
	home_position = spawn_position_meters * meters_to_pixels
	global_position = home_position
	actor_kind = str(enemy_config.get("actor_kind", enemy_config.get("unit_kind", "enemy")))
	faction_id = initial_faction_id
	ai_id = initial_ai_id
	detection_range_meters = float(enemy_config.get("detection_range", 0.0))
	attack_cooldown_remaining = 0.0
	fallback_attack_cooldown_remaining = 0.0
	attack_timer_remaining = 0.0
	attack_phase = ""
	current_attack_mode = "primary"
	attack_has_fired = false
	current_attack_direction = Vector2.RIGHT
	current_skill_id = ""
	current_skill_execution_state = {}
	last_skill_execution_state = {}
	last_requested_skill_id = ""
	last_executed_skill_id = ""
	uses_sprite_visuals = false
	visual_base_modulate = Color.WHITE
	current_visual_direction = "down"
	current_visual_anchor_offset = Vector2(0.0, -8.0)
	current_visual_configured_sprite_frames_path = ""
	current_visual_sheet_path = ""
	current_visual_mirror_right_from_left = false
	current_visual_mirror_left_from_right = false

	var max_hp: int = max(1, int(enemy_config.get("max_health", 1)))
	enemy_data = {
		"max_health": max_hp,
		"health": max_hp,
	}

	_setup_skill_runtime()
	_configure_collision_layers()
	_configure_detection_and_attack_areas()
	_apply_visuals()
	_update_health_label()

	if ai_controller != null:
		ai_controller.setup(self)
		ai_controller.configure_for_spawn(initial_ai_id)


func _physics_process(delta: float) -> void:
	if village != null and village.has_method("is_result_showing") and village.is_result_showing():
		_update_visual_state(Vector2.ZERO)
		return
	if village != null and village.has_method("is_dialogue_active") and village.is_dialogue_active():
		_update_visual_state(Vector2.ZERO)
		return

	if enemy_data.is_empty() or not is_alive():
		_update_visual_state(Vector2.ZERO)
		return

	var previous_position := global_position
	SkillRuntime.tick_cooldowns(skill_runtime_state, delta)
	_update_attack_execution(delta)
	_configure_detection_and_attack_areas()
	if ai_controller != null:
		ai_controller.physics_tick(delta)
	_update_visual_state(global_position - previous_position)


func get_hitbox_half_size_pixels() -> Vector2:
	var size_meters: Vector2 = enemy_config["size_meters"] as Vector2
	return size_meters * meters_to_pixels * 0.5


func get_hurtbox_area() -> Area2D:
	return hurtbox_area


func is_alive() -> bool:
	return int(enemy_data["health"]) > 0


func get_current_health() -> int:
	if enemy_data.is_empty():
		return 0
	return int(enemy_data.get("health", 0))


func get_max_health() -> int:
	if enemy_data.is_empty():
		return 0
	return int(enemy_data.get("max_health", 0))


func get_enemy_data() -> Dictionary:
	return enemy_data.duplicate(true)


func get_enemy_role() -> String:
	return get_actor_role()


func get_actor_role() -> String:
	return str(enemy_config.get("role", ""))


func get_template_id() -> String:
	return str(enemy_config.get("template_id", ""))


func get_enemy_config_snapshot() -> Dictionary:
	return enemy_config.duplicate(true)


func get_actor_kind() -> String:
	return actor_kind


func is_boss() -> bool:
	return get_enemy_role() == "boss"


func get_faction_id() -> String:
	return faction_id


func is_hostile_to_player() -> bool:
	return faction_id == "enemy"


func get_ai_id() -> String:
	return ai_id


func get_last_requested_skill_id() -> String:
	return last_requested_skill_id


func get_last_executed_skill_id() -> String:
	return last_executed_skill_id


func has_sprite_visuals() -> bool:
	return uses_sprite_visuals


func get_visual_debug_state() -> Dictionary:
	var sprite_frames_path := ""
	var current_animation := ""
	var available_animations: Array[String] = []
	if visual_sprite != null and visual_sprite.sprite_frames != null:
		sprite_frames_path = str(visual_sprite.sprite_frames.resource_path)
		current_animation = str(visual_sprite.animation)
		for animation_name in visual_sprite.sprite_frames.get_animation_names():
			available_animations.append(str(animation_name))
	return {
		"uses_sprite_visuals": uses_sprite_visuals,
		"body_visible": body.visible if body != null else false,
		"visual_visible": visual_sprite.visible if visual_sprite != null else false,
		"sprite_frames_path": sprite_frames_path,
		"configured_sprite_frames_path": current_visual_configured_sprite_frames_path,
		"sheet_path": current_visual_sheet_path,
		"current_animation": current_animation,
		"available_animations": available_animations,
		"visual_scale": visual_sprite.scale if visual_sprite != null else Vector2.ONE,
		"visual_anchor_offset": current_visual_anchor_offset,
		"flip_h": visual_sprite.flip_h if visual_sprite != null else false,
		"mirror_right_from_left": current_visual_mirror_right_from_left,
		"mirror_left_from_right": current_visual_mirror_left_from_right,
	}


func get_attack_execution_debug_state() -> Dictionary:
	return {
		"attack_phase": attack_phase,
		"current_skill_id": current_skill_id,
		"current_attack_mode": current_attack_mode,
		"current_state": current_skill_execution_state.duplicate(true),
		"last_state": last_skill_execution_state.duplicate(true),
		"current_attack_direction": current_attack_direction,
	}


func get_home_position() -> Vector2:
	return home_position


func get_health_ratio() -> float:
	if enemy_data.is_empty():
		return 0.0
	return float(enemy_data["health"]) / maxf(float(enemy_data["max_health"]), 1.0)


func set_ai_id_runtime(new_ai_id: String) -> void:
	ai_id = new_ai_id


func set_detection_range_meters(new_range_meters: float) -> void:
	detection_range_meters = maxf(new_range_meters, 0.0)


func switch_ai(new_ai_id: String, preserve_attack_cooldown: bool = false) -> void:
	if ai_controller == null:
		ai_id = new_ai_id
		return
	ai_controller.switch_ai(new_ai_id, preserve_attack_cooldown)


func switch_faction(new_faction_id: String, preserve_attack_cooldown: bool = false) -> void:
	if faction_id == new_faction_id:
		return
	faction_id = new_faction_id
	if ai_controller != null:
		ai_controller.on_faction_changed(preserve_attack_cooldown)


func apply_combat_profile(profile: Dictionary) -> void:
	var preserve_attack_cooldown: bool = bool(profile.get("preserve_attack_cooldown", false))
	if profile.has("faction_id"):
		faction_id = str(profile["faction_id"])

	if profile.has("ai_id") and ai_controller != null:
		ai_controller.switch_ai(str(profile["ai_id"]), preserve_attack_cooldown)
	elif ai_controller != null:
		ai_controller.on_faction_changed(preserve_attack_cooldown)


func get_owned_skill_ids() -> Array[String]:
	return SkillRuntime.get_owned_skill_ids(skill_runtime_state)


func get_skill_runtime_state_snapshot() -> Dictionary:
	return skill_runtime_state.duplicate(true)


func request_skill_use_by_mode(attack_mode: String = "primary") -> bool:
	var skill_id := _resolve_attack_mode_skill_id(attack_mode)
	if skill_id.is_empty():
		return false
	return request_skill_use(skill_id, {"attack_mode": attack_mode})


func request_skill_use(skill_id: String, request_context: Dictionary = {}) -> bool:
	if skill_id.is_empty():
		return false
	var attack_mode := str(request_context.get("attack_mode", ""))
	if attack_mode.is_empty():
		attack_mode = _resolve_skill_attack_mode(skill_id)
	if attack_mode.is_empty():
		return false
	if _resolve_attack_mode_skill_id(attack_mode) != skill_id:
		return false
	last_requested_skill_id = skill_id
	return begin_attack(attack_mode)


func execute_skill_definition(skill_id: String, definition: Dictionary, request_context: Dictionary = {}) -> Dictionary:
	match str(definition.get("execution_key", "")):
		"enemy_sector_attack":
			return execute_enemy_sector_skill(skill_id, definition, request_context)
		"enemy_projectile_attack":
			return execute_enemy_projectile_skill(skill_id, definition, request_context)
		"enemy_fixed_dash_attack":
			return execute_enemy_fixed_dash_skill(skill_id, definition, request_context)
		"enemy_multi_bite_attack":
			return execute_enemy_multi_bite_skill(skill_id, definition, request_context)
		"enemy_multi_stage_sector_attack":
			return execute_enemy_multi_stage_sector_skill(skill_id, definition, request_context)
		_:
			return {"success": false}


func execute_enemy_sector_skill(skill_id: String, _definition: Dictionary, request_context: Dictionary = {}) -> Dictionary:
	var runtime_skill := _get_runtime_skill_config(str(request_context.get("attack_mode", current_attack_mode)), skill_id)
	if runtime_skill.is_empty():
		return {"success": false}
	var attack_profile: Dictionary = get_attack_profile(int(runtime_skill.get("damage", 0)))
	var range_meters: float = float(runtime_skill.get("range_meters", 0.0))
	var arc_degrees: float = float(runtime_skill.get("arc_degrees", 90.0))
	var damage: int = int(runtime_skill.get("damage", 0))
	_show_attack_arc(range_meters, arc_degrees, runtime_skill.get("effect_color", Color(1.0, 0.8, 0.5, 0.7)), float(runtime_skill.get("flash_duration", 0.15)))
	village.apply_enemy_sector_attack(get_display_name(), global_position, current_attack_direction, range_meters * meters_to_pixels, arc_degrees, damage, attack_profile)
	return {
		"success": true,
		"cooldown_duration": _get_attack_cooldown(str(request_context.get("attack_mode", current_attack_mode))),
	}


func execute_enemy_projectile_skill(skill_id: String, _definition: Dictionary, request_context: Dictionary = {}) -> Dictionary:
	var runtime_skill := _get_runtime_skill_config(str(request_context.get("attack_mode", current_attack_mode)), skill_id)
	if runtime_skill.is_empty():
		return {"success": false}
	var attack_profile: Dictionary = get_attack_profile(int(runtime_skill.get("damage", 0)))
	village.spawn_enemy_projectile(get_display_name(), global_position, current_attack_direction, runtime_skill, attack_profile)
	_show_attack_arc(0.45, 90.0, runtime_skill.get("effect_color", Color(0.72, 0.88, 1.0, 0.92)), float(runtime_skill.get("flash_duration", 0.14)))
	return {
		"success": true,
		"cooldown_duration": _get_attack_cooldown(str(request_context.get("attack_mode", current_attack_mode))),
	}


func execute_enemy_fixed_dash_skill(skill_id: String, _definition: Dictionary, request_context: Dictionary = {}) -> Dictionary:
	var attack_mode := str(request_context.get("attack_mode", current_attack_mode))
	var runtime_skill := _get_runtime_skill_config(attack_mode, skill_id)
	if runtime_skill.is_empty():
		return {"success": false}
	if current_skill_execution_state.is_empty():
		current_skill_execution_state = _prepare_attack_execution_state(skill_id, attack_mode)
	var dash_state := current_skill_execution_state.duplicate(true)
	if not bool(dash_state.get("target_found", false)):
		dash_state["completed_reason"] = "no_walkable_target"
		last_skill_execution_state = dash_state.duplicate(true)
		current_skill_execution_state = {}
		attack_phase = "recovery"
		attack_timer_remaining = float(runtime_skill.get("failure_recovery", 0.28))
		return {
			"success": true,
			"cooldown_duration": float(runtime_skill.get("failure_cooldown", 0.0)),
		}

	var target_position := Vector2(dash_state.get("dash_target_position", global_position))
	var speed_multiplier := float(runtime_skill.get("dash_speed_multiplier", 3.0))
	var move_speed_pixels := maxf(_get_move_speed_pixels() * speed_multiplier, 1.0)
	var dash_distance_pixels := global_position.distance_to(target_position)
	var dash_timeout := maxf(dash_distance_pixels / move_speed_pixels + 0.18, 0.18)
	dash_state["speed_multiplier"] = speed_multiplier
	dash_state["arrival_threshold_pixels"] = float(runtime_skill.get("arrival_threshold_meters", 0.24)) * meters_to_pixels
	dash_state["dash_distance_pixels"] = dash_distance_pixels
	dash_state["dash_timeout"] = dash_timeout
	dash_state["dash_elapsed"] = 0.0
	dash_state["sequence_type"] = "fixed_dash"
	current_skill_execution_state = dash_state
	attack_phase = "dash_active"
	attack_timer_remaining = dash_timeout
	_show_attack_arc(0.7, 70.0, runtime_skill.get("effect_color", Color(0.84, 0.92, 1.0, 0.78)), float(runtime_skill.get("flash_duration", 0.14)))
	return {
		"success": true,
		"cooldown_duration": _get_attack_cooldown(attack_mode),
	}


func execute_enemy_multi_bite_skill(skill_id: String, _definition: Dictionary, request_context: Dictionary = {}) -> Dictionary:
	var attack_mode := str(request_context.get("attack_mode", current_attack_mode))
	var runtime_skill := _get_runtime_skill_config(attack_mode, skill_id)
	if runtime_skill.is_empty():
		return {"success": false}
	var bite_count: int = max(1, int(runtime_skill.get("bite_count", 3)))
	var bite_interval: float = maxf(float(runtime_skill.get("bite_interval", 0.18)), 0.01)
	var combo_end_time: float = bite_interval * float(max(bite_count - 1, 0)) + maxf(float(runtime_skill.get("combo_tail", 0.08)), 0.02)
	current_skill_execution_state = {
		"sequence_type": "multi_bite",
		"combo_hits_total": bite_count,
		"combo_hits_resolved": 0,
		"bite_interval": bite_interval,
		"next_hit_time": 0.0,
		"elapsed": 0.0,
		"combo_end_time": combo_end_time,
		"damage": int(runtime_skill.get("damage", 0)),
		"range_pixels": float(runtime_skill.get("range_meters", 1.0)) * meters_to_pixels,
		"arc_degrees": float(runtime_skill.get("arc_degrees", 110.0)),
		"flash_duration": float(runtime_skill.get("flash_duration", 0.09)),
		"effect_color": runtime_skill.get("effect_color", Color(0.92, 0.96, 1.0, 0.84)),
	}
	attack_phase = "bite_combo_active"
	attack_timer_remaining = combo_end_time
	return {
		"success": true,
		"cooldown_duration": _get_attack_cooldown(attack_mode),
	}


func execute_enemy_multi_stage_sector_skill(skill_id: String, _definition: Dictionary, request_context: Dictionary = {}) -> Dictionary:
	var attack_mode := str(request_context.get("attack_mode", current_attack_mode))
	var runtime_skill := _get_runtime_skill_config(attack_mode, skill_id)
	if runtime_skill.is_empty():
		return {"success": false}
	var configured_stages: Array = runtime_skill.get("stages", [])
	if not (configured_stages is Array) or configured_stages.is_empty():
		return {"success": false}

	var stages: Array = []
	var combo_end_time := 0.0
	for stage_entry in configured_stages:
		if not (stage_entry is Dictionary):
			continue
		var stage := (stage_entry as Dictionary).duplicate(true)
		stage["time"] = maxf(float(stage.get("time", 0.0)), 0.0)
		stage["range_meters"] = maxf(float(stage.get("range_meters", 0.0)), 0.0)
		stage["arc_degrees"] = maxf(float(stage.get("arc_degrees", 90.0)), 1.0)
		stage["damage"] = max(0, int(stage.get("damage", 0)))
		stage["flash_duration"] = maxf(float(stage.get("flash_duration", 0.16)), 0.01)
		stage["effect_color"] = stage.get("effect_color", Color(1.0, 0.36, 0.36, 0.8))
		stages.append(stage)
		combo_end_time = maxf(combo_end_time, float(stage["time"]))
	if stages.is_empty():
		return {"success": false}

	combo_end_time += maxf(float(runtime_skill.get("combo_tail", 0.08)), 0.02)
	current_skill_execution_state = {
		"sequence_type": "multi_stage_sector",
		"stages": stages,
		"resolved_stage_count": 0,
		"elapsed": 0.0,
		"combo_end_time": combo_end_time,
	}
	attack_phase = "multi_stage_sector_active"
	attack_timer_remaining = combo_end_time
	return {
		"success": true,
		"cooldown_duration": _get_attack_cooldown(attack_mode),
	}


func collect_ai_perception(_preset, blackboard) -> Dictionary:
	var player_target: Node2D = null
	if blackboard != null and is_instance_valid(blackboard.forced_target):
		player_target = blackboard.forced_target

	var can_target_player: bool = is_hostile_to_player() and _has_live_player()
	if player_target == null and can_target_player:
		player_target = village.get_player_node()

	var player_position: Vector2 = Vector2.ZERO
	var distance_to_player_pixels: float = INF
	var distance_to_player_meters: float = INF
	var player_in_detect_range: bool = false
	var player_in_primary_range: bool = false
	var player_in_fallback_range: bool = false

	if player_target != null and is_instance_valid(player_target):
		player_position = player_target.global_position
		distance_to_player_pixels = global_position.distance_to(player_position)
		distance_to_player_meters = distance_to_player_pixels / meters_to_pixels
		player_in_detect_range = is_target_detectable(player_target)
		player_in_primary_range = distance_to_player_pixels <= get_attack_range_pixels("primary")
		player_in_fallback_range = distance_to_player_pixels <= get_attack_range_pixels("fallback")
		if ENABLE_ATTACK_AREA_DETECTION and get_enemy_role() == "melee" and not is_target_inside_attack_area(player_target):
			player_in_primary_range = false

	return {
		"player": player_target,
		"player_position": player_position,
		"can_target_player": can_target_player and player_target != null and is_instance_valid(player_target),
		"player_in_detect_range": player_in_detect_range,
		"player_in_primary_range": player_in_primary_range,
		"player_in_fallback_range": player_in_fallback_range,
		"primary_skill_id": _resolve_attack_mode_skill_id("primary"),
		"fallback_skill_id": _resolve_attack_mode_skill_id("fallback"),
		"primary_attack_ready": is_attack_ready("primary"),
		"fallback_attack_ready": is_attack_ready("fallback"),
		"is_executing_attack": is_executing_attack(),
		"distance_to_player_pixels": distance_to_player_pixels,
		"distance_to_player_meters": distance_to_player_meters,
		"at_home": has_arrived_home(),
		"health_ratio": get_health_ratio(),
	}


func get_attack_profile(base_damage: int) -> Dictionary:
	var role: String = get_enemy_role()
	var default_hit_rate: float = 88.0
	var default_crit_rate: float = 8.0
	var default_crit_damage: float = 1.5

	match role:
		"ranged":
			default_hit_rate = 90.0
			default_crit_rate = 12.0
			default_crit_damage = 1.6
		"boss":
			default_hit_rate = 94.0
			default_crit_rate = 18.0
			default_crit_damage = 1.8

	return {
		"base_damage": base_damage,
		"hit_rate": float(enemy_config.get("hit_rate", default_hit_rate)),
		"crit_rate": float(enemy_config.get("crit_rate", default_crit_rate)),
		"crit_damage": float(enemy_config.get("crit_damage", default_crit_damage)),
	}


func take_damage(damage: int) -> void:
	if damage <= 0:
		return

	if village != null and village.has_method("is_result_showing") and village.is_result_showing():
		return

	enemy_data["health"] = max(int(enemy_data["health"]) - damage, 0)
	body.color = Color(1.0, 0.82, 0.82, 1.0)
	if uses_sprite_visuals and visual_sprite != null:
		visual_sprite.modulate = Color(1.0, 0.82, 0.82, 1.0)
	var tween: Tween = create_tween()
	tween.tween_interval(0.1)
	tween.tween_callback(func() -> void:
		body.color = enemy_config["display_color"] as Color
		if uses_sprite_visuals and visual_sprite != null:
			visual_sprite.modulate = visual_base_modulate
	)
	_update_health_label()

	if int(enemy_data["health"]) <= 0:
		emit_signal("enemy_died", self)


func get_display_name() -> String:
	return str(enemy_config.get("display_name", enemy_config.get("name", "")))


func get_overhead_display_debug_state() -> Dictionary:
	if overhead_display == null or not is_instance_valid(overhead_display):
		return {}
	return overhead_display.call("get_debug_state")


func is_attack_ready(attack_mode: String) -> bool:
	var skill_id := _resolve_attack_mode_skill_id(attack_mode)
	if skill_id.is_empty():
		return false
	return SkillRuntime.can_trigger_skill(skill_runtime_state, skill_id)


func is_executing_attack() -> bool:
	return attack_phase != ""


func begin_attack(attack_mode: String = "primary") -> bool:
	var skill_id := _resolve_attack_mode_skill_id(attack_mode)
	if skill_id.is_empty() or is_executing_attack() or not is_attack_ready(attack_mode):
		return false

	current_skill_id = skill_id
	current_attack_mode = attack_mode
	attack_phase = "windup"
	attack_has_fired = false
	current_attack_direction = _get_attack_direction()
	current_skill_execution_state = _prepare_attack_execution_state(skill_id, attack_mode)
	if current_skill_execution_state.has("locked_direction"):
		var locked_direction := Vector2(current_skill_execution_state.get("locked_direction", current_attack_direction))
		if locked_direction != Vector2.ZERO:
			current_attack_direction = locked_direction.normalized()
	attack_timer_remaining = _get_windup_duration(attack_mode)
	return true


func execute_move_to_position(target_position: Vector2, delta: float) -> void:
	_move_toward_position(target_position, delta)


func execute_move_away_from_position(origin_position: Vector2, delta: float, speed_multiplier: float = 1.0) -> void:
	_move_away_from_position(origin_position, delta, speed_multiplier)


func execute_return_home(delta: float) -> void:
	_move_toward_position(home_position, delta)


func execute_stop() -> void:
	pass


func has_arrived_home() -> bool:
	return global_position.distance_to(home_position) <= meters_to_pixels * 0.15


func reset_ai_runtime_state(preserve_attack_cooldown: bool = false, interrupt_attack: bool = true) -> void:
	if interrupt_attack:
		attack_phase = ""
		attack_timer_remaining = 0.0
		attack_has_fired = false
		current_attack_mode = "primary"
		current_skill_id = ""
		current_skill_execution_state = {}
		current_attack_direction = Vector2.RIGHT
		attack_arc.visible = false

	if not preserve_attack_cooldown:
		for skill_id in SkillRuntime.get_owned_skill_ids(skill_runtime_state):
			SkillRuntime.clear_cooldown(skill_runtime_state, skill_id)


func get_attack_range_pixels(attack_mode: String = "primary") -> float:
	var effective_attack_range: float = _get_skill_trigger_range_meters(attack_mode)
	if attack_mode == "primary":
		effective_attack_range = maxf(float(enemy_config.get("attack_range", 0.0)), effective_attack_range)
	return effective_attack_range * meters_to_pixels


func is_target_detectable(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if _is_target_inside_detect_area(target):
		return true

	return global_position.distance_to(target.global_position) <= _get_detection_range_pixels()


func is_target_inside_attack_area(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or not target.has_method("get_hitbox_area"):
		return false

	var target_hitbox: Area2D = target.get_hitbox_area()
	if target_hitbox == null:
		return false

	return attack_area.overlaps_area(target_hitbox)


func _has_live_player() -> bool:
	return village != null and village.has_method("is_player_alive") and village.is_player_alive()


func _update_attack_execution(delta: float) -> void:
	if attack_phase == "":
		return

	attack_timer_remaining -= delta

	if attack_phase == "dash_active":
		_update_fixed_dash_execution(delta)
		return

	if attack_phase == "bite_combo_active":
		_update_multi_bite_execution(delta)
		return

	if attack_phase == "multi_stage_sector_active":
		_update_multi_stage_sector_execution(delta)
		return

	if attack_phase == "windup" and attack_timer_remaining <= 0.0:
		if not attack_has_fired:
			_fire_skill()
			attack_has_fired = true

		if attack_phase == "windup":
			attack_phase = "recovery"
			attack_timer_remaining = _get_postcast_duration(current_attack_mode)
		return

	if attack_phase == "recovery" and attack_timer_remaining <= 0.0:
		if not current_skill_execution_state.is_empty():
			last_skill_execution_state = current_skill_execution_state.duplicate(true)
		attack_phase = ""
		attack_timer_remaining = 0.0
		attack_has_fired = false
		current_skill_id = ""
		current_skill_execution_state = {}


func _get_attack_direction() -> Vector2:
	if village == null or not village.has_method("get_player_global_position"):
		return Vector2.RIGHT

	var attack_direction: Vector2 = (village.get_player_global_position() - global_position).normalized()
	if attack_direction == Vector2.ZERO:
		return Vector2.RIGHT
	return attack_direction


func _fire_skill() -> void:
	if current_skill_id.is_empty():
		return
	if SkillExecutor.request_execute(self, skill_runtime_state, current_skill_id, {
		"attack_mode": current_attack_mode,
	}):
		last_executed_skill_id = current_skill_id


func _show_attack_arc(range_meters: float, arc_degrees: float, effect_color: Color, flash_duration: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	var radius_pixels: float = range_meters * meters_to_pixels
	var half_arc_radians: float = deg_to_rad(arc_degrees * 0.5)
	var steps: int = 14

	for step in range(steps + 1):
		var t: float = float(step) / float(steps)
		var angle: float = lerpf(-half_arc_radians, half_arc_radians, t)
		points.append(Vector2(cos(angle), sin(angle)) * radius_pixels)

	attack_arc.polygon = points
	attack_arc.rotation = current_attack_direction.angle()
	attack_arc.color = effect_color
	attack_arc.visible = true

	var tween: Tween = create_tween()
	tween.tween_interval(flash_duration)
	tween.tween_callback(func() -> void:
		attack_arc.visible = false
	)


func _move_toward_position(target_position: Vector2, delta: float, speed_multiplier: float = 1.0) -> void:
	var direction_to_target: Vector2 = (target_position - global_position).normalized()
	if direction_to_target == Vector2.ZERO:
		return

	var motion: Vector2 = direction_to_target * _get_move_speed_pixels() * speed_multiplier * delta
	if village.has_method("resolve_world_movement"):
		global_position = village.resolve_world_movement(global_position, motion, get_hitbox_half_size_pixels())
	else:
		global_position += motion


func _move_away_from_position(origin_position: Vector2, delta: float, speed_multiplier: float = 1.0) -> void:
	var direction_away: Vector2 = (global_position - origin_position).normalized()
	if direction_away == Vector2.ZERO:
		direction_away = Vector2.LEFT

	var motion: Vector2 = direction_away * _get_move_speed_pixels() * speed_multiplier * delta
	if village.has_method("resolve_world_movement"):
		global_position = village.resolve_world_movement(global_position, motion, get_hitbox_half_size_pixels())
	else:
		global_position += motion


func _get_move_speed_pixels() -> float:
	return float(enemy_config["move_speed"]) * meters_to_pixels


func _get_detection_range_pixels() -> float:
	return detection_range_meters * meters_to_pixels


func _get_attack_cooldown(attack_mode: String = "primary") -> float:
	var runtime_stats: Dictionary = _get_runtime_stats(attack_mode)
	if attack_mode == "fallback":
		return float(runtime_stats.get("fallback_attack_cooldown", runtime_stats["attack_cooldown"]))
	if get_enemy_role() == "ranged":
		return float(runtime_stats.get("ranged_attack_cooldown", runtime_stats["attack_cooldown"]))
	return float(runtime_stats["attack_cooldown"])


func _get_windup_duration(attack_mode: String = "primary") -> float:
	var runtime_stats: Dictionary = _get_runtime_stats(attack_mode)
	if attack_mode == "fallback":
		return float(runtime_stats.get("fallback_windup", runtime_stats["windup"]))
	return float(runtime_stats["windup"])


func _get_postcast_duration(attack_mode: String = "primary") -> float:
	var runtime_stats: Dictionary = _get_runtime_stats(attack_mode)
	if attack_mode == "fallback":
		return float(runtime_stats.get("fallback_recovery", runtime_stats["recovery"]))
	return float(runtime_stats["recovery"])


func _get_runtime_stats(attack_mode: String = "primary") -> Dictionary:
	var runtime_stats: Dictionary = enemy_config.duplicate(true)

	if _is_phase_two():
		var phase_two: Dictionary = enemy_config["phase_two"] as Dictionary
		runtime_stats["attack_cooldown"] = float(runtime_stats["attack_cooldown"]) * float(phase_two["cooldown_multiplier"])
		if runtime_stats.has("ranged_attack_cooldown"):
			runtime_stats["ranged_attack_cooldown"] = float(runtime_stats["ranged_attack_cooldown"]) * float(phase_two["cooldown_multiplier"])
		if runtime_stats.has("fallback_attack_cooldown"):
			runtime_stats["fallback_attack_cooldown"] = float(runtime_stats["fallback_attack_cooldown"]) * float(phase_two["cooldown_multiplier"])

	return runtime_stats


func _get_runtime_skill_config(attack_mode: String = "primary", skill_id: String = "") -> Dictionary:
	var resolved_skill_id := skill_id if not skill_id.is_empty() else _resolve_attack_mode_skill_id(attack_mode)
	if resolved_skill_id.is_empty():
		return {}
	var definition := SkillRuntime.get_definition(skill_runtime_state, resolved_skill_id)
	if definition.is_empty():
		return {}
	var runtime_skill: Dictionary = (definition.get("parameters", {}) as Dictionary).duplicate(true)
	if runtime_skill.is_empty():
		return {}

	var uses_formal_skill_ids := enemy_config.has("skill_bindings") or enemy_config.has("skill_ids") or enemy_config.has("skill_definitions")
	if attack_mode == "fallback" and get_enemy_role() == "ranged" and enemy_config.has("skill") and not uses_formal_skill_ids:
		var fallback_damage_ratio: float = float(enemy_config.get("fallback_attack_damage_ratio", 0.5))
		runtime_skill = {
			"type": "sector",
			"name": str(enemy_config.get("fallback_attack_name", "近身反击")),
			"range_meters": float(enemy_config.get("fallback_attack_range", 0.9)),
			"arc_degrees": float(enemy_config.get("fallback_attack_arc_degrees", 100.0)),
			"damage": max(1, int(round(float((enemy_config["skill"] as Dictionary)["damage"]) * fallback_damage_ratio))),
			"flash_duration": float(enemy_config.get("fallback_flash_duration", 0.12)),
			"effect_color": enemy_config.get("fallback_effect_color", Color(1.0, 0.72, 0.56, 0.7)),
		}

	if _is_phase_two():
		var phase_two: Dictionary = enemy_config["phase_two"] as Dictionary
		if runtime_skill.has("damage"):
			runtime_skill["damage"] = int(round(float(runtime_skill["damage"]) * float(phase_two["damage_multiplier"])))
		if attack_mode != "fallback" and runtime_skill.has("range_meters"):
			runtime_skill["range_meters"] = float(runtime_skill["range_meters"]) + float(phase_two["range_bonus"])
		if runtime_skill.has("stages"):
			var phase_two_stages: Array = []
			for stage_entry in runtime_skill.get("stages", []):
				if not (stage_entry is Dictionary):
					continue
				var stage := (stage_entry as Dictionary).duplicate(true)
				stage["damage"] = int(round(float(stage.get("damage", 0)) * float(phase_two["damage_multiplier"])))
				stage["range_meters"] = float(stage.get("range_meters", 0.0)) + float(phase_two["range_bonus"])
				phase_two_stages.append(stage)
			runtime_skill["stages"] = phase_two_stages

	return runtime_skill


func _get_skill_trigger_range_meters(attack_mode: String = "primary") -> float:
	var runtime_skill: Dictionary = _get_runtime_skill_config(attack_mode)
	if runtime_skill.is_empty():
		return float(enemy_config.get("attack_range", 0.0))
	if runtime_skill.has("ai_trigger_range_meters"):
		return float(runtime_skill.get("ai_trigger_range_meters", enemy_config.get("attack_range", 0.0)))
	return float(runtime_skill.get("range_meters", enemy_config.get("attack_range", 0.0)))


func _setup_skill_runtime() -> void:
	var runtime_payload := _build_runtime_skill_payload()
	var skill_definitions: Array = runtime_payload.get("definitions", [])
	skill_mode_bindings = (runtime_payload.get("bindings", {}) as Dictionary).duplicate(true)
	var owned_skill_ids: Array[String] = []
	var equipped_skill_ids: Array[String] = []
	var seen_skill_ids: Dictionary = {}
	for attack_mode in ["primary", "fallback"]:
		var skill_id := str(skill_mode_bindings.get(attack_mode, ""))
		if skill_id.is_empty() or seen_skill_ids.has(skill_id):
			continue
		seen_skill_ids[skill_id] = true
		owned_skill_ids.append(skill_id)
		equipped_skill_ids.append(skill_id)
	if owned_skill_ids.is_empty():
		for definition in skill_definitions:
			var fallback_skill_id := str((definition as Dictionary).get("skill_id", ""))
			if fallback_skill_id.is_empty() or seen_skill_ids.has(fallback_skill_id):
				continue
			seen_skill_ids[fallback_skill_id] = true
			owned_skill_ids.append(fallback_skill_id)
			equipped_skill_ids.append(fallback_skill_id)
	var slot_count: int = max(equipped_skill_ids.size(), owned_skill_ids.size())
	skill_runtime_state = SkillRuntime.build_owner_runtime(
		get_display_name(),
		actor_kind,
		slot_count,
		skill_definitions,
		owned_skill_ids,
		equipped_skill_ids
	)


func _build_runtime_skill_payload() -> Dictionary:
	return SkillRegistry.build_actor_skill_payload(enemy_config, get_display_name())
	if enemy_config.has("skill_definitions"):
		return {
			"definitions": (enemy_config.get("skill_definitions", []) as Array).duplicate(true),
			"bindings": (enemy_config.get("skill_bindings", {}) as Dictionary).duplicate(true),
		}

	var definitions: Array = []
	var bindings: Dictionary = {}
	var name_slug := get_display_name().to_lower().replace(" ", "_")
	if enemy_config.has("skill"):
		var primary_skill := (enemy_config.get("skill", {}) as Dictionary).duplicate(true)
		var primary_skill_id := "%s_primary_skill" % name_slug
		definitions.append({
			"skill_id": primary_skill_id,
			"display_name": str(primary_skill.get("name", "%s技能" % get_display_name())),
			"skill_type": "active",
			"tags": ["enemy", str(enemy_config.get("role", "")), "primary"],
			"summary": "由敌人 AI 主动触发的主要攻击技能。",
			"execution_key": "enemy_projectile_attack" if str(primary_skill.get("type", "sector")) == "projectile" else "enemy_sector_attack",
			"parameters": primary_skill,
		})
		bindings["primary"] = primary_skill_id

	if get_enemy_role() == "ranged":
		var primary_damage := float((enemy_config.get("skill", {}) as Dictionary).get("damage", 1))
		var fallback_damage_ratio: float = float(enemy_config.get("fallback_attack_damage_ratio", 0.5))
		var fallback_skill_id := "%s_fallback_skill" % name_slug
		definitions.append({
			"skill_id": fallback_skill_id,
			"display_name": str(enemy_config.get("fallback_attack_name", "近身反击")),
			"skill_type": "active",
			"tags": ["enemy", str(enemy_config.get("role", "")), "fallback"],
			"summary": "当玩家贴身时由 AI 主动触发的后备近战技能。",
			"execution_key": "enemy_sector_attack",
			"parameters": {
				"type": "sector",
				"name": str(enemy_config.get("fallback_attack_name", "近身反击")),
				"range_meters": float(enemy_config.get("fallback_attack_range", 0.9)),
				"arc_degrees": float(enemy_config.get("fallback_attack_arc_degrees", 100.0)),
				"damage": max(1, int(round(primary_damage * fallback_damage_ratio))),
				"flash_duration": float(enemy_config.get("fallback_flash_duration", 0.12)),
				"effect_color": enemy_config.get("fallback_effect_color", Color(1.0, 0.72, 0.56, 0.7)),
			},
		})
		bindings["fallback"] = fallback_skill_id

	return {
		"definitions": definitions,
		"bindings": bindings,
	}


func _resolve_attack_mode_skill_id(attack_mode: String) -> String:
	var normalized_mode := attack_mode if attack_mode == "fallback" else "primary"
	var resolved_skill_id := str(skill_mode_bindings.get(normalized_mode, ""))
	if not resolved_skill_id.is_empty():
		return resolved_skill_id
	if normalized_mode == "fallback":
		return str(skill_mode_bindings.get("primary", ""))
	return SkillRuntime.get_equipped_skill_id_at_slot(skill_runtime_state, 0)


func _resolve_skill_attack_mode(skill_id: String) -> String:
	for attack_mode in skill_mode_bindings.keys():
		if str(skill_mode_bindings[attack_mode]) == skill_id:
			return str(attack_mode)
	return ""


func _prepare_attack_execution_state(skill_id: String, attack_mode: String) -> Dictionary:
	var definition := SkillRuntime.get_definition(skill_runtime_state, skill_id)
	if definition.is_empty():
		return {}
	match str(definition.get("execution_key", "")):
		"enemy_fixed_dash_attack":
			return _build_fixed_dash_execution_state(attack_mode, skill_id)
		_:
			return {}


func _build_fixed_dash_execution_state(attack_mode: String, skill_id: String) -> Dictionary:
	var runtime_skill := _get_runtime_skill_config(attack_mode, skill_id)
	if runtime_skill.is_empty():
		return {}
	if village == null or not village.has_method("get_player_node"):
		return {"sequence_type": "fixed_dash", "target_found": false}
	var player_target: Node2D = village.get_player_node()
	if player_target == null or not is_instance_valid(player_target):
		return {"sequence_type": "fixed_dash", "target_found": false}
	var player_position: Vector2 = player_target.global_position
	var player_facing: Vector2 = _resolve_player_facing_direction(player_target)
	var behind_direction: Vector2 = -player_facing
	if behind_direction == Vector2.ZERO:
		behind_direction = (player_position - global_position).normalized()
	if behind_direction == Vector2.ZERO:
		behind_direction = Vector2.LEFT
	var desired_target_position: Vector2 = player_position + behind_direction * float(runtime_skill.get("behind_offset_meters", 1.1)) * meters_to_pixels
	var resolved_target: Vector2 = desired_target_position
	var target_found: bool = true
	if village.has_method("resolve_walkable_target_point"):
		var resolved: Dictionary = village.resolve_walkable_target_point(
			desired_target_position,
			get_hitbox_half_size_pixels(),
			float(runtime_skill.get("landing_search_radius_meters", 1.8)) * meters_to_pixels,
			global_position
		)
		target_found = bool(resolved.get("success", false))
		resolved_target = Vector2(resolved.get("position", desired_target_position))
	var locked_direction: Vector2 = (resolved_target - global_position).normalized()
	if locked_direction == Vector2.ZERO:
		locked_direction = current_attack_direction if current_attack_direction != Vector2.ZERO else Vector2.RIGHT
	return {
		"sequence_type": "fixed_dash",
		"target_found": target_found,
		"locked_player_position": player_position,
		"locked_player_facing": player_facing,
		"behind_direction": behind_direction,
		"desired_target_position": desired_target_position,
		"dash_target_position": resolved_target,
		"locked_direction": locked_direction,
	}


func _resolve_player_facing_direction(player_target: Node2D) -> Vector2:
	if village != null and village.has_method("get_player_facing_direction"):
		var facing: Vector2 = village.get_player_facing_direction()
		if facing != Vector2.ZERO:
			return facing.normalized()
	if player_target != null and player_target.has_method("get_facing_direction"):
		var player_facing: Vector2 = player_target.get_facing_direction()
		if player_facing != Vector2.ZERO:
			return player_facing.normalized()
	var fallback_direction := (player_target.global_position - global_position).normalized() if player_target != null else Vector2.ZERO
	if fallback_direction == Vector2.ZERO:
		return Vector2.RIGHT
	return fallback_direction


func _update_fixed_dash_execution(delta: float) -> void:
	if current_skill_execution_state.is_empty():
		attack_phase = "recovery"
		attack_timer_remaining = _get_postcast_duration(current_attack_mode)
		return
	var target_position := Vector2(current_skill_execution_state.get("dash_target_position", global_position))
	var previous_distance := global_position.distance_to(target_position)
	var speed_multiplier := float(current_skill_execution_state.get("speed_multiplier", 3.0))
	_move_toward_position(target_position, delta, speed_multiplier)
	var new_distance := global_position.distance_to(target_position)
	current_skill_execution_state["dash_elapsed"] = float(current_skill_execution_state.get("dash_elapsed", 0.0)) + delta
	current_skill_execution_state["remaining_distance_pixels"] = new_distance
	if new_distance > 0.01:
		current_attack_direction = (target_position - global_position).normalized()
	var arrival_threshold := float(current_skill_execution_state.get("arrival_threshold_pixels", meters_to_pixels * 0.24))
	if new_distance <= arrival_threshold or attack_timer_remaining <= 0.0:
		current_skill_execution_state["completed_reason"] = "arrived" if new_distance <= arrival_threshold else "timeout"
		current_skill_execution_state["final_distance_pixels"] = new_distance
		last_skill_execution_state = current_skill_execution_state.duplicate(true)
		current_skill_execution_state = {}
		attack_phase = "recovery"
		attack_timer_remaining = _get_postcast_duration(current_attack_mode)
	elif new_distance > previous_distance + 1.0:
		current_skill_execution_state["completed_reason"] = "blocked"
		last_skill_execution_state = current_skill_execution_state.duplicate(true)
		current_skill_execution_state = {}
		attack_phase = "recovery"
		attack_timer_remaining = _get_postcast_duration(current_attack_mode)


func _update_multi_bite_execution(delta: float) -> void:
	if current_skill_execution_state.is_empty():
		attack_phase = "recovery"
		attack_timer_remaining = _get_postcast_duration(current_attack_mode)
		return
	var elapsed := float(current_skill_execution_state.get("elapsed", 0.0)) + delta
	var total_hits := int(current_skill_execution_state.get("combo_hits_total", 0))
	var hits_resolved := int(current_skill_execution_state.get("combo_hits_resolved", 0))
	var next_hit_time := float(current_skill_execution_state.get("next_hit_time", 0.0))
	var bite_interval := float(current_skill_execution_state.get("bite_interval", 0.18))
	var damage := int(current_skill_execution_state.get("damage", 0))
	var attack_profile := get_attack_profile(damage)
	while hits_resolved < total_hits and elapsed + 0.0001 >= next_hit_time:
		_show_attack_arc(
			float(current_skill_execution_state.get("range_pixels", meters_to_pixels)) / meters_to_pixels,
			float(current_skill_execution_state.get("arc_degrees", 115.0)),
			current_skill_execution_state.get("effect_color", Color(0.92, 0.96, 1.0, 0.84)),
			float(current_skill_execution_state.get("flash_duration", 0.09))
		)
		if village != null and village.has_method("apply_enemy_sector_attack"):
			village.apply_enemy_sector_attack(
				get_display_name(),
				global_position,
				current_attack_direction,
				float(current_skill_execution_state.get("range_pixels", meters_to_pixels)),
				float(current_skill_execution_state.get("arc_degrees", 115.0)),
				damage,
				attack_profile
			)
		hits_resolved += 1
		next_hit_time += bite_interval
	current_skill_execution_state["elapsed"] = elapsed
	current_skill_execution_state["combo_hits_resolved"] = hits_resolved
	current_skill_execution_state["next_hit_time"] = next_hit_time
	if hits_resolved >= total_hits and elapsed + 0.0001 >= float(current_skill_execution_state.get("combo_end_time", 0.0)):
		current_skill_execution_state["completed_reason"] = "combo_complete"
		last_skill_execution_state = current_skill_execution_state.duplicate(true)
		current_skill_execution_state = {}
		attack_phase = "recovery"
		attack_timer_remaining = _get_postcast_duration(current_attack_mode)


func _update_multi_stage_sector_execution(delta: float) -> void:
	if current_skill_execution_state.is_empty():
		attack_phase = "recovery"
		attack_timer_remaining = _get_postcast_duration(current_attack_mode)
		return

	var elapsed := float(current_skill_execution_state.get("elapsed", 0.0)) + delta
	var stages: Array = current_skill_execution_state.get("stages", [])
	var resolved_stage_count := int(current_skill_execution_state.get("resolved_stage_count", 0))
	while resolved_stage_count < stages.size():
		var stage_entry: Variant = stages[resolved_stage_count]
		if not (stage_entry is Dictionary):
			resolved_stage_count += 1
			continue
		var stage := stage_entry as Dictionary
		if elapsed + 0.0001 < float(stage.get("time", 0.0)):
			break
		var damage := int(stage.get("damage", 0))
		var attack_profile := get_attack_profile(damage)
		_show_attack_arc(
			float(stage.get("range_meters", 0.0)),
			float(stage.get("arc_degrees", 120.0)),
			stage.get("effect_color", Color(1.0, 0.36, 0.36, 0.8)),
			float(stage.get("flash_duration", 0.16))
		)
		if village != null and village.has_method("apply_enemy_sector_attack"):
			village.apply_enemy_sector_attack(
				get_display_name(),
				global_position,
				current_attack_direction,
				float(stage.get("range_meters", 0.0)) * meters_to_pixels,
				float(stage.get("arc_degrees", 120.0)),
				damage,
				attack_profile
			)
		resolved_stage_count += 1
	current_skill_execution_state["elapsed"] = elapsed
	current_skill_execution_state["resolved_stage_count"] = resolved_stage_count
	if resolved_stage_count >= stages.size() and elapsed + 0.0001 >= float(current_skill_execution_state.get("combo_end_time", 0.0)):
		current_skill_execution_state["completed_reason"] = "combo_complete"
		last_skill_execution_state = current_skill_execution_state.duplicate(true)
		current_skill_execution_state = {}
		attack_phase = "recovery"
		attack_timer_remaining = _get_postcast_duration(current_attack_mode)


func _is_phase_two() -> bool:
	if not enemy_config.has("phase_two"):
		return false

	if str(enemy_config["role"]) != "boss":
		return false

	return float(enemy_data["health"]) <= float(enemy_data["max_health"]) * 0.5


func _apply_visuals() -> void:
	var half_size_pixels: Vector2 = get_hitbox_half_size_pixels()
	body.offset_left = -half_size_pixels.x
	body.offset_top = -half_size_pixels.y
	body.offset_right = half_size_pixels.x
	body.offset_bottom = half_size_pixels.y
	body.color = enemy_config["display_color"] as Color
	var hurtbox_rectangle := RectangleShape2D.new()
	hurtbox_rectangle.size = half_size_pixels * 2.0
	hurtbox_shape.shape = hurtbox_rectangle

	_disable_legacy_overhead_labels()
	_sync_overhead_display()
	attack_arc.visible = false
	_configure_visual_sprite()


func _configure_visual_sprite() -> void:
	if visual_sprite == null:
		return

	var visual_config := enemy_config.get("body_visual", enemy_config.get("visual", {})) as Dictionary
	uses_sprite_visuals = not visual_config.is_empty()
	current_visual_configured_sprite_frames_path = str(visual_config.get("sprite_frames_path", ""))
	current_visual_sheet_path = str(visual_config.get("sheet_path", ""))
	if not uses_sprite_visuals:
		body.visible = true
		visual_sprite.visible = false
		visual_sprite.sprite_frames = null
		visual_sprite.flip_h = false
		current_visual_mirror_right_from_left = false
		current_visual_mirror_left_from_right = false
		return

	var sprite_frames_path := current_visual_configured_sprite_frames_path
	var can_load_imported_sprite_frames := not sprite_frames_path.is_empty() and ResourceLoader.exists(sprite_frames_path, "SpriteFrames") and (current_visual_sheet_path.is_empty() or ResourceLoader.exists(current_visual_sheet_path, "Texture2D"))
	var sprite_frames_resource := load(sprite_frames_path) as SpriteFrames if can_load_imported_sprite_frames else null
	if sprite_frames_resource == null:
		sprite_frames_resource = _build_sprite_frames_from_visual_config(visual_config)
	if sprite_frames_resource == null:
		push_error("EnemyActor[%s] failed to resolve sprite visuals from %s / %s" % [get_display_name(), sprite_frames_path, current_visual_sheet_path])
		uses_sprite_visuals = false
		body.visible = true
		visual_sprite.visible = false
		visual_sprite.sprite_frames = null
		return

	body.visible = false
	visual_sprite.visible = true
	visual_sprite.sprite_frames = sprite_frames_resource
	visual_sprite.centered = true
	visual_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var visual_scale := float(visual_config.get("display_scale", 0.0625))
	visual_sprite.scale = Vector2(visual_scale, visual_scale)
	var anchor_offset_value: Variant = visual_config.get("anchor_offset_pixels", Vector2(0.0, -8.0))
	current_visual_anchor_offset = anchor_offset_value as Vector2 if anchor_offset_value is Vector2 else Vector2(0.0, -8.0)
	visual_sprite.position = current_visual_anchor_offset
	current_visual_direction = str(visual_config.get("default_facing", "down"))
	current_visual_mirror_right_from_left = bool(visual_config.get("mirror_right_from_left", false))
	current_visual_mirror_left_from_right = bool(visual_config.get("mirror_left_from_right", false))
	visual_base_modulate = Color.WHITE if bool(visual_config.get("use_raw_texture_colors", true)) else (enemy_config["display_color"] as Color)
	visual_sprite.modulate = visual_base_modulate
	visual_sprite.flip_h = _should_flip_visual_for_direction(current_visual_direction)
	_update_visual_state(Vector2.ZERO)


func _build_sprite_frames_from_visual_config(visual_config: Dictionary) -> SpriteFrames:
	var frame_sets_variant: Variant = visual_config.get("frame_sets", {})
	if not (frame_sets_variant is Dictionary):
		return null
	var frame_sets := frame_sets_variant as Dictionary
	if frame_sets.is_empty():
		return null
	if current_visual_sheet_path.is_empty():
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(current_visual_sheet_path))
	if image == null or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	if texture == null:
		return null

	var sprite_frames := SpriteFrames.new()
	var animation_order: Array[String] = [
		"idle_down",
		"idle_up",
		"idle_left",
		"idle_right",
		"move_down",
		"move_up",
		"move_left",
		"move_right",
	]
	for animation_name_variant in frame_sets.keys():
		var animation_name := str(animation_name_variant)
		if animation_order.has(animation_name):
			continue
		animation_order.append(animation_name)
	for animation_name in animation_order:
		if not frame_sets.has(animation_name):
			continue
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_loop(animation_name, true)
		sprite_frames.set_animation_speed(animation_name, 7.0 if animation_name.begins_with("move_") else 5.0)
		for region_value in frame_sets[animation_name]:
			var region_rect := region_value as Rect2
			var atlas_texture := AtlasTexture.new()
			atlas_texture.atlas = texture
			atlas_texture.region = region_rect
			sprite_frames.add_frame(animation_name, atlas_texture, 1.0)
	return sprite_frames


func _update_visual_state(motion: Vector2) -> void:
	if not uses_sprite_visuals or visual_sprite == null or visual_sprite.sprite_frames == null:
		return

	var is_moving := motion.length() > 0.05
	if attack_phase != "" and current_attack_direction != Vector2.ZERO:
		current_visual_direction = _resolve_visual_direction_from_motion(current_attack_direction)
	elif is_moving:
		current_visual_direction = _resolve_visual_direction_from_motion(motion)
	var animation_name := _resolve_visual_animation_name(is_moving)
	if animation_name.is_empty():
		visual_sprite.flip_h = false
		return
	visual_sprite.flip_h = _should_flip_visual_for_direction(current_visual_direction)
	if str(visual_sprite.animation) != animation_name or not visual_sprite.is_playing():
		visual_sprite.play(animation_name)


func _resolve_visual_animation_name(is_moving: bool) -> String:
	var fallback_order: Array[String] = []
	var movement_prefix := "move" if is_moving else "idle"
	if attack_phase != "":
		fallback_order.append("attack_%s" % current_visual_direction)
		fallback_order.append("%s_%s" % [attack_phase, current_visual_direction])
	fallback_order.append("%s_%s" % [movement_prefix, current_visual_direction])
	fallback_order.append("idle_%s" % current_visual_direction)
	fallback_order.append("move_%s" % current_visual_direction)
	if current_visual_mirror_right_from_left and current_visual_direction == "right":
		fallback_order.append("%s_left" % movement_prefix)
		fallback_order.append("idle_left")
		fallback_order.append("move_left")
	if current_visual_mirror_left_from_right and current_visual_direction == "left":
		fallback_order.append("%s_right" % movement_prefix)
		fallback_order.append("idle_right")
		fallback_order.append("move_right")
	fallback_order.append("idle_down")
	fallback_order.append("move_down")

	var seen: Dictionary = {}
	for animation_name in fallback_order:
		if seen.has(animation_name):
			continue
		seen[animation_name] = true
		if visual_sprite.sprite_frames.has_animation(animation_name):
			return animation_name

	var animation_names := visual_sprite.sprite_frames.get_animation_names()
	if animation_names.is_empty():
		return ""
	return str(animation_names[0])


func _resolve_visual_direction_from_motion(motion: Vector2) -> String:
	if absf(motion.x) > absf(motion.y):
		return "right" if motion.x > 0.0 else "left"
	return "down" if motion.y > 0.0 else "up"


func _should_flip_visual_for_direction(direction: String) -> bool:
	if current_visual_mirror_right_from_left and direction == "right":
		return true
	if current_visual_mirror_left_from_right and direction == "left":
		return true
	return false


func _update_health_label() -> void:
	_sync_overhead_display()


func _ensure_overhead_display() -> void:
	if overhead_display != null and is_instance_valid(overhead_display):
		return
	var existing := get_node_or_null("OverheadDisplay")
	if existing != null and existing.has_method("sync_display"):
		overhead_display = existing
		return
	var instance := OverheadDisplayScene.instantiate()
	if instance != null and instance.has_method("sync_display"):
		overhead_display = instance
		overhead_display.name = "OverheadDisplay"
		add_child(overhead_display)


func _disable_legacy_overhead_labels() -> void:
	if name_label != null:
		name_label.visible = false
		name_label.text = ""
	if health_label != null:
		health_label.visible = false
		health_label.text = ""


func _sync_overhead_display() -> void:
	_ensure_overhead_display()
	if overhead_display == null or not is_instance_valid(overhead_display):
		return
	if enemy_config.is_empty() or enemy_data.is_empty():
		overhead_display.visible = false
		return
	overhead_display.sync_display(
		get_display_name(),
		_resolve_overhead_bar_style(),
		_resolve_overhead_show_name(),
		get_current_health(),
		get_max_health(),
		_resolve_overhead_layout_overrides(),
		int(enemy_config.get("label_font_size", 10))
	)


func _resolve_overhead_bar_style() -> String:
	var configured_style := str(enemy_config.get("hp_bar_style", ""))
	if not configured_style.is_empty():
		return configured_style
	if enemy_config.has("show_health_label") and not bool(enemy_config.get("show_health_label", true)):
		return OverheadDisplayScript.STYLE_NONE
	return OverheadDisplayScript.STYLE_RED


func _resolve_overhead_show_name() -> bool:
	if enemy_config.has("show_name"):
		return bool(enemy_config.get("show_name", true))
	return bool(enemy_config.get("show_name_label", true))


func _resolve_overhead_layout_overrides() -> Dictionary:
	var overrides: Dictionary = {}
	var configured_overrides: Variant = enemy_config.get("overhead_display_overrides", null)
	if configured_overrides is Dictionary:
		overrides = (configured_overrides as Dictionary).duplicate(true)
	var configured_offset: Variant = enemy_config.get("overhead_display_offset_pixels", null)
	if configured_offset is Vector2:
		overrides["head_offset_pixels"] = configured_offset
	return overrides


func _configure_collision_layers() -> void:
	hurtbox_area.collision_layer = GameLayers.bit(GameLayers.ENEMY_ENTITY)
	hurtbox_area.collision_mask = 0
	hurtbox_area.monitoring = false
	hurtbox_area.monitorable = true
	detect_area.collision_layer = GameLayers.bit(GameLayers.ENEMY_DETECT)
	detect_area.collision_mask = GameLayers.bit(GameLayers.PLAYER_ENTITY)
	attack_area.collision_layer = GameLayers.bit(GameLayers.ENEMY_ATTACK)
	attack_area.collision_mask = GameLayers.bit(GameLayers.PLAYER_ENTITY)
	attack_area.monitoring = ENABLE_ATTACK_AREA_DETECTION


func _configure_detection_and_attack_areas() -> void:
	var detect_circle: CircleShape2D = detect_shape.shape
	if detect_circle == null:
		detect_circle = CircleShape2D.new()
		detect_shape.shape = detect_circle
	detect_circle.radius = _get_detection_range_pixels()

	var attack_circle: CircleShape2D = attack_shape.shape
	if attack_circle == null:
		attack_circle = CircleShape2D.new()
		attack_shape.shape = attack_circle
	attack_circle.radius = get_attack_range_pixels()


func _is_target_inside_detect_area(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or not target.has_method("get_hitbox_area"):
		return false

	var target_hitbox: Area2D = target.get_hitbox_area()
	if target_hitbox == null:
		return false

	return detect_area.overlaps_area(target_hitbox)
