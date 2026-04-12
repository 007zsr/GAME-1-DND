extends SceneTree

const ItemSystem = preload("res://game/scripts/item_system.gd")
const CultivationWorldStructure = preload("res://game/scripts/cultivation_world_structure.gd")
const CultivationFrostWastesBlockout = preload("res://game/scripts/cultivation_frost_wastes_blockout.gd")
const CHECK_NAME := "check_cultivation_frost_wastes_blockout"
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

	if not _check_blockout_definition():
		return
	if not _check_selection_entries(game_state):
		return
	if not await _check_preview_scene_mode(game_state):
		return
	if not await _check_formal_scene_mode(game_state):
		return

	print("check_cultivation_frost_wastes_blockout_ok")
	quit(0)


func _check_blockout_definition() -> bool:
	var errors := CultivationFrostWastesBlockout.validate_blockout()
	if not errors.is_empty():
		push_error("frost wastes blockout definition errors: %s" % str(errors))
		quit(1)
		return false

	var snapshot := CultivationFrostWastesBlockout.build_snapshot()
	if not is_equal_approx(CultivationFrostWastesBlockout.get_map_scale(), 10.0):
		push_error("frost wastes blockout scale should be 10.0")
		quit(1)
		return false
	var areas: Array = snapshot.get("areas", []) as Array
	if areas.size() != 9:
		push_error("frost wastes blockout should expose 9 entries")
		quit(1)
		return false
	var routes: Array = snapshot.get("routes", []) as Array
	if routes.size() < 10:
		push_error("frost wastes blockout should expose 10 route polygons")
		quit(1)
		return false
	var outer_bounds := _compute_bounds(snapshot.get("outer_boundary_polygon", PackedVector2Array()))
	if outer_bounds.size.x < 700.0 or outer_bounds.size.y < 400.0:
		push_error("frost wastes outer bounds should reflect 10x enlarged map: %s" % str(outer_bounds))
		quit(1)
		return false
	var spawn_point := CultivationFrostWastesBlockout.get_spawn_point_meters()
	if spawn_point.x < 200.0 or spawn_point.y < 200.0:
		push_error("spawn point should scale with enlarged map: %s" % str(spawn_point))
		quit(1)
		return false

	var names := _collect_names(areas)
	for required_name in [
		"[1] \u65ad\u89d2\u77ad\u671b\u53f0",
		"[2] \u8352\u730e\u4eba\u6b8b\u5c4b",
		"[3] \u6b8b\u706b\u8425\u5730",
		"[4] \u57cb\u9aa8\u96ea\u5761",
		"[5] \u51b0\u5c01\u53e4\u6218\u573a\u8fb9\u7f18",
		"[6] \u51bb\u6cb3\u88c2\u53e3",
		"[7] \u5b88\u8a93\u53f0\u9057\u5740",
		"[\u51fa\u53e3A] \u65ad\u57ce\u5173 -> \u5317\u7586",
		"[\u51fa\u53e3B] \u88c2\u5ca9\u65e7\u9053 -> \u897f\u8fb9\u5927\u5c71",
	]:
		if not names.has(required_name):
			push_error("missing blockout name %s" % required_name)
			quit(1)
			return false

	var link_keys := _collect_link_keys(snapshot.get("links", []) as Array)
	for required_link in [
		"watchtower->hunters_ruin",
		"hunters_ruin->embers_camp",
		"hunters_ruin->burial_slope",
		"embers_camp->battlefield_edge",
		"burial_slope->battlefield_edge",
		"burial_slope->frozen_river_breach",
		"battlefield_edge->oath_ruins",
		"battlefield_edge->exit_north_border",
		"frozen_river_breach->oath_ruins",
		"frozen_river_breach->exit_west_mountain",
	]:
		if not link_keys.has(required_link):
			push_error("missing link %s" % required_link)
			quit(1)
			return false
	return true


func _check_selection_entries(game_state: Node) -> bool:
	var entries: Array = game_state.get_world_selection_entries() if game_state.has_method("get_world_selection_entries") else []
	var formal_entry := _find_entry(entries, CultivationWorldStructure.get_world_id())
	var preview_entry := _find_entry(entries, CultivationFrostWastesBlockout.get_preview_entry_id())
	if formal_entry.is_empty():
		push_error("formal cultivation world entry missing from world selection")
		quit(1)
		return false
	if preview_entry.is_empty():
		push_error("frost wastes preview entry missing from world selection")
		quit(1)
		return false
	if not bool(formal_entry.get("is_available", false)):
		push_error("formal cultivation world entry should remain available")
		quit(1)
		return false
	if not bool(preview_entry.get("is_available", false)):
		push_error("preview entry should be available")
		quit(1)
		return false
	if str(formal_entry.get("entry_kind", "")) == str(preview_entry.get("entry_kind", "")):
		push_error("formal and preview entries should not share the same entry kind")
		quit(1)
		return false
	if str(preview_entry.get("preview_region_id", "")) != CultivationFrostWastesBlockout.get_region_id():
		push_error("preview entry should target northwest region")
		quit(1)
		return false
	return true


func _check_preview_scene_mode(game_state: Node) -> bool:
	var exploration_before: Dictionary = game_state.get_world_exploration_state() if game_state.has_method("get_world_exploration_state") else {}
	var preview_scene_path := str(game_state.begin_world_selection_entry(CultivationFrostWastesBlockout.get_preview_entry_id()))
	if preview_scene_path != CultivationWorldStructure.get_region_scene_path(CultivationFrostWastesBlockout.get_region_id()):
		push_error("preview entry should point at northwest region scene")
		quit(1)
		return false
	if game_state.get_current_world_id() != "":
		push_error("preview entry should not set current_world_id")
		quit(1)
		return false
	var exploration_after: Dictionary = game_state.get_world_exploration_state() if game_state.has_method("get_world_exploration_state") else {}
	if exploration_after != exploration_before:
		push_error("preview entry should not mutate formal exploration state")
		quit(1)
		return false
	if change_scene_to_file(preview_scene_path) != OK:
		push_error("failed to load frost wastes preview scene")
		quit(1)
		return false
	await _await_frames(4, "waiting for preview scene bootstrap")

	var scene := current_scene
	if scene == null or not scene.has_method("get_region_id") or str(scene.get_region_id()) != CultivationFrostWastesBlockout.get_region_id():
		push_error("preview scene did not load northwest region")
		quit(1)
		return false
	if scene.has_method("get_transition_gate_targets") and not (scene.get_transition_gate_targets() as Array).is_empty():
		push_error("preview scene should not expose formal transition gates")
		quit(1)
		return false
	if not _check_scene_snapshot(scene):
		return false
	return true


func _check_formal_scene_mode(game_state: Node) -> bool:
	var formal_scene_path := str(game_state.begin_cultivation_world_exploration_from_region(CultivationFrostWastesBlockout.get_region_id()))
	if formal_scene_path != CultivationWorldStructure.get_region_scene_path(CultivationFrostWastesBlockout.get_region_id()):
		push_error("formal northwest scene path mismatch")
		quit(1)
		return false
	if change_scene_to_file(formal_scene_path) != OK:
		push_error("failed to load frost wastes formal scene")
		quit(1)
		return false
	await _await_frames(4, "waiting for formal scene bootstrap")

	var scene := current_scene
	if scene == null:
		push_error("formal scene missing after load")
		quit(1)
		return false
	var gate_targets: Array = scene.get_transition_gate_targets() if scene.has_method("get_transition_gate_targets") else []
	if not _same_string_set(_normalize_string_array(gate_targets), [CultivationWorldStructure.REGION_ID_EDGE_NORTH, CultivationWorldStructure.REGION_ID_EDGE_WEST]):
		push_error("formal northwest scene should keep north and west transition gates: %s" % str(gate_targets))
		quit(1)
		return false
	return _check_scene_snapshot(scene)


func _check_scene_snapshot(scene: Node) -> bool:
	if scene == null or not scene.has_method("get_frost_wastes_blockout_snapshot"):
		push_error("northwest scene missing frost wastes snapshot method")
		quit(1)
		return false
	var snapshot: Dictionary = scene.get_frost_wastes_blockout_snapshot()
	var areas: Array = snapshot.get("areas", []) as Array
	if areas.size() != 9:
		push_error("scene snapshot should expose 9 blockout entries")
		quit(1)
		return false
	var routes: Array = snapshot.get("routes", []) as Array
	if routes.size() < 10:
		push_error("scene snapshot should expose 10 route polygons")
		quit(1)
		return false
	if not scene.has_method("get_frost_wastes_walkable_polygon_count") or int(scene.get_frost_wastes_walkable_polygon_count()) < 19:
		push_error("scene should expose combined walkable polygons for areas and routes")
		quit(1)
		return false
	if not scene.has_method("is_frost_wastes_point_walkable") or not scene.is_frost_wastes_point_walkable(CultivationFrostWastesBlockout.get_spawn_point_meters()):
		push_error("spawn point should be walkable in scene")
		quit(1)
		return false
	if not scene.has_method("get_world_bounds_meters"):
		push_error("scene should expose dynamic world bounds")
		quit(1)
		return false
	var world_bounds: Rect2 = scene.get_world_bounds_meters()
	if world_bounds.size.x < 720.0 or world_bounds.size.y < 430.0:
		push_error("scene world bounds should expand with enlarged map: %s" % str(world_bounds))
		quit(1)
		return false
	if scene.get("player") == null or not scene.player.has_method("get_move_speed"):
		push_error("scene player missing move speed accessor")
		quit(1)
		return false
	if not is_equal_approx(float(scene.player.get_move_speed()), 8.0):
		push_error("player move speed should be 8.0 for large-map testing: %s" % str(scene.player.get_move_speed()))
		quit(1)
		return false
	if not scene.player.has_method("get_camera_zoom_limits"):
		push_error("scene player missing camera zoom limits accessor")
		quit(1)
		return false
	var camera_limits: Dictionary = scene.player.get_camera_zoom_limits()
	if float(camera_limits.get("default", 1.0)) >= 1.0 or float(camera_limits.get("min", 1.0)) >= 1.0:
		push_error("frost wastes scene should loosen camera zoom for the enlarged map: %s" % str(camera_limits))
		quit(1)
		return false
	return true


func _find_entry(entries: Array, entry_id: String) -> Dictionary:
	for entry in entries:
		var dict := entry as Dictionary
		if str(dict.get("entry_id", dict.get("world_id", ""))) == entry_id:
			return dict
	return {}


func _collect_names(entries: Array) -> Array[String]:
	var results: Array[String] = []
	for entry in entries:
		results.append(str((entry as Dictionary).get("display_name", "")))
	return results


func _collect_link_keys(entries: Array) -> Array[String]:
	var results: Array[String] = []
	for entry in entries:
		var dict := entry as Dictionary
		results.append("%s->%s" % [str(dict.get("from_area_id", "")), str(dict.get("to_area_id", ""))])
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


func _compute_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_x := points[0].x
	var max_x := points[0].x
	var min_y := points[0].y
	var max_y := points[0].y
	for point in points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


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
