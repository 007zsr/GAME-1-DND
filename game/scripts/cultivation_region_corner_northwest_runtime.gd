extends "res://game/scripts/cultivation_world_region.gd"

const CultivationFrostWastesBlockout = preload("res://game/scripts/cultivation_frost_wastes_blockout.gd")

const TITLE_RECT := Rect2(Vector2(11.4, 9.4), Vector2(10.8, 2.8))
const RETURN_GATE_POSITION_METERS := Vector2(19.2, 23.4)
const OUTER_FILL_COLOR := Color(0.11, 0.16, 0.24, 1.0)
const OUTER_OUTLINE_COLOR := Color(0.70, 0.80, 0.92, 0.45)
const MAIN_ROUTE_FILL_COLOR := Color(0.47, 0.62, 0.76, 0.94)
const BRANCH_ROUTE_FILL_COLOR := Color(0.38, 0.52, 0.66, 0.88)
const NARROW_ROUTE_FILL_COLOR := Color(0.31, 0.45, 0.58, 0.92)
const EXIT_ROUTE_FILL_COLOR := Color(0.60, 0.70, 0.82, 0.96)
const ROUTE_OUTLINE_COLOR := Color(0.89, 0.95, 1.0, 0.52)
const AREA_FILL_COLOR := Color(0.60, 0.73, 0.84, 0.84)
const AREA_FILL_ALT_COLOR := Color(0.55, 0.68, 0.79, 0.86)
const AREA_OUTLINE_COLOR := Color(0.94, 0.98, 1.0, 0.86)
const EXIT_FILL_COLOR := Color(0.73, 0.81, 0.91, 0.92)
const EXIT_OUTLINE_COLOR := Color(0.99, 1.0, 1.0, 0.96)
const LABEL_BG_COLOR := Color(0.08, 0.12, 0.18, 0.82)
const EXIT_LABEL_BG_COLOR := Color(0.12, 0.16, 0.22, 0.88)
const LABEL_TEXT_COLOR := Color(0.95, 0.98, 1.0, 1.0)
const TITLE_FONT_SIZE := 34
const AREA_LABEL_FONT_SIZE := 26
const EXIT_LABEL_FONT_SIZE := 22
const PLAYER_CAMERA_DEFAULT_ZOOM := 0.55
const PLAYER_CAMERA_MIN_ZOOM := 0.35
const PLAYER_CAMERA_MAX_ZOOM := 2.4
const PLAYER_CAMERA_ZOOM_STEP := 0.12
const ENEMY_SCENE_PATH := "res://game/scenes/enemy_actor.tscn"
const BLOCK_DAMAGE_MULTIPLIER := 0.5
const FLOATING_TEXT_LIFETIME := 0.75
const FROST_WHITE_WOLF_TEMPLATE := {
	"template_id": "frost_white_wolf",
	"name": "寒霜白狼",
	"display_name": "寒霜白狼",
	"role": "wolf",
	"max_health": 118,
	"move_speed": 2.05,
	"attack_range": 8.0,
	"attack_cooldown": 30.0,
	"windup": 0.22,
	"recovery": 0.34,
	"fallback_attack_cooldown": 4.2,
	"fallback_windup": 0.12,
	"fallback_recovery": 0.36,
	"size_meters": Vector2(0.52, 0.42),
	"display_color": Color(0.84, 0.90, 0.98, 1.0),
	"label_font_size": 10,
	"hp_bar_style": "red",
	"show_name": true,
	"hit_rate": 92.0,
	"crit_rate": 12.0,
	"crit_damage": 1.6,
	"skill_ids": [
		"frost_white_wolf_rear_dash",
		"frost_white_wolf_triple_bite",
	],
	"skill_bindings": {
		"primary": "frost_white_wolf_rear_dash",
		"fallback": "frost_white_wolf_triple_bite",
	},
	"body_visual": {
		"sheet_path": "res://game/assets/textures/characters/enemies/frost_white_wolf/spritesheets/frost_white_wolf_sheet_v001.png",
		"display_scale": 0.055,
		"anchor_offset_pixels": Vector2(0.0, -8.0),
		"default_facing": "right",
		"mirror_left_from_right": true,
		"use_raw_texture_colors": true,
		"frame_sets": {
			"idle_down": [Rect2(768, 0, 384, 384)],
			"idle_up": [Rect2(768, 384, 384, 384)],
			"idle_left": [Rect2(384, 768, 384, 384)],
			"idle_right": [Rect2(384, 768, 384, 384)],
			"move_down": [
				Rect2(0, 0, 384, 384),
				Rect2(384, 0, 384, 384),
				Rect2(768, 0, 384, 384),
				Rect2(1152, 0, 384, 384),
				Rect2(1536, 0, 384, 384)
			],
			"move_up": [
				Rect2(0, 384, 384, 384),
				Rect2(384, 384, 384, 384),
				Rect2(768, 384, 384, 384),
				Rect2(1152, 384, 384, 384),
				Rect2(1536, 384, 384, 384)
			],
			"move_left": [
				Rect2(0, 768, 384, 384),
				Rect2(384, 768, 384, 384),
				Rect2(768, 768, 384, 384),
				Rect2(1152, 768, 384, 384),
				Rect2(1536, 768, 384, 384),
				Rect2(1920, 768, 384, 384),
				Rect2(2304, 768, 384, 384),
				Rect2(2688, 768, 384, 384)
			],
			"move_right": [
				Rect2(0, 768, 384, 384),
				Rect2(384, 768, 384, 384),
				Rect2(768, 768, 384, 384),
				Rect2(1152, 768, 384, 384),
				Rect2(1536, 768, 384, 384),
				Rect2(1920, 768, 384, 384),
				Rect2(2304, 768, 384, 384),
				Rect2(2688, 768, 384, 384)
			],
		},
	},
}

var enemy_registry: Dictionary = {}
var frost_wastes_content_self_check_errors: Array[String] = []


func _ready() -> void:
	super._ready()
	if player != null:
		if player.has_method("configure_camera_zoom_limits"):
			player.configure_camera_zoom_limits(
				PLAYER_CAMERA_DEFAULT_ZOOM,
				PLAYER_CAMERA_MIN_ZOOM,
				PLAYER_CAMERA_MAX_ZOOM,
				PLAYER_CAMERA_ZOOM_STEP
			)
		player.position = CultivationFrostWastesBlockout.get_spawn_point_meters() * METERS_TO_PIXELS
	_spawn_frost_white_wolves()
	_update_ui()
	call_deferred("_run_frost_wastes_content_self_check")


func get_frost_wastes_blockout_snapshot() -> Dictionary:
	return CultivationFrostWastesBlockout.build_snapshot()


func get_frost_wastes_walkable_polygon_count() -> int:
	return CultivationFrostWastesBlockout.get_walkable_polygons().size()


func get_world_bounds_meters() -> Rect2:
	return CultivationFrostWastesBlockout.get_world_bounds_meters()


func is_frost_wastes_point_walkable(point_meters: Vector2) -> bool:
	return _is_point_inside_walkable_polygons(point_meters)


func get_enemy_registry_snapshot() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for enemy_id in enemy_registry.keys():
		var entry := enemy_registry.get(enemy_id, {}) as Dictionary
		var enemy: Node2D = entry.get("node") as Node2D
		results.append({
			"template_id": str(entry.get("template_id", "")),
			"display_name": enemy.get_display_name() if enemy != null and is_instance_valid(enemy) and enemy.has_method("get_display_name") else "",
			"position": enemy.global_position if enemy != null and is_instance_valid(enemy) else Vector2.ZERO,
			"is_alive": enemy != null and is_instance_valid(enemy) and enemy.has_method("is_alive") and enemy.is_alive(),
			"ai_id": enemy.get_ai_id() if enemy != null and is_instance_valid(enemy) and enemy.has_method("get_ai_id") else "",
			"spawn_id": str(entry.get("spawn_id", "")),
		})
	return results


func get_live_enemy_nodes() -> Array[Node2D]:
	var results: Array[Node2D] = []
	for enemy_id in enemy_registry.keys():
		var enemy := (enemy_registry.get(enemy_id, {}) as Dictionary).get("node") as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		results.append(enemy)
	return results


func get_enemy_count_by_template(template_id: String) -> int:
	var count := 0
	for snapshot in get_enemy_registry_snapshot():
		var entry := snapshot as Dictionary
		if str(entry.get("template_id", "")) == template_id and bool(entry.get("is_alive", false)):
			count += 1
	return count


func get_frost_wastes_content_self_check_errors() -> Array[String]:
	return frost_wastes_content_self_check_errors.duplicate()


func get_frost_wastes_scene_content_snapshot() -> Dictionary:
	var room_floor_child_count := room_floor_layer.get_child_count() if room_floor_layer != null else 0
	var polygon_count := 0
	var outline_count := 0
	var label_count := 0
	var tag_background_count := 0
	if room_floor_layer != null:
		for child in room_floor_layer.get_children():
			if child is Polygon2D:
				polygon_count += 1
			elif child is Line2D:
				outline_count += 1
			elif child is Label:
				label_count += 1
			elif child is ColorRect:
				tag_background_count += 1
	var interactable_count := interactable_layer.get_child_count() if interactable_layer != null else 0
	var live_enemy_count := get_live_enemy_nodes().size()
	return {
		"room_floor_layer_exists": room_floor_layer != null,
		"room_floor_child_count": room_floor_child_count,
		"polygon_count": polygon_count,
		"outline_count": outline_count,
		"label_count": label_count,
		"tag_background_count": tag_background_count,
		"interactable_layer_exists": interactable_layer != null,
		"interactable_count": interactable_count,
		"return_gate_exists": return_gate != null and is_instance_valid(return_gate),
		"transition_gate_count": transition_gates.size(),
		"enemy_registry_count": enemy_registry.size(),
		"live_enemy_count": live_enemy_count,
		"frost_white_wolf_count": get_enemy_count_by_template("frost_white_wolf"),
		"world_bounds": get_world_bounds_meters(),
		"ground_rect": Rect2(
			Vector2(ground.offset_left, ground.offset_top),
			Vector2(ground.offset_right - ground.offset_left, ground.offset_bottom - ground.offset_top)
		) if ground != null else Rect2(),
	}


func _run_frost_wastes_content_self_check() -> void:
	frost_wastes_content_self_check_errors = _validate_frost_wastes_content_state()
	if frost_wastes_content_self_check_errors.is_empty():
		return
	for error_text in frost_wastes_content_self_check_errors:
		push_error("FrostWastesContent[%s] %s" % [scene_file_path if not str(scene_file_path).is_empty() else name, error_text])


func _validate_frost_wastes_content_state() -> Array[String]:
	var errors: Array[String] = []
	var snapshot := get_frost_wastes_scene_content_snapshot()
	if not bool(snapshot.get("room_floor_layer_exists", false)):
		errors.append("room_floor_layer missing")
		return errors
	if int(snapshot.get("room_floor_child_count", 0)) < 20:
		errors.append("room_floor_layer appears underpopulated")
	if int(snapshot.get("polygon_count", 0)) < 12:
		errors.append("map polygon count too low")
	if int(snapshot.get("outline_count", 0)) < 10:
		errors.append("map outline count too low")
	if int(snapshot.get("label_count", 0)) < 10:
		errors.append("map label count too low")
	if int(snapshot.get("tag_background_count", 0)) < 10:
		errors.append("tag background count too low")
	if not bool(snapshot.get("interactable_layer_exists", false)):
		errors.append("interactable_layer missing")
	if not bool(snapshot.get("return_gate_exists", false)):
		errors.append("return gate missing")
	if int(snapshot.get("frost_white_wolf_count", 0)) != 2:
		errors.append("expected 2 frost white wolves")
	var world_bounds := snapshot.get("world_bounds", Rect2()) as Rect2
	if world_bounds.size.x < 720.0 or world_bounds.size.y < 430.0:
		errors.append("world bounds smaller than expected large-map runtime")
	return errors


func _build_world_layout() -> void:
	for child in room_floor_layer.get_children():
		child.queue_free()

	var world_bounds := get_world_bounds_meters()
	ground.color = Color(0.06, 0.10, 0.16, 1.0)
	grid_overlay.color = Color(0.92, 0.98, 1.0, 0.05)
	ground.offset_left = world_bounds.position.x * METERS_TO_PIXELS
	ground.offset_top = world_bounds.position.y * METERS_TO_PIXELS
	ground.offset_right = (world_bounds.position.x + world_bounds.size.x) * METERS_TO_PIXELS
	ground.offset_bottom = (world_bounds.position.y + world_bounds.size.y) * METERS_TO_PIXELS
	grid_overlay.polygon = PackedVector2Array([
		world_bounds.position * METERS_TO_PIXELS,
		Vector2(world_bounds.position.x + world_bounds.size.x, world_bounds.position.y) * METERS_TO_PIXELS,
		(world_bounds.position + world_bounds.size) * METERS_TO_PIXELS,
		Vector2(world_bounds.position.x, world_bounds.position.y + world_bounds.size.y) * METERS_TO_PIXELS,
	])

	var title_rect := _get_title_rect()
	_add_polygon(CultivationFrostWastesBlockout.get_outer_boundary_polygon(), OUTER_FILL_COLOR, 0)
	_add_polygon_outline(CultivationFrostWastesBlockout.get_outer_boundary_polygon(), OUTER_OUTLINE_COLOR, 4.0, 1)
	_add_floor_rect(title_rect, Color(0.18, 0.28, 0.40, 1.0))
	_add_outline(title_rect, Color(0.92, 0.98, 1.0, 0.62))

	_build_route_polygons()
	_build_area_blocks()
	_build_title_label()


func _get_available_region_entries() -> Array[Dictionary]:
	if _is_preview_mode():
		return []
	return super._get_available_region_entries()


func _sync_region_runtime_state() -> void:
	if _is_preview_mode():
		return
	super._sync_region_runtime_state()


func return_to_god_space(exit_reason: String = "manual_return") -> bool:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null:
		return false
	if _is_preview_mode():
		if game_state.has_method("clear_active_scene_entry_context"):
			game_state.clear_active_scene_entry_context()
	else:
		if game_state.has_method("abort_world_exploration"):
			game_state.abort_world_exploration(exit_reason)
	var target_scene_path := str(game_state.get_god_space_scene_path()) if game_state.has_method("get_god_space_scene_path") else ""
	if target_scene_path.is_empty():
		return false
	get_tree().paused = false
	if player != null and player.has_method("unlock_gameplay"):
		player.unlock_gameplay()
	get_tree().change_scene_to_file(target_scene_path)
	return true


func resolve_world_movement(current_position: Vector2, motion: Vector2, half_size_pixels: Vector2) -> Vector2:
	var clamped_target := super.resolve_world_movement(current_position, motion, half_size_pixels)
	if _is_walkable_position_pixels(clamped_target, half_size_pixels):
		return clamped_target

	var full_motion := clamped_target - current_position
	var direct_result := _search_walkable_motion(current_position, full_motion, half_size_pixels)
	if direct_result != current_position:
		return direct_result

	var x_first := _search_walkable_motion(current_position, Vector2(full_motion.x, 0.0), half_size_pixels)
	var x_then_y := _search_walkable_motion(x_first, Vector2(0.0, full_motion.y), half_size_pixels)
	if x_then_y != current_position:
		return x_then_y

	var y_first := _search_walkable_motion(current_position, Vector2(0.0, full_motion.y), half_size_pixels)
	var y_then_x := _search_walkable_motion(y_first, Vector2(full_motion.x, 0.0), half_size_pixels)
	if y_then_x != current_position:
		return y_then_x

	return current_position


func _spawn_interactables() -> void:
	for gate in transition_gates:
		if gate != null and is_instance_valid(gate):
			gate.queue_free()
	transition_gates.clear()
	if return_gate != null and is_instance_valid(return_gate):
		return_gate.queue_free()

	var gate_scene: PackedScene = load(GATE_SCENE_PATH)
	var available_entries := _get_available_region_entries()
	for index in range(available_entries.size()):
		var entry: Dictionary = available_entries[index]
		var gate: Node2D = gate_scene.instantiate()
		interactable_layer.add_child(gate)
		var target_region_id := str(entry.get("region_id", ""))
		var target_name := str(entry.get("display_name", target_region_id))
		gate.configure(
			self,
			player,
			_get_gate_position_for_target(target_region_id, index, available_entries.size()),
			METERS_TO_PIXELS,
			"travel:%s" % target_region_id,
			"\u524d\u5f80 %s" % target_name,
			"\u6309 E \u8fdb\u5165 %s" % target_name
		)
		transition_gates.append(gate)

	return_gate = gate_scene.instantiate()
	interactable_layer.add_child(return_gate)
	return_gate.configure(
		self,
		player,
		_get_return_gate_position_meters(),
		METERS_TO_PIXELS,
		"return_to_god_space",
		"\u8fd4\u56de\u4e3b\u795e\u7a7a\u95f4",
		"\u6309 E \u7ed3\u675f\u89c2\u5bdf"
	)


func _update_ui() -> void:
	super._update_ui()
	var mode_text := "\u6d4b\u8bd5\u76f4\u8fbe" if _is_preview_mode() else "\u6b63\u5f0f\u533a\u57df"
	var next_text := "\u4ec5\u89c2\u5bdf\u5bd2\u971c\u8352\u539f\u7070\u76d2" if _is_preview_mode() else _build_next_region_text()
	location_info_label.text = "\u4fee\u4ed9\u4e16\u754c  |  \u5f53\u524d\u533a\u57df\uff1a\u5bd2\u971c\u8352\u539f  |  \u6a21\u5f0f\uff1a%s  |  \u4e0b\u4e00\u6b65\uff1a%s" % [
		mode_text,
		next_text,
	]
	player_info_label.text = "\u5730\u56fe\u7070\u76d2\uff1a7 \u4e2a\u5b50\u5206\u533a / 2 \u4e2a\u51fa\u53e3 / %d \u6bb5\u901a\u8def  |  \u5750\u6807 %.1f, %.1f  |  HP %d/%d" % [
		CultivationFrostWastesBlockout.get_route_definitions().size(),
		player.position.x / METERS_TO_PIXELS,
		player.position.y / METERS_TO_PIXELS,
		player.get_current_health(),
		player.get_max_health(),
	]
	if player_info_label != null:
		player_info_label.text += "  |  寒霜白狼 %d" % get_enemy_count_by_template("frost_white_wolf")


func _build_route_polygons() -> void:
	for route_definition in CultivationFrostWastesBlockout.get_route_definitions():
		var route_polygon := CultivationFrostWastesBlockout.get_route_polygon_points(str(route_definition.get("link_key", "")))
		var route_kind := str(route_definition.get("route_kind", "branch"))
		_add_polygon(route_polygon, _get_route_fill_color(route_kind), 2)
		_add_polygon_outline(route_polygon, ROUTE_OUTLINE_COLOR, 2.5, 3)


func _build_area_blocks() -> void:
	for entry in CultivationFrostWastesBlockout.get_area_definitions():
		var area_id := str(entry.get("area_id", ""))
		var polygon := CultivationFrostWastesBlockout.get_area_polygon_points(area_id)
		var rect_meters := Rect2(Vector2(entry.get("blockout_position", Vector2.ZERO)), Vector2(entry.get("blockout_size", Vector2.ZERO)))
		var is_exit := bool(entry.get("is_exit", false))
		var fill_color := EXIT_FILL_COLOR if is_exit else AREA_FILL_ALT_COLOR
		if not is_exit and int(rect_meters.position.y) % 2 == 0:
			fill_color = AREA_FILL_COLOR
		_add_polygon(polygon, fill_color, 4)
		_add_polygon_outline(polygon, EXIT_OUTLINE_COLOR if is_exit else AREA_OUTLINE_COLOR, 3.0, 5)
		var inset_polygons := Geometry2D.offset_polygon(polygon, -0.55)
		if not inset_polygons.is_empty():
			_add_polygon(inset_polygons[0], Color(1.0, 1.0, 1.0, 0.06), 6)
		_add_area_label(
			Vector2(entry.get("label_anchor", rect_meters.position)),
			Vector2(entry.get("label_size", rect_meters.size)),
			str(entry.get("display_name", "")),
			is_exit
		)


func _build_title_label() -> void:
	var title_rect := _get_title_rect()
	_add_tag_plaque(title_rect.position, title_rect.size, "\u5bd2\u971c\u8352\u539f\u7070\u76d2", false, TITLE_FONT_SIZE)


func _add_area_label(anchor_meters: Vector2, size_meters: Vector2, text: String, is_exit: bool) -> void:
	_add_tag_plaque(anchor_meters, size_meters, text, is_exit, EXIT_LABEL_FONT_SIZE if is_exit else AREA_LABEL_FONT_SIZE)


func _add_tag_plaque(anchor_meters: Vector2, size_meters: Vector2, text: String, is_exit: bool, font_size: int) -> void:
	var bg := ColorRect.new()
	bg.name = "TagBg_%s" % text.md5_text().substr(0, 8)
	bg.position = anchor_meters * METERS_TO_PIXELS
	bg.size = size_meters * METERS_TO_PIXELS
	bg.color = EXIT_LABEL_BG_COLOR if is_exit else LABEL_BG_COLOR
	room_floor_layer.add_child(bg)

	var label := Label.new()
	label.name = "BlockoutLabel_%s" % text.md5_text().substr(0, 8)
	label.position = anchor_meters * METERS_TO_PIXELS + Vector2(8.0, 4.0)
	label.size = size_meters * METERS_TO_PIXELS - Vector2(16.0, 8.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = LABEL_TEXT_COLOR
	label.text = text
	room_floor_layer.add_child(label)


func _build_next_region_text() -> String:
	var next_region_names: Array[String] = []
	for entry in super._get_available_region_entries():
		next_region_names.append(str((entry as Dictionary).get("display_name", "")))
	if next_region_names.is_empty():
		return "\u5f53\u524d\u5df2\u5230\u7ec8\u70b9\u5c42"
	return ", ".join(next_region_names)


func _get_route_fill_color(route_kind: String) -> Color:
	match route_kind:
		"main":
			return MAIN_ROUTE_FILL_COLOR
		"narrow":
			return NARROW_ROUTE_FILL_COLOR
		"exit":
			return EXIT_ROUTE_FILL_COLOR
		_:
			return BRANCH_ROUTE_FILL_COLOR


func _add_polygon(points_meters: PackedVector2Array, color: Color, z_index: int) -> void:
	var polygon := Polygon2D.new()
	polygon.color = color
	polygon.z_index = z_index
	polygon.polygon = _scale_points(points_meters)
	room_floor_layer.add_child(polygon)


func _add_polygon_outline(points_meters: PackedVector2Array, color: Color, width: float, z_index: int) -> void:
	var outline := Line2D.new()
	outline.width = width
	outline.default_color = color
	outline.closed = true
	outline.z_index = z_index
	outline.points = _scale_points(points_meters)
	room_floor_layer.add_child(outline)


func _scale_points(points_meters: PackedVector2Array) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	for point in points_meters:
		scaled.append(point * METERS_TO_PIXELS)
	return scaled


func _get_gate_position_for_target(target_region_id: String, index: int, gate_count: int) -> Vector2:
	var area_id := CultivationFrostWastesBlockout.get_gate_area_id_for_region(target_region_id)
	if not area_id.is_empty():
		return CultivationFrostWastesBlockout.get_area_center(area_id)
	if gate_count <= 1:
		return Vector2(66.0, 28.0) * CultivationFrostWastesBlockout.get_map_scale()
	if gate_count == 2:
		return [Vector2(62.0, 20.0), Vector2(62.0, 36.0)][index] * CultivationFrostWastesBlockout.get_map_scale()
	return Vector2(60.0, 18.0 + float(index) * 8.0) * CultivationFrostWastesBlockout.get_map_scale()


func _get_title_rect() -> Rect2:
	var map_scale := CultivationFrostWastesBlockout.get_map_scale()
	return Rect2(TITLE_RECT.position * map_scale, TITLE_RECT.size * map_scale)


func _get_return_gate_position_meters() -> Vector2:
	return RETURN_GATE_POSITION_METERS * CultivationFrostWastesBlockout.get_map_scale()


func _search_walkable_motion(origin: Vector2, motion: Vector2, half_size_pixels: Vector2) -> Vector2:
	if motion == Vector2.ZERO:
		return origin
	var best := origin
	for step in range(1, 13):
		var candidate := origin + motion * (float(step) / 12.0)
		if _is_walkable_position_pixels(candidate, half_size_pixels):
			best = candidate
		else:
			break
	return best


func _is_walkable_position_pixels(position_pixels: Vector2, half_size_pixels: Vector2) -> bool:
	var center := position_pixels / METERS_TO_PIXELS
	var sample_radius := minf(half_size_pixels.x, half_size_pixels.y) / METERS_TO_PIXELS * 0.55
	var sample_points := [
		center,
		center + Vector2(sample_radius, 0.0),
		center + Vector2(-sample_radius, 0.0),
		center + Vector2(0.0, sample_radius),
		center + Vector2(0.0, -sample_radius),
	]
	for sample in sample_points:
		if not _is_point_inside_walkable_polygons(sample):
			return false
	return true


func _is_point_inside_walkable_polygons(point_meters: Vector2) -> bool:
	for polygon in CultivationFrostWastesBlockout.get_walkable_polygons():
		if Geometry2D.is_point_in_polygon(point_meters, polygon):
			return true
	return false


func _is_preview_mode() -> bool:
	var game_state: Node = get_node_or_null("/root/GameState")
	return game_state != null and game_state.has_method("is_cultivation_region_preview_active") and game_state.is_cultivation_region_preview_active(CultivationFrostWastesBlockout.get_region_id())


func find_enemies_in_radius(center_position: Vector2, radius_pixels: float) -> Array:
	if battle_result_locked:
		return []
	var results: Array = []
	for enemy_id in enemy_registry.keys():
		var entry := enemy_registry.get(enemy_id, {}) as Dictionary
		var enemy := entry.get("node") as Node2D
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		if enemy.has_method("is_hostile_to_player") and not enemy.is_hostile_to_player():
			continue
		var half_size_pixels := entry.get("half_size_pixels", Vector2.ZERO) as Vector2
		if _rectangle_overlaps_circle(enemy.global_position, half_size_pixels, center_position, radius_pixels):
			results.append(enemy)
	return results


func apply_player_slash_attack(center_position: Vector2, direction: Vector2, radius_pixels: float, damage: float) -> void:
	if battle_result_locked:
		return
	for enemy in find_enemies_in_radius(center_position, radius_pixels):
		var enemy_id: int = enemy.get_instance_id()
		var half_size_pixels := (enemy_registry.get(enemy_id, {}) as Dictionary).get("half_size_pixels", Vector2.ZERO) as Vector2
		if _rectangle_overlaps_sector(enemy.global_position, half_size_pixels, center_position, direction, radius_pixels, 180.0):
			_resolve_player_attack(enemy, damage)


func apply_enemy_sector_attack(attacker_name: String, center_position: Vector2, direction: Vector2, radius_pixels: float, arc_degrees: float, damage: int, attack_profile: Dictionary = {}) -> void:
	if battle_result_locked or dialogue_context_active:
		return
	if not is_player_alive():
		return
	if _rectangle_overlaps_sector(player.global_position, player.get_hitbox_half_size_pixels(), center_position, direction, radius_pixels, arc_degrees):
		_resolve_enemy_attack(attacker_name, damage, attack_profile, player.global_position)


func resolve_walkable_target_point(target_position: Vector2, half_size_pixels: Vector2, search_radius_pixels: float, fallback_position: Vector2 = Vector2.ZERO) -> Dictionary:
	if _is_walkable_position_pixels(target_position, half_size_pixels):
		return {"success": true, "position": target_position}
	var sample_directions := [
		Vector2.RIGHT,
		Vector2(0.707, 0.707),
		Vector2.DOWN,
		Vector2(-0.707, 0.707),
		Vector2.LEFT,
		Vector2(-0.707, -0.707),
		Vector2.UP,
		Vector2(0.707, -0.707),
	]
	for ring_index in range(1, 5):
		var ring_radius := search_radius_pixels * (float(ring_index) / 4.0)
		for direction in sample_directions:
			var candidate: Vector2 = target_position + direction * ring_radius
			if _is_walkable_position_pixels(candidate, half_size_pixels):
				return {"success": true, "position": candidate}
	if fallback_position != Vector2.ZERO and _is_walkable_position_pixels(fallback_position, half_size_pixels):
		return {"success": false, "position": fallback_position}
	return {"success": false, "position": target_position}


func _spawn_frost_white_wolves() -> void:
	var enemy_scene: PackedScene = load(ENEMY_SCENE_PATH)
	for spawn_definition in _build_frost_white_wolf_spawns():
		var enemy: Node2D = enemy_scene.instantiate()
		enemy.add_to_group("enemy")
		entities_layer.add_child(enemy)
		var spawn_position_meters := Vector2((spawn_definition as Dictionary).get("spawn_position_meters", Vector2.ZERO))
		enemy.setup_enemy(
			FROST_WHITE_WOLF_TEMPLATE,
			self,
			spawn_position_meters,
			METERS_TO_PIXELS,
			str((spawn_definition as Dictionary).get("ai_id", "frost_white_wolf_hunter_001")),
			"enemy"
		)
		enemy.enemy_died.connect(_on_enemy_died)
		enemy_registry[enemy.get_instance_id()] = {
			"node": enemy,
			"health": int(FROST_WHITE_WOLF_TEMPLATE.get("max_health", 1)),
			"half_size_pixels": enemy.get_hitbox_half_size_pixels(),
			"template_id": str(FROST_WHITE_WOLF_TEMPLATE.get("template_id", "")),
			"spawn_id": str((spawn_definition as Dictionary).get("spawn_id", "")),
		}


func _build_frost_white_wolf_spawns() -> Array[Dictionary]:
	return [
		{
			"spawn_id": "wolf_mid_front",
			"ai_id": "frost_white_wolf_hunter_001",
			"spawn_position_meters": CultivationFrostWastesBlockout.get_area_center("burial_slope") + Vector2(-24.0, 14.0),
		},
		{
			"spawn_id": "wolf_mid_back",
			"ai_id": "frost_white_wolf_hunter_001",
			"spawn_position_meters": CultivationFrostWastesBlockout.get_area_center("oath_ruins") + Vector2(-18.0, -12.0),
		},
	]


func _resolve_player_attack(enemy: Node2D, base_damage: float) -> void:
	if battle_result_locked or enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_method("is_alive") or not enemy.is_alive():
		return
	if not _roll_percent(player.get_hit_rate()):
		_show_floating_text(enemy.global_position, "MISS", Color(0.92, 0.92, 0.92, 1.0), 18)
		return
	var final_damage: int = max(int(round(base_damage)), 1)
	var is_critical := _roll_percent(player.get_crit_rate())
	if is_critical:
		final_damage = max(int(round(float(final_damage) * player.get_crit_damage_multiplier())), 1)
	enemy.take_damage(final_damage)
	_update_enemy_registry_health(enemy)
	var damage_text := str(final_damage)
	var damage_color := Color(1.0, 0.92, 0.62, 1.0)
	var font_size := 18
	if is_critical:
		damage_text += "!"
		damage_color = Color(1.0, 0.32, 0.32, 1.0)
		font_size = 22
	_show_floating_text(enemy.global_position, damage_text, damage_color, font_size)


func _resolve_enemy_attack(attacker_name: String, base_damage: int, attack_profile: Dictionary, hit_position: Vector2) -> void:
	if battle_result_locked or not is_player_alive():
		return
	var hit_rate := float(attack_profile.get("hit_rate", 100.0))
	var crit_rate := float(attack_profile.get("crit_rate", 0.0))
	var crit_damage := maxf(float(attack_profile.get("crit_damage", 1.5)), 1.0)
	if not _roll_percent(hit_rate):
		_show_floating_text(hit_position, "MISS", Color(0.92, 0.92, 0.92, 1.0), 18)
		return
	if _roll_percent(player.get_dodge_rate()):
		_show_floating_text(hit_position, "MISS", Color(0.92, 0.92, 0.92, 1.0), 18)
		return
	var final_damage: int = max(base_damage, 1)
	if _roll_percent(player.get_block_rate()):
		final_damage = max(int(round(float(final_damage) * BLOCK_DAMAGE_MULTIPLIER)), 1)
	var is_critical := _roll_percent(crit_rate)
	if is_critical:
		final_damage = max(int(round(float(final_damage) * crit_damage)), 1)
	player.take_damage(final_damage, attacker_name)
	var damage_text := str(final_damage)
	var damage_color := Color(1.0, 0.95, 0.95, 1.0)
	var font_size := 18
	if is_critical:
		damage_text += "!"
		damage_color = Color(1.0, 0.32, 0.32, 1.0)
		font_size = 22
	_show_floating_text(hit_position, damage_text, damage_color, font_size)


func _update_enemy_registry_health(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var enemy_id := enemy.get_instance_id()
	if enemy_registry.has(enemy_id):
		enemy_registry[enemy_id]["health"] = enemy.get_enemy_data()["health"]


func _roll_percent(chance_percent: float) -> bool:
	var clamped_chance := clampf(chance_percent, 0.0, 100.0)
	return randf() * 100.0 < clamped_chance


func _show_floating_text(world_position: Vector2, text: String, color: Color, font_size: int = 18) -> void:
	if effect_layer == null:
		return
	var floating_label := Label.new()
	floating_label.text = text
	floating_label.position = world_position + Vector2(-18.0, -28.0)
	floating_label.modulate = color
	floating_label.z_as_relative = false
	floating_label.z_index = 40
	floating_label.add_theme_font_size_override("font_size", font_size)
	effect_layer.add_child(floating_label)
	var tween := create_tween()
	tween.tween_property(floating_label, "position", floating_label.position + Vector2(0.0, -18.0), FLOATING_TEXT_LIFETIME)
	tween.parallel().tween_property(floating_label, "modulate:a", 0.0, FLOATING_TEXT_LIFETIME)
	tween.tween_callback(func() -> void:
		if is_instance_valid(floating_label):
			floating_label.queue_free()
	)


func _on_enemy_died(enemy: Node2D) -> void:
	enemy_registry.erase(enemy.get_instance_id())
	enemy.queue_free()


func _rectangle_overlaps_circle(rect_center: Vector2, rect_half_size: Vector2, circle_center: Vector2, radius_pixels: float) -> bool:
	var closest_point := Vector2(
		clampf(circle_center.x, rect_center.x - rect_half_size.x, rect_center.x + rect_half_size.x),
		clampf(circle_center.y, rect_center.y - rect_half_size.y, rect_center.y + rect_half_size.y)
	)
	return closest_point.distance_to(circle_center) <= radius_pixels


func _rectangle_overlaps_sector(rect_center: Vector2, rect_half_size: Vector2, attack_center: Vector2, direction: Vector2, radius_pixels: float, arc_degrees: float) -> bool:
	var normalized_direction := direction.normalized()
	if normalized_direction == Vector2.ZERO:
		normalized_direction = Vector2.RIGHT
	var cosine_threshold := cos(deg_to_rad(arc_degrees * 0.5))
	for point in _get_rectangle_candidate_points(rect_center, rect_half_size):
		var offset: Vector2 = point - attack_center
		if offset.length() > radius_pixels:
			continue
		var candidate_direction := normalized_direction
		if offset != Vector2.ZERO:
			candidate_direction = offset.normalized()
		if normalized_direction.dot(candidate_direction) >= cosine_threshold:
			return true
	if not _rectangle_overlaps_circle(rect_center, rect_half_size, attack_center, radius_pixels):
		return false
	var closest_point := Vector2(
		clampf(attack_center.x, rect_center.x - rect_half_size.x, rect_center.x + rect_half_size.x),
		clampf(attack_center.y, rect_center.y - rect_half_size.y, rect_center.y + rect_half_size.y)
	)
	var closest_offset := closest_point - attack_center
	if closest_offset == Vector2.ZERO:
		return true
	return normalized_direction.dot(closest_offset.normalized()) >= cosine_threshold


func _get_rectangle_candidate_points(rect_center: Vector2, rect_half_size: Vector2) -> Array:
	return [
		rect_center,
		Vector2(rect_center.x - rect_half_size.x, rect_center.y - rect_half_size.y),
		Vector2(rect_center.x + rect_half_size.x, rect_center.y - rect_half_size.y),
		Vector2(rect_center.x - rect_half_size.x, rect_center.y + rect_half_size.y),
		Vector2(rect_center.x + rect_half_size.x, rect_center.y + rect_half_size.y),
		Vector2(rect_center.x, rect_center.y - rect_half_size.y),
		Vector2(rect_center.x, rect_center.y + rect_half_size.y),
		Vector2(rect_center.x - rect_half_size.x, rect_center.y),
		Vector2(rect_center.x + rect_half_size.x, rect_center.y),
	]
