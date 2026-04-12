extends SceneTree

const ItemSystem = preload("res://game/scripts/item_system.gd")
const CultivationWorldStructure = preload("res://game/scripts/cultivation_world_structure.gd")
const CultivationFrostWastesBlockout = preload("res://game/scripts/cultivation_frost_wastes_blockout.gd")
const GameplaySceneContract = preload("res://game/scripts/gameplay_scene_contract.gd")
const CHECK_NAME := "check_cultivation_world_structure"
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

	if not _check_structure_snapshot(game_state):
		return
	if not _check_world_selection_entries(game_state):
		return
	if not _check_random_corner_entry(game_state):
		return
	if not _check_progression_gatekeeping(game_state):
		return
	if not await _check_all_region_scene_integrations(game_state):
		return
	if not await _check_death_return_to_god_space(game_state):
		return

	print("check_cultivation_world_structure_ok")
	quit(0)


func _check_structure_snapshot(game_state: Node) -> bool:
	var structure_errors: Array = game_state.get_cultivation_world_structure_errors() if game_state.has_method("get_cultivation_world_structure_errors") else []
	if not structure_errors.is_empty():
		push_error("cultivation world structure errors: %s" % str(structure_errors))
		quit(1)
		return false

	var snapshot: Dictionary = game_state.get_cultivation_world_structure_snapshot() if game_state.has_method("get_cultivation_world_structure_snapshot") else {}
	if str(snapshot.get("world_id", "")) != CultivationWorldStructure.get_world_id():
		push_error("cultivation world id mismatch in structure snapshot")
		quit(1)
		return false
	if int(snapshot.get("region_count", 0)) != 9:
		push_error("cultivation world should expose 9 regions")
		quit(1)
		return false

	var start_ids := _normalize_string_array(snapshot.get("start_region_ids", []))
	if not _same_string_set(start_ids, CultivationWorldStructure.get_start_region_ids()):
		push_error("start region ids mismatch: %s" % str(start_ids))
		quit(1)
		return false
	var edge_ids := _normalize_string_array(snapshot.get("edge_region_ids", []))
	if not _same_string_set(edge_ids, CultivationWorldStructure.get_edge_region_ids()):
		push_error("edge region ids mismatch: %s" % str(edge_ids))
		quit(1)
		return false
	if str(snapshot.get("center_region_id", "")) != CultivationWorldStructure.get_center_region_id():
		push_error("center region id mismatch")
		quit(1)
		return false
	if CultivationWorldStructure.get_region_display_name(CultivationWorldStructure.REGION_ID_EDGE_EAST) != "\u4e71\u661f\u6d77":
		push_error("east edge display name mismatch")
		quit(1)
		return false
	if CultivationWorldStructure.get_region_display_name(CultivationWorldStructure.get_center_region_id()) != "\u4e2d\u5dde":
		push_error("center region display name mismatch")
		quit(1)
		return false
	if CultivationWorldStructure.get_region_display_name(CultivationWorldStructure.REGION_ID_CORNER_NORTHWEST) != CultivationFrostWastesBlockout.get_region_display_name():
		push_error("northwest display name mismatch")
		quit(1)
		return false

	var regions: Array = snapshot.get("regions", []) as Array
	if regions.size() != 9:
		push_error("structure snapshot region list size mismatch")
		quit(1)
		return false
	var seen_scene_paths: Array[String] = []
	for region_entry in regions:
		var entry: Dictionary = region_entry as Dictionary
		var scene_path := str(entry.get("scene_path", ""))
		if scene_path.is_empty():
			push_error("region scene path missing in structure snapshot")
			quit(1)
			return false
		if seen_scene_paths.has(scene_path):
			push_error("duplicate region scene path found: %s" % scene_path)
			quit(1)
			return false
		seen_scene_paths.append(scene_path)
	return true


func _check_world_selection_entries(game_state: Node) -> bool:
	var entries: Array = game_state.get_world_selection_entries() if game_state.has_method("get_world_selection_entries") else []
	var formal_found := false
	var preview_found := false
	for entry in entries:
		var dict := entry as Dictionary
		var entry_id := str(dict.get("entry_id", dict.get("world_id", "")))
		if entry_id == CultivationWorldStructure.get_world_id():
			formal_found = true
		if entry_id == CultivationFrostWastesBlockout.get_preview_entry_id():
			preview_found = true
			if str(dict.get("entry_kind", "")) != "cultivation_region_preview":
				push_error("preview entry kind mismatch")
				quit(1)
				return false
			if str(dict.get("preview_region_id", "")) != CultivationFrostWastesBlockout.get_region_id():
				push_error("preview entry should point at northwest region")
				quit(1)
				return false
	if not formal_found:
		push_error("formal cultivation world entry missing from world selection")
		quit(1)
		return false
	if not preview_found:
		push_error("frost wastes preview entry missing from world selection")
		quit(1)
		return false
	return true


func _check_random_corner_entry(game_state: Node) -> bool:
	for _iteration in range(8):
		var scene_path := str(game_state.begin_world_exploration("cultivation_world"))
		if scene_path.is_empty():
			push_error("random cultivation world entry returned empty scene path")
			quit(1)
			return false
		var exploration_state: Dictionary = game_state.get_world_exploration_state()
		var start_region_id := str(exploration_state.get("start_region_id", ""))
		var current_region_id := str(exploration_state.get("current_region_id", ""))
		if not CultivationWorldStructure.is_start_region(start_region_id):
			push_error("random cultivation start region should be one of the four corners: %s" % start_region_id)
			quit(1)
			return false
		if current_region_id != start_region_id:
			push_error("random cultivation start current region mismatch: %s vs %s" % [current_region_id, start_region_id])
			quit(1)
			return false
		if scene_path != CultivationWorldStructure.get_region_scene_path(start_region_id):
			push_error("random cultivation entry scene path mismatch: %s" % scene_path)
			quit(1)
			return false
		game_state.abort_world_exploration("random_entry_reset")
	return true


func _check_progression_gatekeeping(game_state: Node) -> bool:
	var corner_id := CultivationWorldStructure.REGION_ID_CORNER_NORTHWEST
	var edge_id := CultivationWorldStructure.REGION_ID_EDGE_NORTH
	var center_id := CultivationWorldStructure.get_center_region_id()
	var scene_path := str(game_state.begin_cultivation_world_exploration_from_region(corner_id))
	if scene_path != CultivationWorldStructure.get_region_scene_path(corner_id):
		push_error("corner start scene path mismatch")
		quit(1)
		return false
	if not str(game_state.travel_in_cultivation_world(center_id)).is_empty():
		push_error("corner region should not be able to enter center directly")
		quit(1)
		return false
	var corner_targets := _entry_ids(game_state.get_available_cultivation_region_entries())
	if not _same_string_set(corner_targets, [CultivationWorldStructure.REGION_ID_EDGE_NORTH, CultivationWorldStructure.REGION_ID_EDGE_WEST]):
		push_error("corner progression targets mismatch: %s" % str(corner_targets))
		quit(1)
		return false

	var edge_scene_path := str(game_state.travel_in_cultivation_world(edge_id))
	if edge_scene_path != CultivationWorldStructure.get_region_scene_path(edge_id):
		push_error("edge transition scene path mismatch")
		quit(1)
		return false
	var edge_state: Dictionary = game_state.get_world_exploration_state()
	if not bool(edge_state.get("entered_edge", false)):
		push_error("entering edge region should mark entered_edge")
		quit(1)
		return false
	if bool(edge_state.get("entered_core", false)):
		push_error("edge region should not mark entered_core")
		quit(1)
		return false
	var edge_targets := _entry_ids(game_state.get_available_cultivation_region_entries())
	if edge_targets != [center_id]:
		push_error("edge progression should only expose center: %s" % str(edge_targets))
		quit(1)
		return false

	var center_scene_path := str(game_state.travel_in_cultivation_world(center_id))
	if center_scene_path != CultivationWorldStructure.get_region_scene_path(center_id):
		push_error("center transition scene path mismatch")
		quit(1)
		return false
	var center_state: Dictionary = game_state.get_world_exploration_state()
	if not bool(center_state.get("entered_core", false)):
		push_error("entering center should mark entered_core")
		quit(1)
		return false
	if str(center_state.get("current_region_id", "")) != center_id:
		push_error("center current region id mismatch")
		quit(1)
		return false

	game_state.abort_world_exploration("progression_reset")
	return true


func _check_all_region_scene_integrations(game_state: Node) -> bool:
	for region_id in CultivationWorldStructure.get_region_ids():
		game_state.abort_world_exploration("integration_loop_reset")
		var scene_path := CultivationWorldStructure.get_region_scene_path(region_id)
		if change_scene_to_file(scene_path) != OK:
			push_error("failed to load region scene %s" % scene_path)
			quit(1)
			return false
		await _await_frames(4, "waiting for region bootstrap %s" % region_id)

		var scene := current_scene
		if scene == null or str(scene.scene_file_path) != scene_path:
			push_error("region scene did not become active: %s" % scene_path)
			quit(1)
			return false
		var contract_errors := GameplaySceneContract.validate_scene(scene, {
			"require_dialogue_registration": true,
		})
		if not contract_errors.is_empty():
			push_error("region scene contract errors for %s: %s" % [region_id, str(contract_errors)])
			quit(1)
			return false
		if not scene.has_method("get_region_id") or str(scene.get_region_id()) != region_id:
			push_error("region scene reported wrong region id for %s" % region_id)
			quit(1)
			return false
		var synced_state: Dictionary = game_state.get_world_exploration_state()
		if str(synced_state.get("current_region_id", "")) != region_id:
			push_error("region scene did not sync current region id for %s" % region_id)
			quit(1)
			return false
	return true


func _check_death_return_to_god_space(game_state: Node) -> bool:
	var start_region_id := CultivationWorldStructure.REGION_ID_CORNER_SOUTHEAST
	var scene_path := str(game_state.begin_cultivation_world_exploration_from_region(start_region_id))
	if change_scene_to_file(scene_path) != OK:
		push_error("failed to load cultivation death return scene")
		quit(1)
		return false
	await _await_frames(4, "waiting for cultivation death return bootstrap")

	var scene := current_scene
	if scene == null or not scene.has_method("request_player_death"):
		push_error("cultivation region scene missing death request entry")
		quit(1)
		return false
	scene.request_player_death()
	await _await_frames(2, "waiting for cultivation death panel")
	if not scene.has_method("is_result_showing") or not scene.is_result_showing():
		push_error("cultivation death result did not lock scene state")
		quit(1)
		return false
	if not scene.has_method("complete_death_return") or not scene.complete_death_return():
		push_error("cultivation death return completion failed")
		quit(1)
		return false
	await _await_frames(6, "waiting for god space after cultivation death")

	var hub_scene_path := str(game_state.get_god_space_scene_path())
	if current_scene == null or str(current_scene.scene_file_path) != hub_scene_path:
		push_error("death return did not land in god space")
		quit(1)
		return false
	var exploration_state: Dictionary = game_state.get_world_exploration_state()
	if game_state.get_current_world_id() != "":
		push_error("current world id should clear after cultivation death return")
		quit(1)
		return false
	if str(exploration_state.get("start_region_id", "")) != "":
		push_error("start region id should clear after cultivation death return")
		quit(1)
		return false
	if str(exploration_state.get("current_region_id", "")) != "":
		push_error("current region id should clear after cultivation death return")
		quit(1)
		return false
	if not bool(exploration_state.get("interrupted_by_death", false)):
		push_error("death return should mark interrupted_by_death")
		quit(1)
		return false
	if str(exploration_state.get("last_exit_reason", "")) != "death":
		push_error("death return should store death exit reason")
		quit(1)
		return false
	return true


func _entry_ids(entries: Array) -> Array[String]:
	var results: Array[String] = []
	for entry in entries:
		results.append(str((entry as Dictionary).get("region_id", "")))
	return results


func _normalize_string_array(values: Array) -> Array[String]:
	var results: Array[String] = []
	for value in values:
		results.append(str(value))
	return results


func _same_string_set(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for value in left:
		if not right.has(value):
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
