extends SceneTree

const ItemSystem = preload("res://game/scripts/item_system.gd")
const GameplaySceneContract = preload("res://game/scripts/gameplay_scene_contract.gd")
const CultivationWorldStructure = preload("res://game/scripts/cultivation_world_structure.gd")
const CultivationFrostWastesBlockout = preload("res://game/scripts/cultivation_frost_wastes_blockout.gd")
const CHECK_NAME := "check_cultivation_frost_wastes_runtime"
const CHECK_TIMEOUT_SEC := 30.0

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

	if not await _check_preview_runtime(game_state):
		return
	if not await _check_formal_runtime(game_state):
		return

	print("check_cultivation_frost_wastes_runtime_ok")
	quit(0)


func _check_preview_runtime(game_state: Node) -> bool:
	var preview_scene_path := str(game_state.begin_world_selection_entry(CultivationFrostWastesBlockout.get_preview_entry_id()))
	if preview_scene_path != CultivationWorldStructure.get_region_scene_path(CultivationFrostWastesBlockout.get_region_id()):
		push_error("preview scene path mismatch: %s" % preview_scene_path)
		quit(1)
		return false
	return await _load_and_check_runtime_scene(preview_scene_path, true)


func _check_formal_runtime(game_state: Node) -> bool:
	var formal_scene_path := str(game_state.begin_cultivation_world_exploration_from_region(CultivationFrostWastesBlockout.get_region_id()))
	if formal_scene_path != CultivationWorldStructure.get_region_scene_path(CultivationFrostWastesBlockout.get_region_id()):
		push_error("formal scene path mismatch: %s" % formal_scene_path)
		quit(1)
		return false
	return await _load_and_check_runtime_scene(formal_scene_path, false)


func _load_and_check_runtime_scene(scene_path: String, expect_preview_mode: bool) -> bool:
	if change_scene_to_file(scene_path) != OK:
		push_error("failed to load frost wastes runtime scene: %s" % scene_path)
		quit(1)
		return false
	await _await_frames(4, "waiting for frost wastes runtime bootstrap")

	var scene := current_scene
	if scene == null:
		push_error("runtime scene missing after load")
		quit(1)
		return false

	var contract_errors := GameplaySceneContract.validate_scene(scene, {
		"require_dialogue_registration": true,
	})
	if not contract_errors.is_empty():
		push_error("frost wastes gameplay contract errors: %s" % str(contract_errors))
		quit(1)
		return false

	if not scene.has_method("get_frost_wastes_scene_content_snapshot"):
		push_error("scene missing frost wastes content snapshot method")
		quit(1)
		return false
	if not scene.has_method("get_frost_wastes_content_self_check_errors"):
		push_error("scene missing frost wastes content self-check method")
		quit(1)
		return false

	var content_errors: Array = scene.get_frost_wastes_content_self_check_errors()
	if not content_errors.is_empty():
		push_error("frost wastes content self-check errors: %s" % str(content_errors))
		quit(1)
		return false

	var snapshot: Dictionary = scene.get_frost_wastes_scene_content_snapshot()
	if int(snapshot.get("room_floor_child_count", 0)) < 20:
		push_error("runtime room floor nodes too low: %s" % str(snapshot))
		quit(1)
		return false
	if int(snapshot.get("polygon_count", 0)) < 12:
		push_error("runtime polygon nodes too low: %s" % str(snapshot))
		quit(1)
		return false
	if int(snapshot.get("label_count", 0)) < 10:
		push_error("runtime labels too low: %s" % str(snapshot))
		quit(1)
		return false
	if int(snapshot.get("frost_white_wolf_count", 0)) != 2:
		push_error("expected 2 frost white wolves in runtime scene: %s" % str(snapshot))
		quit(1)
		return false
	if int(snapshot.get("enemy_registry_count", 0)) != 2:
		push_error("enemy registry should contain exactly 2 wolves: %s" % str(snapshot))
		quit(1)
		return false
	if int(snapshot.get("live_enemy_count", 0)) != 2:
		push_error("live enemy count should remain 2 after bootstrap: %s" % str(snapshot))
		quit(1)
		return false

	if not scene.has_method("get_enemy_registry_snapshot"):
		push_error("scene missing enemy registry snapshot method")
		quit(1)
		return false
	var wolves := scene.get_enemy_registry_snapshot() as Array
	if wolves.size() != 2:
		push_error("expected 2 enemy snapshot entries, got %d" % wolves.size())
		quit(1)
		return false
	var spawn_ids: Array[String] = []
	for entry in wolves:
		var dict := entry as Dictionary
		if str(dict.get("template_id", "")) != "frost_white_wolf":
			push_error("non-wolf enemy detected in frost wastes runtime: %s" % str(dict))
			quit(1)
			return false
		spawn_ids.append(str(dict.get("spawn_id", "")))
	if spawn_ids.size() != 2 or spawn_ids[0] == spawn_ids[1]:
		push_error("wolf spawn ids should be distinct: %s" % str(spawn_ids))
		quit(1)
		return false

	var gate_targets: Array[String] = scene.get_transition_gate_targets() if scene.has_method("get_transition_gate_targets") else []
	if expect_preview_mode:
		if not gate_targets.is_empty():
			push_error("preview runtime should not expose formal transition gates: %s" % str(gate_targets))
			quit(1)
			return false
	else:
		if gate_targets.size() != 2:
			push_error("formal runtime should expose 2 transition gates: %s" % str(gate_targets))
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
