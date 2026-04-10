extends Node2D

const GameLayers = preload("res://game/scripts/game_layers.gd")
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
var skill_runtime_state: Dictionary = {}
var skill_mode_bindings: Dictionary = {}
var last_requested_skill_id: String = ""
var last_executed_skill_id: String = ""

@onready var ai_controller: Node = $AIController
@onready var body: ColorRect = $Body
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
	last_requested_skill_id = ""
	last_executed_skill_id = ""

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
		return
	if village != null and village.has_method("is_dialogue_active") and village.is_dialogue_active():
		return

	if enemy_data.is_empty() or not is_alive():
		return

	SkillRuntime.tick_cooldowns(skill_runtime_state, delta)
	_update_attack_execution(delta)
	_configure_detection_and_attack_areas()
	if ai_controller != null:
		ai_controller.physics_tick(delta)


func get_hitbox_half_size_pixels() -> Vector2:
	var size_meters: Vector2 = enemy_config["size_meters"] as Vector2
	return size_meters * meters_to_pixels * 0.5


func get_hurtbox_area() -> Area2D:
	return hurtbox_area


func is_alive() -> bool:
	return int(enemy_data["health"]) > 0


func get_enemy_data() -> Dictionary:
	return enemy_data.duplicate(true)


func get_enemy_role() -> String:
	return get_actor_role()


func get_actor_role() -> String:
	return str(enemy_config.get("role", ""))


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
	var tween: Tween = create_tween()
	tween.tween_interval(0.1)
	tween.tween_callback(func() -> void:
		body.color = enemy_config["display_color"] as Color
	)
	_update_health_label()

	if int(enemy_data["health"]) <= 0:
		emit_signal("enemy_died", self)


func get_display_name() -> String:
	return str(enemy_config["name"])


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
		current_attack_direction = Vector2.RIGHT
		attack_arc.visible = false

	if not preserve_attack_cooldown:
		for skill_id in SkillRuntime.get_owned_skill_ids(skill_runtime_state):
			SkillRuntime.clear_cooldown(skill_runtime_state, skill_id)


func get_attack_range_pixels(attack_mode: String = "primary") -> float:
	var runtime_skill: Dictionary = _get_runtime_skill_config(attack_mode)
	var effective_attack_range: float = float(runtime_skill.get("range_meters", enemy_config.get("attack_range", 0.0)))
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

	if attack_phase == "windup" and attack_timer_remaining <= 0.0:
		if not attack_has_fired:
			_fire_skill()
			attack_has_fired = true

		attack_phase = "recovery"
		attack_timer_remaining = _get_postcast_duration(current_attack_mode)
		return

	if attack_phase == "recovery" and attack_timer_remaining <= 0.0:
		attack_phase = ""
		attack_timer_remaining = 0.0
		attack_has_fired = false
		current_skill_id = ""


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


func _move_toward_position(target_position: Vector2, delta: float) -> void:
	var direction_to_target: Vector2 = (target_position - global_position).normalized()
	if direction_to_target == Vector2.ZERO:
		return

	var motion: Vector2 = direction_to_target * _get_move_speed_pixels() * delta
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

	if attack_mode == "fallback" and get_enemy_role() == "ranged" and enemy_config.has("skill"):
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
		runtime_skill["damage"] = int(round(float(runtime_skill["damage"]) * float(phase_two["damage_multiplier"])))
		if attack_mode != "fallback":
			runtime_skill["range_meters"] = float(runtime_skill["range_meters"]) + float(phase_two["range_bonus"])

	return runtime_skill


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

	var font_size: int = int(enemy_config["label_font_size"])
	name_label.add_theme_font_size_override("font_size", font_size)
	health_label.add_theme_font_size_override("font_size", font_size)
	name_label.text = str(enemy_config["name"])
	name_label.offset_left = -32.0
	name_label.offset_top = -26.0
	name_label.offset_right = 32.0
	name_label.offset_bottom = -8.0
	health_label.offset_left = -30.0
	health_label.offset_top = 10.0
	health_label.offset_right = 30.0
	health_label.offset_bottom = 24.0
	name_label.visible = bool(enemy_config.get("show_name_label", true))
	health_label.visible = bool(enemy_config.get("show_health_label", true))
	attack_arc.visible = false


func _update_health_label() -> void:
	health_label.text = "HP %d" % int(enemy_data["health"])


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
