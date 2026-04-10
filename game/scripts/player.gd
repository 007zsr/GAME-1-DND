extends Node2D

const GameLayers = preload("res://game/scripts/game_layers.gd")
const CharacterStats = preload("res://game/scripts/character_stats.gd")
const ItemSystem = preload("res://game/scripts/item_system.gd")
const ModifierSystem = preload("res://game/scripts/modifier_system.gd")
const SkillExecutor = preload("res://game/skills/skill_executor.gd")
const SkillRegistry = preload("res://game/skills/skill_registry.gd")
const SkillRuntime = preload("res://game/skills/skill_runtime.gd")

signal death_requested
signal runtime_values_recalculated

const GRID_SIZE_METERS := 1.0
const BODY_SIZE_METERS := Vector2(0.5, 0.5)
const CAMERA_DEFAULT_ZOOM := 1.0
const CAMERA_MIN_ZOOM := 0.8
const CAMERA_MAX_ZOOM := 1.8
const CAMERA_ZOOM_STEP := 0.1
const MIN_SLASH_COOLDOWN := 0.1
const DEFAULT_SLASH_RANGE_METERS := 0.5
const DEFAULT_SLASH_BASE_DAMAGE := 10
const DEFAULT_SLASH_FLASH_DURATION := 0.2
const EQUIPMENT_SOURCE_PREFIX := "equipment:"
const ARTIFACT_SOURCE_PREFIX := "artifact:"
const PASSIVE_SOURCE_PREFIX := "passive:"
const STATUS_SOURCE_PREFIX := "status:"

var faction_id: String = "player"
var ai_id: String = ""
var current_target_enemy: Node2D = null
var current_level: int = 1
var max_health: int = 220
var current_health: int = 220
var base_a_stats: Dictionary = {}
var current_a_stats: Dictionary = {}
var a_stat_breakdowns: Dictionary = {}
var base_b_stats: Dictionary = {}
var current_b_stats: Dictionary = {}
var b_stat_breakdowns: Dictionary = {}
var skill_breakdowns: Dictionary = {}
var skill_runtime_cache: Dictionary = {}
var skill_runtime_state: Dictionary = {}
var active_modifier_sources: Dictionary = {}
var equipped_items: Dictionary = {}
var inventory_slots: Array = []
var gameplay_locked: bool = false
var dead_locked: bool = false
var death_request_queued: bool = false
var current_camera_zoom: float = CAMERA_DEFAULT_ZOOM
var slash_attack_in_progress: bool = false
var enemies_in_slash_range: Array[Node2D] = []
var slash_range_area: Area2D
var slash_range_shape: CollisionShape2D
var slash_effect_tween: Tween

@export var meters_to_pixels: float = 16.0
@export var village_path: NodePath

@onready var village: Node = get_node(village_path)
@onready var attack_timer: Timer = $AttackTimer
@onready var attack_arc: Polygon2D = $AttackArc
@onready var camera: Camera2D = $Camera2D
@onready var body: ColorRect = $Body
@onready var hitbox_area: Area2D = $HitboxArea
@onready var hitbox_shape: CollisionShape2D = $HitboxArea/CollisionShape2D


func _ready() -> void:
	_ensure_slash_range_area()
	_connect_slash_range_signals()
	_apply_character_stats()
	_apply_body_visual()
	_apply_slash_skill_stats()
	attack_arc.visible = false
	attack_arc.z_as_relative = false
	attack_arc.z_index = GameLayers.Z_EFFECTS
	attack_timer.one_shot = true
	attack_timer.stop()
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	_configure_collision_layers()
	_apply_camera_zoom()


func _physics_process(delta: float) -> void:
	if gameplay_locked:
		return
	SkillRuntime.tick_cooldowns(skill_runtime_state, delta)

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector == Vector2.ZERO:
		input_vector = _get_keyboard_input_vector()

	var speed_pixels: float = get_move_speed() * meters_to_pixels
	var motion: Vector2 = input_vector * speed_pixels * delta
	if village.has_method("resolve_world_movement"):
		position = village.resolve_world_movement(position, motion, get_hitbox_half_size_pixels())
	else:
		position += motion

	_refresh_slash_targets_from_world()
	_update_auto_slash_attack()


func _unhandled_input(event: InputEvent) -> void:
	if gameplay_locked or event == null:
		return
	if event.is_echo():
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if village != null and village.has_method("is_overlay_open") and village.is_overlay_open():
		return
	if village != null and village.has_method("is_result_showing") and village.is_result_showing():
		return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_adjust_camera_zoom(-CAMERA_ZOOM_STEP)
		get_viewport().set_input_as_handled()
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_adjust_camera_zoom(CAMERA_ZOOM_STEP)
		get_viewport().set_input_as_handled()


func configure_world(world_meters_to_pixels: float) -> void:
	meters_to_pixels = world_meters_to_pixels
	_apply_body_visual()
	_apply_slash_skill_stats()
	_configure_collision_layers()
	_apply_camera_zoom()


func get_grid_position() -> Vector2:
	return Vector2(
		floor(position.x / (meters_to_pixels * GRID_SIZE_METERS)),
		floor(position.y / (meters_to_pixels * GRID_SIZE_METERS))
	)


func get_hitbox_half_size_pixels() -> Vector2:
	return BODY_SIZE_METERS * meters_to_pixels * 0.5


func get_hitbox_area() -> Area2D:
	return hitbox_area


func get_current_health() -> int:
	return current_health


func get_faction_id() -> String:
	return faction_id


func get_ai_id() -> String:
	return ai_id


func get_max_health() -> int:
	return max_health


func is_alive() -> bool:
	return current_health > 0 and not dead_locked


func is_dead_locked() -> bool:
	return dead_locked


func is_gameplay_locked() -> bool:
	return gameplay_locked


func lock_gameplay() -> void:
	gameplay_locked = true
	current_target_enemy = null
	slash_attack_in_progress = false
	enemies_in_slash_range.clear()
	attack_arc.visible = false
	attack_timer.stop()


func unlock_gameplay() -> void:
	if dead_locked:
		return
	gameplay_locked = false


func lock_for_death() -> void:
	if dead_locked:
		return

	dead_locked = true
	gameplay_locked = true
	current_health = 0
	current_target_enemy = null
	slash_attack_in_progress = false
	enemies_in_slash_range.clear()
	attack_arc.visible = false
	attack_timer.stop()


func take_damage(damage: int, _source_name: String = "") -> void:
	if damage <= 0:
		return

	if gameplay_locked or dead_locked:
		return

	if village.has_method("is_result_showing") and village.is_result_showing():
		return

	var final_damage: int = int(round(get_taken_damage_value(float(damage))))
	current_health = max(current_health - final_damage, 0)
	body.color = Color(1.0, 0.45, 0.45, 1.0)
	var tween: Tween = create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(func() -> void:
		body.color = Color(0.278431, 0.690196, 0.941176, 1.0)
	)

	if current_health <= 0:
		lock_for_death()
		if not death_request_queued:
			death_request_queued = true
			call_deferred("_emit_death_requested")


func get_hit_rate() -> float:
	return float(current_b_stats.get("accuracy", 100.0))


func get_crit_rate() -> float:
	return float(current_b_stats.get("critical_rate", 0.0))


func get_crit_damage_multiplier() -> float:
	return maxf(float(current_b_stats.get("critical_damage", 1.5)), 1.0)


func get_attack_speed() -> float:
	return maxf(float(current_b_stats.get("attack_speed", 1.0)), 0.01)


func get_damage_power() -> float:
	return float(current_b_stats.get("damage_power", 0.0))


func get_magic_power() -> float:
	return float(current_b_stats.get("magic_power", 0.0))


func get_move_speed() -> float:
	return maxf(float(current_b_stats.get("move_speed", CharacterStats.FIXED_MOVE_SPEED)), 0.01)


func get_dodge_rate() -> float:
	return float(current_b_stats.get("evasion", 0.0))


func get_block_rate() -> float:
	return float(current_b_stats.get("block_rate", 0.0))


func get_current_slash_cooldown() -> float:
	return get_skill_cooldown_value("slash_skill")


func get_slash_cooldown_remaining() -> float:
	return get_skill_cooldown_remaining("slash_skill")


func get_slash_cooldown_display_value() -> String:
	return ModifierSystem.format_target_value("skill.slash_cooldown", get_current_slash_cooldown())


func get_slash_cooldown_formula_text() -> String:
	return _format_breakdown_formula_text("skill.slash_cooldown", get_skill_breakdown("slash_cooldown"))


func get_slash_damage_value() -> float:
	return float(skill_runtime_cache.get("slash_damage", float(DEFAULT_SLASH_BASE_DAMAGE)))


func get_slash_damage_display_value() -> String:
	return ModifierSystem.format_target_value("skill.slash_damage", get_slash_damage_value())


func get_slash_damage_formula_text() -> String:
	return _format_breakdown_formula_text("skill.slash_damage", get_skill_breakdown("slash_damage"))


func get_slash_range_display_value() -> String:
	return ModifierSystem.format_target_value("skill.slash_range", float(skill_runtime_cache.get("slash_range", DEFAULT_SLASH_RANGE_METERS)))


func get_slash_range_formula_text() -> String:
	return _format_breakdown_formula_text("skill.slash_range", get_skill_breakdown("slash_range"))


func get_slash_trigger_text() -> String:
	var trigger_text := str((_get_skill_definition("slash_skill").get("parameters", {}) as Dictionary).get("trigger_text", "范围内有敌人且冷却结束时立即触发"))
	if is_skill_equipped("slash_skill"):
		return trigger_text
	return "配置后%s" % trigger_text


func get_item_definition(item_id: String) -> Dictionary:
	return ItemSystem.get_item_definition(item_id)


func get_item_stack_definition(item_stack: Dictionary) -> Dictionary:
	var normalized_stack := ItemSystem.normalize_item_stack(item_stack)
	if normalized_stack.is_empty():
		return {}
	return get_item_definition(ItemSystem.get_stack_template_id(normalized_stack))


func can_equip_item_to_slot(item_stack: Dictionary, slot_type: String) -> bool:
	var definition: Dictionary = get_item_stack_definition(item_stack)
	if definition.is_empty():
		return false
	return bool(definition.get("can_equip", false)) and str(definition.get("equip_slot_type", "")) == ItemSystem.get_slot_accept_type(slot_type)


func find_best_equip_slot_for_item_stack(item_stack: Dictionary) -> String:
	return ItemSystem.find_best_equip_slot(equipped_items, item_stack)


func get_stat_bonus_display(stat_key: String, stat_group: String) -> float:
	if stat_group == "a":
		return float(get_a_stat_breakdown(stat_key).get("final_value", base_a_stats.get(stat_key, 0.0))) - float(base_a_stats.get(stat_key, 0.0))
	var base_value: float = float(base_b_stats.get(stat_key, 0.0))
	return float(get_b_stat_breakdown(stat_key).get("final_value", base_value)) - base_value


func get_equipment_slot_stack(slot_type: String) -> Dictionary:
	return ItemSystem.normalize_item_stack((equipped_items.get(slot_type, {}) as Dictionary).duplicate(true))


func get_inventory_stack(index: int) -> Dictionary:
	if index < 0 or index >= inventory_slots.size():
		return {}
	return ItemSystem.normalize_item_stack((inventory_slots[index] as Dictionary).duplicate(true))


func find_inventory_receive_target_index(item_stack: Dictionary) -> int:
	var normalized_stack := ItemSystem.normalize_item_stack(item_stack)
	if normalized_stack.is_empty():
		return -1

	var definition: Dictionary = get_item_stack_definition(normalized_stack)
	if definition.is_empty():
		return -1

	var incoming_count: int = int(normalized_stack.get("count", 1))
	var max_stack: int = ItemSystem.get_max_stack_for_definition(definition)
	_ensure_inventory_display_size()

	for index in range(inventory_slots.size()):
		var existing_stack := ItemSystem.normalize_item_stack(inventory_slots[index] as Dictionary)
		if existing_stack.is_empty():
			continue
		if not ItemSystem.can_merge_stacks(existing_stack, normalized_stack):
			continue
		var existing_count: int = int(existing_stack.get("count", 1))
		if existing_count < max_stack and existing_count + incoming_count > 0:
			return index

	for index in range(inventory_slots.size()):
		if (inventory_slots[index] as Dictionary).is_empty():
			return index

	return -1


func drop_inventory_item(index: int) -> bool:
	if index < 0 or index >= inventory_slots.size():
		return false
	inventory_slots[index] = {}
	_trim_inventory_tail()
	_sync_runtime_character_to_game_state()
	return true


func split_inventory_stack(index: int) -> bool:
	var item_stack: Dictionary = get_inventory_stack(index)
	var split_count: int = int(item_stack.get("count", 1)) / 2
	return split_inventory_stack_by_count(index, split_count)


func split_inventory_stack_by_count(index: int, split_count: int) -> bool:
	if index < 0 or index >= inventory_slots.size():
		return false
	var item_stack := ItemSystem.normalize_item_stack(inventory_slots[index] as Dictionary)
	if item_stack.is_empty():
		return false
	var definition: Dictionary = get_item_stack_definition(item_stack)
	if not bool(definition.get("can_split", false)):
		return false
	var count: int = int(item_stack.get("count", 1))
	if count <= 1:
		return false
	if split_count < 1 or split_count >= count:
		return false
	var empty_index: int = _find_first_empty_inventory_slot()
	if empty_index == -1:
		return false
	var remain_count: int = count - split_count
	item_stack["count"] = remain_count
	inventory_slots[index] = item_stack
	var new_stack := item_stack.duplicate(true)
	new_stack["count"] = split_count
	inventory_slots[empty_index] = ItemSystem.normalize_item_stack(new_stack)
	_sync_runtime_character_to_game_state()
	return true


func move_inventory_item(from_index: int, to_index: int) -> bool:
	if from_index == to_index:
		return false
	if not _is_valid_inventory_index(from_index) or not _is_valid_inventory_index(to_index):
		return false
	var source_stack := ItemSystem.normalize_item_stack(inventory_slots[from_index] as Dictionary)
	var target_stack := ItemSystem.normalize_item_stack(inventory_slots[to_index] as Dictionary)
	if ItemSystem.can_merge_stacks(target_stack, source_stack):
		var merge_result := ItemSystem.merge_stacks(target_stack, source_stack)
		inventory_slots[to_index] = merge_result.get("target_stack", {})
		inventory_slots[from_index] = merge_result.get("source_stack", {})
		_sync_runtime_character_to_game_state()
		return true
	inventory_slots[from_index] = target_stack
	inventory_slots[to_index] = source_stack
	_sync_runtime_character_to_game_state()
	return true


func move_item_to_inventory_index(item_stack: Dictionary, target_index: int) -> bool:
	if not _is_valid_inventory_index(target_index):
		return false
	inventory_slots[target_index] = ItemSystem.normalize_item_stack(item_stack)
	_sync_runtime_character_to_game_state()
	return true


func replace_inventory_stack(index: int, item_stack: Dictionary) -> bool:
	if not _is_valid_inventory_index(index):
		return false
	inventory_slots[index] = ItemSystem.normalize_item_stack(item_stack)
	_sync_runtime_character_to_game_state()
	return true


func equip_from_inventory(from_index: int, slot_type: String) -> bool:
	if not _is_valid_inventory_index(from_index):
		return false
	var normalized_slot_type := str(slot_type)
	var source_stack := ItemSystem.normalize_item_stack(inventory_slots[from_index] as Dictionary)
	if source_stack.is_empty() or not can_equip_item_to_slot(source_stack, slot_type):
		return false
	var previous_equipped := ItemSystem.normalize_item_stack(equipped_items.get(normalized_slot_type, {}) as Dictionary)
	var equip_stack := source_stack.duplicate(true)
	equip_stack["count"] = 1
	if previous_equipped.is_empty():
		equipped_items[normalized_slot_type] = equip_stack
		if int(source_stack.get("count", 1)) > 1:
			source_stack["count"] = int(source_stack.get("count", 1)) - 1
			inventory_slots[from_index] = source_stack
		else:
			inventory_slots[from_index] = {}
		_commit_runtime_container_state_to_game_state()
		_recalculate_character_state(false)
		return true

	if int(source_stack.get("count", 1)) > 1:
		var previous_receive_index := _find_inventory_receive_target_index_excluding(previous_equipped, [from_index])
		if previous_receive_index == -1:
			return false
		if not _place_stack_into_inventory(previous_equipped, previous_receive_index):
			return false
		source_stack["count"] = int(source_stack.get("count", 1)) - 1
		inventory_slots[from_index] = source_stack
	else:
		inventory_slots[from_index] = previous_equipped
	equipped_items[normalized_slot_type] = equip_stack
	_commit_runtime_container_state_to_game_state()
	_recalculate_character_state(false)
	return true


func unequip_to_inventory(slot_type: String, target_index: int) -> bool:
	if not _is_valid_inventory_index(target_index):
		return false
	var normalized_slot_type := str(slot_type)
	var equipped_stack := ItemSystem.normalize_item_stack(equipped_items.get(normalized_slot_type, {}) as Dictionary)
	if equipped_stack.is_empty():
		return false
	var target_stack := ItemSystem.normalize_item_stack(inventory_slots[target_index] as Dictionary)
	if target_stack.is_empty():
		equipped_items[normalized_slot_type] = {}
		inventory_slots[target_index] = equipped_stack
		_commit_runtime_container_state_to_game_state()
		_recalculate_character_state(false)
		return true
	if ItemSystem.can_merge_stacks(target_stack, equipped_stack):
		var merge_result := ItemSystem.merge_stacks(target_stack, equipped_stack)
		equipped_items[normalized_slot_type] = merge_result.get("source_stack", {})
		inventory_slots[target_index] = merge_result.get("target_stack", {})
		_commit_runtime_container_state_to_game_state()
		_recalculate_character_state(false)
		return true
	if not can_equip_item_to_slot(target_stack, normalized_slot_type):
		return false
	equipped_items[normalized_slot_type] = target_stack
	inventory_slots[target_index] = equipped_stack
	_commit_runtime_container_state_to_game_state()
	_recalculate_character_state(false)
	return true


func unequip_to_inventory_auto(slot_type: String) -> bool:
	var equipped_stack := get_equipment_slot_stack(slot_type)
	if equipped_stack.is_empty():
		return false
	var target_index := find_inventory_receive_target_index(equipped_stack)
	if target_index == -1:
		return false
	return unequip_to_inventory(slot_type, target_index)


func equip_best_from_inventory(from_index: int) -> String:
	if not _is_valid_inventory_index(from_index):
		return ""
	var item_stack := ItemSystem.normalize_item_stack(inventory_slots[from_index] as Dictionary)
	if item_stack.is_empty():
		return ""
	var slot_type := find_best_equip_slot_for_item_stack(item_stack)
	if slot_type == "":
		return ""
	if not equip_from_inventory(from_index, slot_type):
		return ""
	return slot_type


func _get_game_state_character() -> Dictionary:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state != null and "current_character" in game_state:
		return game_state.current_character
	return {}


func get_character_class_name() -> String:
	return str(_get_game_state_character().get("class_name", "战士"))


func get_background_id() -> String:
	return str(_get_game_state_character().get("background_id", _get_game_state_character().get("past_life_id", "")))


func get_background_name() -> String:
	return str(_get_game_state_character().get("background_name", _get_game_state_character().get("past_life_name", "")))


func get_past_life_id() -> String:
	return str(_get_game_state_character().get("past_life_id", get_background_id()))


func get_trait_ids() -> Array[String]:
	var results: Array[String] = []
	for entry in _get_game_state_character().get("trait_ids", []):
		results.append(str(entry))
	return results


func get_strength_id() -> String:
	return str(_get_game_state_character().get("strength_id", ""))


func get_weakness_id() -> String:
	return str(_get_game_state_character().get("weakness_id", ""))


func get_personality_id() -> String:
	return str(_get_game_state_character().get("personality_id", ""))


func get_reborn_job_id() -> String:
	return str(_get_game_state_character().get("reborn_job_id", _get_game_state_character().get("class_id", "")))


func get_profile_tags() -> Array[String]:
	var tags: Array[String] = []
	for entry in _get_game_state_character().get("profile_tags", []):
		tags.append(str(entry))
	return tags


func get_character_a_stats() -> Dictionary:
	return current_a_stats.duplicate(true)


func get_base_a_stats() -> Dictionary:
	return base_a_stats.duplicate(true)


func get_character_b_stats() -> Dictionary:
	return current_b_stats.duplicate(true)


func get_base_b_stats() -> Dictionary:
	return base_b_stats.duplicate(true)


func get_a_stat_breakdown(stat_key: String) -> Dictionary:
	return (a_stat_breakdowns.get(stat_key, {}) as Dictionary).duplicate(true)


func get_b_stat_breakdown(stat_key: String) -> Dictionary:
	return (b_stat_breakdowns.get(stat_key, {}) as Dictionary).duplicate(true)


func get_skill_breakdown(skill_key: String) -> Dictionary:
	return (skill_breakdowns.get(skill_key, {}) as Dictionary).duplicate(true)


func get_active_modifier_sources() -> Dictionary:
	return active_modifier_sources.duplicate(true)


func get_level() -> int:
	return current_level


func get_equipped_items() -> Dictionary:
	return equipped_items.duplicate(true)


func get_inventory_slots() -> Array:
	var result: Array = []
	for item_stack in inventory_slots:
		result.append(ItemSystem.normalize_item_stack(item_stack as Dictionary))
	return result


func register_modifier_source(source_id: String, source_data: Dictionary, recalculate_now: bool = true) -> void:
	if source_id == "" or source_data.is_empty():
		return
	active_modifier_sources[source_id] = source_data.duplicate(true)
	if recalculate_now:
		_recalculate_character_state(false)


func get_inventory_capacity() -> int:
	return max(inventory_slots.size(), 12)


func is_inventory_overloaded() -> bool:
	var occupied_slots := 0
	for item_stack in inventory_slots:
		if not ItemSystem.normalize_item_stack(item_stack as Dictionary).is_empty():
			occupied_slots += 1
	return occupied_slots > get_inventory_capacity()


func get_skill_slot_count() -> int:
	return SkillRuntime.get_slot_count(skill_runtime_state)


func get_owned_skill_ids() -> Array[String]:
	return SkillRuntime.get_owned_skill_ids(skill_runtime_state)


func get_equipped_skill_ids() -> Array[String]:
	return SkillRuntime.get_equipped_skill_ids(skill_runtime_state)


func get_equipped_skill_id(slot_index: int) -> String:
	return SkillRuntime.get_equipped_skill_id_at_slot(skill_runtime_state, slot_index)


func is_skill_owned(skill_id: String) -> bool:
	return SkillRuntime.owns_skill(skill_runtime_state, skill_id)


func is_skill_equipped(skill_id: String) -> bool:
	return SkillRuntime.is_skill_equipped(skill_runtime_state, skill_id)


func get_skill_cooldown_remaining(skill_id: String) -> float:
	return SkillRuntime.get_cooldown_remaining(skill_runtime_state, skill_id)


func get_skill_cooldown_value(skill_id: String) -> float:
	match skill_id:
		"slash_skill":
			return float(skill_runtime_cache.get("slash_cooldown", MIN_SLASH_COOLDOWN))
		_:
			return SkillRuntime.get_cooldown_duration(skill_runtime_state, skill_id)


func get_skill_data(skill_id: String) -> Dictionary:
	var definition := _get_skill_definition(skill_id)
	if definition.is_empty():
		return {}
	var state := SkillRuntime.get_state(skill_runtime_state, skill_id)
	var data := {
		"id": skill_id,
		"skill_id": skill_id,
		"name": str(definition.get("display_name", skill_id)),
		"display_name": str(definition.get("display_name", skill_id)),
		"skill_type": str(definition.get("skill_type", "active")),
		"skill_type_label": SkillRegistry.get_skill_type_label(str(definition.get("skill_type", "active"))),
		"summary": str(definition.get("summary", "")),
		"tags": (definition.get("tags", []) as Array).duplicate(true),
		"is_owned": bool(state.get("is_owned", false)),
		"is_equipped": bool(state.get("is_equipped", false)),
		"slot_index": int(state.get("slot_index", -1)),
		"is_enabled": bool(state.get("is_enabled", true)),
		"cooldown": get_skill_cooldown_value(skill_id),
		"cooldown_remaining": get_skill_cooldown_remaining(skill_id),
	}
	match skill_id:
		"slash_skill":
			data["damage"] = get_slash_damage_value()
			data["damage_text"] = get_slash_damage_display_value()
			data["cooldown_text"] = get_slash_cooldown_display_value()
			data["range"] = float(skill_runtime_cache.get("slash_range", DEFAULT_SLASH_RANGE_METERS))
			data["range_text"] = get_slash_range_display_value()
			data["trigger_text"] = get_slash_trigger_text()
		_:
			data["cooldown_text"] = "%.2f秒" % get_skill_cooldown_value(skill_id)
	return data


func get_owned_skill_entries() -> Array:
	var entries: Array = []
	for skill_id in get_owned_skill_ids():
		entries.append(get_skill_data(skill_id))
	return entries


func get_skill_slot_entries() -> Array:
	var entries: Array = []
	for slot_index in range(get_skill_slot_count()):
		var skill_id := get_equipped_skill_id(slot_index)
		if skill_id.is_empty():
			entries.append({
				"slot_index": slot_index,
				"skill_id": "",
				"is_empty": true,
			})
			continue
		var entry := get_skill_data(skill_id)
		entry["slot_index"] = slot_index
		entry["is_empty"] = false
		entries.append(entry)
	return entries


func equip_skill_to_first_empty_slot(skill_id: String) -> bool:
	if not SkillRuntime.equip_skill_to_first_empty_slot(skill_runtime_state, skill_id):
		return false
	_on_skill_loadout_changed(skill_id)
	return true


func equip_skill_to_slot(skill_id: String, slot_index: int) -> bool:
	if not SkillRuntime.equip_skill_to_slot(skill_runtime_state, skill_id, slot_index):
		return false
	_on_skill_loadout_changed(skill_id)
	return true


func unequip_skill(skill_id: String) -> bool:
	if not SkillRuntime.unequip_skill(skill_runtime_state, skill_id):
		return false
	_on_skill_loadout_changed(skill_id)
	return true


func unequip_skill_at_slot(slot_index: int) -> bool:
	var skill_id := get_equipped_skill_id(slot_index)
	if skill_id.is_empty():
		return false
	return unequip_skill(skill_id)


func swap_skill_slots(from_slot_index: int, to_slot_index: int) -> bool:
	if from_slot_index == to_slot_index:
		return false
	var from_skill_id := get_equipped_skill_id(from_slot_index)
	if from_skill_id.is_empty():
		return false
	var to_skill_id := get_equipped_skill_id(to_slot_index)
	if not SkillRuntime.unequip_skill_at_slot(skill_runtime_state, from_slot_index):
		return false
	if not to_skill_id.is_empty():
		SkillRuntime.unequip_skill_at_slot(skill_runtime_state, to_slot_index)
	SkillRuntime.equip_skill_to_slot(skill_runtime_state, from_skill_id, to_slot_index)
	if not to_skill_id.is_empty():
		SkillRuntime.equip_skill_to_slot(skill_runtime_state, to_skill_id, from_slot_index)
	_on_skill_loadout_changed(from_skill_id)
	return true


func get_slash_skill_data() -> Dictionary:
	return get_skill_data("slash_skill")


func request_skill_use(skill_id: String, request_context: Dictionary = {}) -> bool:
	return SkillExecutor.request_execute(self, skill_runtime_state, skill_id, request_context)


func execute_skill_definition(skill_id: String, definition: Dictionary, request_context: Dictionary = {}) -> Dictionary:
	match str(definition.get("execution_key", "")):
		"player_slash":
			return execute_player_skill_slash(skill_id, definition, request_context)
		_:
			return {"success": false}


func get_combat_summary() -> Dictionary:
	return {
		"class_name": get_character_class_name(),
		"current_hp": get_current_health(),
		"max_hp": get_max_health(),
		"slash_damage": get_slash_damage_value(),
		"slash_cooldown": get_current_slash_cooldown(),
	}


func get_b_stat_hover_detail_data(stat_key: String, source_context: String = "") -> Dictionary:
	return CharacterStats.build_b_stat_hover_detail_data(
		stat_key,
		get_character_b_stats(),
		get_character_a_stats(),
		source_context
	)


func get_skill_hover_detail_data(skill_id: String) -> Dictionary:
	var skill_data := get_skill_data(skill_id)
	if skill_data.is_empty():
		return {}
	match skill_id:
		"slash_skill":
			var status_text := "已配置" if bool(skill_data.get("is_equipped", false)) else "未配置"
			var summary_lines: Array[String] = [
				str(skill_data.get("summary", "")),
				"类型：%s" % str(skill_data.get("skill_type_label", "")),
				"当前状态：%s" % status_text,
				"当前伤害：%s" % get_slash_damage_display_value(),
				"当前冷却：%s" % get_slash_cooldown_display_value(),
				"当前范围：%s" % get_slash_range_display_value(),
			]
			var detail_lines: Array[String] = [
				"触发规则：%s" % get_slash_trigger_text(),
				"伤害公式：%s" % get_slash_damage_formula_text(),
				"冷却公式：%s" % get_slash_cooldown_formula_text(),
				"范围公式：%s" % get_slash_range_formula_text(),
			]
			return {
				"title": str(skill_data.get("display_name", skill_id)),
				"summary_lines": summary_lines,
				"detail_lines": detail_lines,
				"supports_shift": true,
			}
		_:
			return {
				"title": str(skill_data.get("display_name", skill_id)),
				"summary_lines": [
					str(skill_data.get("summary", "")),
					"类型：%s" % str(skill_data.get("skill_type_label", "")),
				],
				"detail_lines": [
					"当前冷却：%s" % str(skill_data.get("cooldown_text", "--")),
				],
				"supports_shift": true,
			}


func get_slash_skill_hover_detail_data() -> Dictionary:
	return get_skill_hover_detail_data("slash_skill")


func _ensure_slash_range_area() -> void:
	if slash_range_area != null and is_instance_valid(slash_range_area):
		return
	slash_range_area = Area2D.new()
	slash_range_area.name = "SlashRangeArea"
	slash_range_area.monitoring = true
	slash_range_area.monitorable = false
	add_child(slash_range_area)
	slash_range_shape = CollisionShape2D.new()
	slash_range_shape.name = "CollisionShape2D"
	slash_range_area.add_child(slash_range_shape)


func _connect_slash_range_signals() -> void:
	_ensure_slash_range_area()
	if slash_range_area == null:
		return
	if not slash_range_area.area_entered.is_connected(_on_slash_range_area_entered):
		slash_range_area.area_entered.connect(_on_slash_range_area_entered)
	if not slash_range_area.area_exited.is_connected(_on_slash_range_area_exited):
		slash_range_area.area_exited.connect(_on_slash_range_area_exited)


func _apply_character_stats() -> void:
	_recalculate_character_state(true)


func _apply_body_visual() -> void:
	if body == null:
		return
	body.color = Color(0.278431, 0.690196, 0.941176, 1.0)
	body.custom_minimum_size = BODY_SIZE_METERS * meters_to_pixels
	body.size = BODY_SIZE_METERS * meters_to_pixels
	body.position = -(body.size * 0.5)
	if hitbox_shape != null:
		var rectangle_shape := RectangleShape2D.new()
		rectangle_shape.size = BODY_SIZE_METERS * meters_to_pixels
		hitbox_shape.shape = rectangle_shape


func _apply_slash_skill_stats() -> void:
	_ensure_slash_range_area()
	var slash_damage_breakdown := ModifierSystem.build_target_breakdown(
		"skill.slash_damage",
		float(DEFAULT_SLASH_BASE_DAMAGE) + get_damage_power(),
		active_modifier_sources
	)
	var slash_cooldown_breakdown := ModifierSystem.build_target_breakdown(
		"skill.slash_cooldown",
		maxf(MIN_SLASH_COOLDOWN, 1.0 / maxf(get_attack_speed(), 0.01)),
		active_modifier_sources
	)
	var slash_range_breakdown := ModifierSystem.build_target_breakdown(
		"skill.slash_range",
		DEFAULT_SLASH_RANGE_METERS,
		active_modifier_sources
	)
	skill_breakdowns["slash_damage"] = slash_damage_breakdown
	skill_breakdowns["slash_cooldown"] = slash_cooldown_breakdown
	skill_breakdowns["slash_range"] = slash_range_breakdown
	skill_runtime_cache["slash_damage"] = float(slash_damage_breakdown.get("final_value", DEFAULT_SLASH_BASE_DAMAGE))
	skill_runtime_cache["slash_cooldown"] = float(slash_cooldown_breakdown.get("final_value", MIN_SLASH_COOLDOWN))
	skill_runtime_cache["slash_range"] = float(slash_range_breakdown.get("final_value", DEFAULT_SLASH_RANGE_METERS))
	if slash_range_shape != null:
		var circle_shape := CircleShape2D.new()
		circle_shape.radius = float(skill_runtime_cache["slash_range"]) * meters_to_pixels
		slash_range_shape.shape = circle_shape


func _on_attack_timer_timeout() -> void:
	slash_attack_in_progress = false
	if slash_effect_tween != null:
		slash_effect_tween.kill()
		slash_effect_tween = null
	if attack_arc != null:
		attack_arc.visible = false


func _configure_collision_layers() -> void:
	if hitbox_area != null:
		hitbox_area.collision_layer = GameLayers.bit(GameLayers.PLAYER_ENTITY)
		hitbox_area.collision_mask = GameLayers.bit(GameLayers.ENEMY_ATTACK)
	if slash_range_area != null:
		slash_range_area.collision_layer = GameLayers.bit(GameLayers.PLAYER_ATTACK)
		slash_range_area.collision_mask = GameLayers.bit(GameLayers.ENEMY_ENTITY)


func _apply_camera_zoom() -> void:
	if camera != null:
		camera.zoom = Vector2(current_camera_zoom, current_camera_zoom)


func _adjust_camera_zoom(delta_zoom: float) -> void:
	current_camera_zoom = clampf(current_camera_zoom + delta_zoom, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
	_apply_camera_zoom()


func _get_keyboard_input_vector() -> Vector2:
	var x := 0.0
	var y := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		y += 1.0
	return Vector2(x, y).normalized()


func get_taken_damage_value(raw_damage: float) -> float:
	return maxf(raw_damage, 0.0)


func _format_breakdown_formula_text(target_key: String, breakdown: Dictionary) -> String:
	if breakdown.is_empty():
		return ModifierSystem.format_target_value(target_key, 0.0)
	return ModifierSystem.build_breakdown_hover_detail_data(
		ModifierSystem.get_target_label(target_key),
		breakdown
	).get("detail_lines", [""]).front()


func _get_skill_definition(skill_id: String) -> Dictionary:
	var runtime_definition := SkillRuntime.get_definition(skill_runtime_state, skill_id)
	if not runtime_definition.is_empty():
		return runtime_definition
	return SkillRegistry.get_skill_definition(skill_id)


func _load_skill_runtime_from_character(current_character: Dictionary) -> void:
	skill_runtime_state = SkillRegistry.build_player_skill_runtime(current_character, skill_runtime_state)


func _on_skill_loadout_changed(changed_skill_id: String = "") -> void:
	if changed_skill_id == "slash_skill" and not is_skill_equipped("slash_skill"):
		_cancel_slash_runtime()
	_sync_runtime_character_to_game_state()
	emit_signal("runtime_values_recalculated")


func _cancel_slash_runtime() -> void:
	current_target_enemy = null
	slash_attack_in_progress = false
	if slash_effect_tween != null:
		slash_effect_tween.kill()
		slash_effect_tween = null
	if attack_arc != null:
		attack_arc.visible = false
	if attack_timer != null:
		attack_timer.stop()


func _ensure_inventory_display_size() -> void:
	if inventory_slots.is_empty():
		inventory_slots = ItemSystem.get_default_inventory_state()
	while inventory_slots.size() < get_inventory_capacity():
		inventory_slots.append({})


func _trim_inventory_tail() -> void:
	var min_size: int = max(1, ItemSystem.get_default_inventory_state().size())
	while inventory_slots.size() > min_size:
		var last_stack := ItemSystem.normalize_item_stack(inventory_slots[inventory_slots.size() - 1] as Dictionary)
		if not last_stack.is_empty():
			break
		inventory_slots.remove_at(inventory_slots.size() - 1)


func _sync_runtime_character_to_game_state() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null or not ("current_character" in game_state):
		return
	var skill_persistence := SkillRegistry.export_player_skill_persistence(skill_runtime_state)
	game_state.current_character["level"] = current_level
	game_state.current_character["a_stats"] = base_a_stats.duplicate(true)
	game_state.current_character["b_stats"] = current_b_stats.duplicate(true)
	game_state.current_character["equipped_items"] = equipped_items.duplicate(true)
	game_state.current_character["inventory_slots"] = inventory_slots.duplicate(true)
	game_state.current_character["owned_skill_ids"] = skill_persistence.get("owned_skill_ids", [])
	game_state.current_character["equipped_skill_ids"] = skill_persistence.get("equipped_skill_ids", [])
	game_state.current_character["skill_state_overrides"] = skill_persistence.get("skill_state_overrides", {})
	game_state.current_character["skill_slot_count"] = skill_persistence.get("skill_slot_count", SkillRegistry.get_default_player_skill_slot_count())


func _commit_runtime_container_state_to_game_state() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null or not ("current_character" in game_state):
		return
	game_state.current_character["equipped_items"] = equipped_items.duplicate(true)
	game_state.current_character["inventory_slots"] = inventory_slots.duplicate(true)


func _find_first_empty_inventory_slot() -> int:
	_ensure_inventory_display_size()
	for index in range(inventory_slots.size()):
		if ItemSystem.normalize_item_stack(inventory_slots[index] as Dictionary).is_empty():
			return index
	return -1


func _is_valid_inventory_index(index: int) -> bool:
	_ensure_inventory_display_size()
	return index >= 0 and index < inventory_slots.size()


func _recalculate_character_state(recover_full_health: bool = false) -> void:
	var current_character := _get_game_state_character()
	current_level = int(current_character.get("level", current_level))
	if current_level <= 0:
		current_level = 1

	equipped_items = ItemSystem.get_empty_equipment_state()
	var equipped_from_state: Dictionary = current_character.get("equipped_items", {})
	for slot_type in equipped_items.keys():
		equipped_items[slot_type] = ItemSystem.normalize_item_stack((equipped_from_state.get(slot_type, {}) as Dictionary).duplicate(true))

	inventory_slots = []
	for item_stack in current_character.get("inventory_slots", ItemSystem.get_default_inventory_state()):
		inventory_slots.append(ItemSystem.normalize_item_stack(item_stack as Dictionary))
	_ensure_inventory_display_size()
	_rebuild_equipment_modifier_sources()
	_load_skill_runtime_from_character(current_character)

	base_a_stats = {}
	for stat_definition in CharacterStats.A_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		base_a_stats[stat_key] = int((current_character.get("a_stats", {}) as Dictionary).get(stat_key, 1))

	current_a_stats = {}
	a_stat_breakdowns = {}
	for stat_definition in CharacterStats.A_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		var breakdown := ModifierSystem.build_target_breakdown(
			"a.%s" % stat_key,
			float(base_a_stats.get(stat_key, 0)),
			active_modifier_sources
		)
		a_stat_breakdowns[stat_key] = breakdown
		current_a_stats[stat_key] = int(round(float(breakdown.get("final_value", base_a_stats.get(stat_key, 0)))))

	base_b_stats = CharacterStats.calculate_b_stats(current_a_stats)
	current_b_stats = {}
	b_stat_breakdowns = {}
	for stat_definition in CharacterStats.B_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		var b_breakdown := ModifierSystem.build_target_breakdown(
			CharacterStats.get_b_target_key(stat_key),
			float(base_b_stats.get(stat_key, 0.0)),
			active_modifier_sources
		)
		b_stat_breakdowns[stat_key] = b_breakdown
		current_b_stats[stat_key] = float(b_breakdown.get("final_value", base_b_stats.get(stat_key, 0.0)))

	max_health = int(round(float(current_b_stats.get("health", 1.0))))
	if recover_full_health or current_health <= 0:
		current_health = max_health
	else:
		current_health = clampi(current_health, 0, max_health)
	_apply_slash_skill_stats()
	_sync_runtime_character_to_game_state()
	emit_signal("runtime_values_recalculated")


func _find_inventory_receive_target_index_excluding(item_stack: Dictionary, excluded_indices: Array[int]) -> int:
	var normalized_stack := ItemSystem.normalize_item_stack(item_stack)
	if normalized_stack.is_empty():
		return -1
	_ensure_inventory_display_size()
	for index in range(inventory_slots.size()):
		if excluded_indices.has(index):
			continue
		var existing_stack := ItemSystem.normalize_item_stack(inventory_slots[index] as Dictionary)
		if ItemSystem.can_merge_stacks(existing_stack, normalized_stack):
			return index
	for index in range(inventory_slots.size()):
		if excluded_indices.has(index):
			continue
		if ItemSystem.normalize_item_stack(inventory_slots[index] as Dictionary).is_empty():
			return index
	return -1


func _place_stack_into_inventory(item_stack: Dictionary, target_index: int) -> bool:
	if not _is_valid_inventory_index(target_index):
		return false
	var normalized_stack := ItemSystem.normalize_item_stack(item_stack)
	if normalized_stack.is_empty():
		return false
	var target_stack := ItemSystem.normalize_item_stack(inventory_slots[target_index] as Dictionary)
	if target_stack.is_empty():
		inventory_slots[target_index] = normalized_stack
		_sync_runtime_character_to_game_state()
		return true
	if ItemSystem.can_merge_stacks(target_stack, normalized_stack):
		var merge_result := ItemSystem.merge_stacks(target_stack, normalized_stack)
		inventory_slots[target_index] = merge_result.get("target_stack", {})
		_sync_runtime_character_to_game_state()
		return (merge_result.get("source_stack", {}) as Dictionary).is_empty()
	return false


func _emit_death_requested() -> void:
	emit_signal("death_requested")


func _rebuild_equipment_modifier_sources() -> void:
	var preserved_sources: Dictionary = {}
	for source_id in active_modifier_sources.keys():
		var normalized_source_id := str(source_id)
		if normalized_source_id.begins_with(EQUIPMENT_SOURCE_PREFIX):
			continue
		preserved_sources[normalized_source_id] = (active_modifier_sources[source_id] as Dictionary).duplicate(true)
	active_modifier_sources = preserved_sources

	for slot_type in equipped_items.keys():
		var item_stack := ItemSystem.normalize_item_stack(equipped_items.get(slot_type, {}) as Dictionary)
		if item_stack.is_empty():
			continue
		var definition := get_item_stack_definition(item_stack)
		if definition.is_empty():
			continue
		var source_id := "%s%s" % [EQUIPMENT_SOURCE_PREFIX, str(slot_type)]
		var source_name := str(definition.get("display_name", definition.get("name", ItemSystem.get_slot_label(str(slot_type)))))
		active_modifier_sources[source_id] = ItemSystem.build_item_modifier_source(
			source_id,
			source_name,
			"equipment",
			definition
		)


func _refresh_slash_targets_from_world() -> void:
	if village == null or not village.has_method("find_enemies_in_radius"):
		return
	var range_pixels := float(skill_runtime_cache.get("slash_range", DEFAULT_SLASH_RANGE_METERS)) * meters_to_pixels
	var nearby_enemies: Array = village.find_enemies_in_radius(global_position, range_pixels)
	var refreshed_targets: Array[Node2D] = []
	for entry in nearby_enemies:
		if entry is Node2D and is_instance_valid(entry):
			refreshed_targets.append(entry)
	enemies_in_slash_range = refreshed_targets
	_prune_slash_targets()


func _update_auto_slash_attack() -> void:
	if not is_skill_equipped("slash_skill"):
		return
	if slash_attack_in_progress:
		return
	if not SkillExecutor.can_execute(skill_runtime_state, "slash_skill"):
		return
	if village != null and village.has_method("is_dialogue_active") and village.is_dialogue_active():
		return
	if village != null and village.has_method("is_result_showing") and village.is_result_showing():
		return

	var target_enemy := _find_slash_target()
	if target_enemy == null:
		current_target_enemy = null
		return

	request_skill_use("slash_skill", {
		"target_enemy": target_enemy,
	})


func _find_slash_target() -> Node2D:
	_prune_slash_targets()
	var best_target: Node2D = null
	var best_distance := INF
	for enemy in enemies_in_slash_range:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = enemy
	return best_target


func _trigger_slash_attack(target_enemy: Node2D) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy):
		return
	var direction := (target_enemy.global_position - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	current_target_enemy = target_enemy
	slash_attack_in_progress = true
	_show_slash_attack_arc(direction)
	if village != null and village.has_method("apply_player_slash_attack"):
		village.apply_player_slash_attack(
			global_position,
			direction,
			float(skill_runtime_cache.get("slash_range", DEFAULT_SLASH_RANGE_METERS)) * meters_to_pixels,
			get_slash_damage_value()
		)
	if attack_timer != null:
		attack_timer.start(DEFAULT_SLASH_FLASH_DURATION)
	if slash_effect_tween != null:
		slash_effect_tween.kill()
	slash_effect_tween = create_tween()
	slash_effect_tween.tween_interval(DEFAULT_SLASH_FLASH_DURATION)
	slash_effect_tween.finished.connect(func() -> void:
		slash_effect_tween = null
	)


func execute_player_skill_slash(skill_id: String, _definition: Dictionary, request_context: Dictionary = {}) -> Dictionary:
	if skill_id != "slash_skill":
		return {"success": false}
	var target_enemy: Node2D = request_context.get("target_enemy")
	if target_enemy == null:
		target_enemy = _find_slash_target()
	if target_enemy == null or not is_instance_valid(target_enemy):
		return {"success": false}
	_trigger_slash_attack(target_enemy)
	return {
		"success": true,
		"cooldown_duration": get_current_slash_cooldown(),
	}


func _show_slash_attack_arc(direction: Vector2) -> void:
	if attack_arc == null:
		return
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	var radius_pixels: float = float(skill_runtime_cache.get("slash_range", DEFAULT_SLASH_RANGE_METERS)) * meters_to_pixels
	var half_arc_radians: float = deg_to_rad(90.0)
	var steps: int = 14
	for step in range(steps + 1):
		var t: float = float(step) / float(steps)
		var angle: float = lerpf(-half_arc_radians, half_arc_radians, t)
		points.append(Vector2(cos(angle), sin(angle)) * radius_pixels)
	attack_arc.polygon = points
	attack_arc.rotation = direction.angle()
	attack_arc.color = Color(1.0, 0.86, 0.48, 0.72)
	attack_arc.visible = true


func _on_slash_range_area_entered(area: Area2D) -> void:
	var enemy := _get_enemy_node_from_slash_area(area)
	if enemy == null:
		return
	if enemies_in_slash_range.has(enemy):
		return
	enemies_in_slash_range.append(enemy)


func _on_slash_range_area_exited(area: Area2D) -> void:
	var enemy := _get_enemy_node_from_slash_area(area)
	if enemy == null:
		return
	enemies_in_slash_range.erase(enemy)


func _get_enemy_node_from_slash_area(area: Area2D) -> Node2D:
	if area == null or not is_instance_valid(area):
		return null
	var enemy := area.get_parent()
	if enemy is Node2D and enemy.has_method("is_alive") and enemy.has_method("is_hostile_to_player"):
		return enemy
	return null


func _prune_slash_targets() -> void:
	var pruned_targets: Array[Node2D] = []
	for enemy in enemies_in_slash_range:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		if enemy.has_method("is_hostile_to_player") and not enemy.is_hostile_to_player():
			continue
		pruned_targets.append(enemy)
	enemies_in_slash_range = pruned_targets
