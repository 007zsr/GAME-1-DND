extends SceneTree

const ItemSystem = preload("res://game/scripts/item_system.gd")
const CultivationWorldStructure = preload("res://game/scripts/cultivation_world_structure.gd")
const CultivationFrostWastesBlockout = preload("res://game/scripts/cultivation_frost_wastes_blockout.gd")
const SkillRegistry = preload("res://game/skills/skill_registry.gd")
const CHECK_NAME := "check_frost_white_wolf_visuals"
const CHECK_TIMEOUT_SEC := 30.0
const EXPECTED_WOLF_SHEET_PATH := "res://game/assets/textures/characters/enemies/frost_white_wolf/spritesheets/frost_white_wolf_sheet_v001.png"
const EXPECTED_MELEE_FRAMES_PATH := "res://game/assets/textures/characters/enemies/melee_grunt/animations/melee_grunt_sprite_frames_v001.tres"
const EXPECTED_WOLF_SKILL_IDS := ["frost_white_wolf_rear_dash", "frost_white_wolf_triple_bite"]

var _check_started_msec: int = 0


func _init() -> void:
	_check_started_msec = Time.get_ticks_msec()
	_start_watchdog()
	call_deferred("_run_check")


func _run_check() -> void:
	var game_state: Node = root.get_node_or_null("/root/GameState")
	if game_state == null:
		push_error("GameState autoload missing")
		quit(1)
		return

	game_state.set_current_character({
		"class_id": "warrior",
		"class_name": "warrior",
		"reborn_job_id": "warrior",
		"reborn_job_name": "warrior",
		"background_id": "student",
		"background_name": "student",
		"profile_tags": ["student"],
		"trait_ids": [],
		"strength_id": "",
		"weakness_id": "",
		"personality_id": "",
		"level": 1,
		"a_stats": {
			"strength": 8,
			"agility": 6,
			"intelligence": 5,
			"perception": 6,
			"fortitude": 7,
			"willpower": 5,
		},
		"b_stats": {},
		"equipped_items": {},
		"inventory_slots": ItemSystem.get_default_inventory_state(),
	})

	if not await _check_frost_wastes_wolves(game_state):
		return
	if not await _check_newbie_melee_visuals():
		return

	print("check_frost_white_wolf_visuals_ok")
	quit(0)


func _check_frost_wastes_wolves(game_state: Node) -> bool:
	var preview_scene_path := str(game_state.begin_world_selection_entry(CultivationFrostWastesBlockout.get_preview_entry_id()))
	if preview_scene_path != CultivationWorldStructure.get_region_scene_path(CultivationFrostWastesBlockout.get_region_id()):
		push_error("frost wastes preview scene path mismatch: %s" % preview_scene_path)
		quit(1)
		return false
	if change_scene_to_file(preview_scene_path) != OK:
		push_error("failed to load frost wastes scene for wolf visual check")
		quit(1)
		return false
	await _await_frames(4, "waiting for frost wastes wolf visual bootstrap")

	var scene := current_scene
	if scene == null or not scene.has_method("get_live_enemy_nodes"):
		push_error("frost wastes scene missing live enemy accessors")
		quit(1)
		return false
	var wolves := scene.get_live_enemy_nodes() as Array[Node2D]
	if wolves.size() != 2:
		push_error("expected 2 live frost white wolves, got %d" % wolves.size())
		quit(1)
		return false

	for skill_id in EXPECTED_WOLF_SKILL_IDS:
		var skill_definition := SkillRegistry.get_skill_definition(skill_id)
		if skill_definition.is_empty():
			push_error("wolf skill definition missing from skill registry: %s" % skill_id)
			quit(1)
			return false
		var skill_visual := skill_definition.get("visual", {}) as Dictionary
		if skill_visual.is_empty():
			push_error("wolf skill visual should live on the skill definition: %s" % skill_id)
			quit(1)
			return false

	for wolf in wolves:
		if wolf == null or not wolf.has_method("get_template_id") or wolf.get_template_id() != "frost_white_wolf":
			push_error("non-wolf node detected in frost wastes enemy list")
			quit(1)
			return false
		if not wolf.has_method("get_visual_debug_state"):
			push_error("wolf visual debug state missing")
			quit(1)
			return false
		var visual_state: Dictionary = wolf.get_visual_debug_state()
		if not bool(visual_state.get("uses_sprite_visuals", false)):
			push_error("wolf should use dedicated sprite visuals: %s" % str(visual_state))
			quit(1)
			return false
		if str(visual_state.get("sheet_path", "")) != EXPECTED_WOLF_SHEET_PATH:
			push_error("wolf configured sprite frames path mismatch: %s" % str(visual_state))
			quit(1)
			return false
		if str(visual_state.get("sheet_path", "")).contains("Downloads"):
			push_error("wolf visual path should not reference Downloads: %s" % str(visual_state))
			quit(1)
			return false
		if str(visual_state.get("configured_sprite_frames_path", "")) == EXPECTED_MELEE_FRAMES_PATH:
			push_error("wolf should not point at melee grunt sprite frames")
			quit(1)
			return false
		if not wolf.has_method("get_enemy_config_snapshot"):
			push_error("wolf enemy config snapshot missing")
			quit(1)
			return false
		var enemy_config: Dictionary = wolf.get_enemy_config_snapshot()
		if not enemy_config.has("body_visual"):
			push_error("wolf template should keep body_visual")
			quit(1)
			return false
		if enemy_config.has("skill_visuals"):
			push_error("wolf template should no longer keep unit-side skill_visuals: %s" % str(enemy_config))
			quit(1)
			return false
		var unit_skill_ids: Array[String] = []
		for entry in enemy_config.get("skill_ids", []):
			unit_skill_ids.append(str(entry))
		for skill_id in EXPECTED_WOLF_SKILL_IDS:
			if not unit_skill_ids.has(skill_id):
				push_error("wolf template missing skill_id %s in %s" % [skill_id, str(unit_skill_ids)])
				quit(1)
				return false
		if not wolf.has_method("get_owned_skill_ids"):
			push_error("wolf owned skill accessor missing")
			quit(1)
			return false
		var owned_skill_ids: Array[String] = []
		for entry in wolf.get_owned_skill_ids():
			owned_skill_ids.append(str(entry))
		for skill_id in EXPECTED_WOLF_SKILL_IDS:
			if not owned_skill_ids.has(skill_id):
				push_error("wolf runtime missing owned skill %s in %s" % [skill_id, str(owned_skill_ids)])
				quit(1)
				return false
		var available_animations: Array = visual_state.get("available_animations", [])
		for animation_name in ["idle_up", "idle_down", "idle_left", "idle_right", "move_up", "move_down", "move_left", "move_right"]:
			if not available_animations.has(animation_name):
				push_error("wolf missing animation %s in %s" % [animation_name, str(available_animations)])
				quit(1)
				return false

		wolf.call("_update_visual_state", Vector2.LEFT)
		var left_state: Dictionary = wolf.get_visual_debug_state()
		if not bool(left_state.get("flip_h", false)):
			push_error("wolf left-facing state should mirror the right-facing source sprite: %s" % str(left_state))
			quit(1)
			return false
		wolf.call("_update_visual_state", Vector2.RIGHT)
		var right_state: Dictionary = wolf.get_visual_debug_state()
		if bool(right_state.get("flip_h", false)):
			push_error("wolf right-facing state should now use the unflipped source sprite: %s" % str(right_state))
			quit(1)
			return false

		wolf.reset_ai_runtime_state(false, true)
		if not wolf.request_skill_use_by_mode("primary"):
			push_error("wolf primary skill should remain triggerable for visual check")
			quit(1)
			return false
		await _await_frames(2, "waiting for wolf primary skill visual state")
		var primary_state: Dictionary = wolf.get_visual_debug_state()
		if str(primary_state.get("sheet_path", "")) != EXPECTED_WOLF_SHEET_PATH:
			push_error("wolf primary skill should keep wolf sprite frames: %s" % str(primary_state))
			quit(1)
			return false

		wolf.reset_ai_runtime_state(false, true)
		if not wolf.request_skill_use_by_mode("fallback"):
			push_error("wolf fallback skill should remain triggerable for visual check")
			quit(1)
			return false
		await _await_frames(2, "waiting for wolf fallback skill visual state")
		var fallback_state: Dictionary = wolf.get_visual_debug_state()
		if str(fallback_state.get("sheet_path", "")) != EXPECTED_WOLF_SHEET_PATH:
			push_error("wolf fallback skill should keep wolf sprite frames: %s" % str(fallback_state))
			quit(1)
			return false

	return true


func _check_newbie_melee_visuals() -> bool:
	var scene: PackedScene = load("res://game/scenes/newbie_village.tscn")
	if scene == null:
		push_error("load newbie_village.tscn failed")
		quit(1)
		return false
	var instance := scene.instantiate()
	if instance == null:
		push_error("instantiate newbie_village.tscn failed")
		quit(1)
		return false
	root.add_child(instance)
	await _await_frames(2, "waiting for newbie village melee visual bootstrap")

	var melee_count := 0
	for entry in instance.enemy_registry.values():
		var enemy_data := entry as Dictionary
		if str(enemy_data.get("template_id", "")) != "melee_grunt":
			continue
		var enemy_node: Node = enemy_data.get("node")
		if enemy_node == null or not enemy_node.has_method("get_visual_debug_state"):
			push_error("melee grunt visual debug state missing")
			quit(1)
			return false
		var visual_state: Dictionary = enemy_node.get_visual_debug_state()
		if str(visual_state.get("configured_sprite_frames_path", "")) != EXPECTED_MELEE_FRAMES_PATH:
			push_error("melee grunt sprite frames path mismatch after wolf visual import: %s" % str(visual_state))
			quit(1)
			return false
		if str(visual_state.get("sheet_path", "")) == EXPECTED_WOLF_SHEET_PATH:
			push_error("melee grunt should not point at wolf sheet")
			quit(1)
			return false
		melee_count += 1
	if melee_count != 2:
		push_error("expected 2 melee grunts in newbie village, got %d" % melee_count)
		quit(1)
		return false
	return true


func _start_watchdog() -> void:
	var watchdog := create_timer(CHECK_TIMEOUT_SEC)
	watchdog.timeout.connect(func() -> void:
		push_error("%s timed out after %.1f seconds" % [CHECK_NAME, CHECK_TIMEOUT_SEC])
		quit(1))


func _await_frames(frame_count: int, label: String) -> void:
	for _frame_index in range(frame_count):
		_guard_timeout(label)
		await process_frame
		_guard_timeout(label)


func _guard_timeout(label: String) -> void:
	var elapsed_sec := float(Time.get_ticks_msec() - _check_started_msec) / 1000.0
	if elapsed_sec > CHECK_TIMEOUT_SEC:
		push_error("%s timed out while %s after %.2f seconds" % [CHECK_NAME, label, elapsed_sec])
		quit(1)
