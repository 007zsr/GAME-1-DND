extends "res://game/scripts/gameplay_scene_base.gd"

const GameLayers = preload("res://game/scripts/game_layers.gd")
const METERS_TO_PIXELS := 16.0
const WORLD_BOUNDS_METERS := Rect2(Vector2(8.0, 8.0), Vector2(76.0, 44.0))
const GATE_SCENE_PATH := "res://game/scenes/scene_gate_interactable.tscn"

var interactable_layer: Node2D
var return_gate: Node2D

@onready var ground: ColorRect = $Ground
@onready var grid_overlay: Polygon2D = $GridOverlay
@onready var room_floor_layer: Node2D = $WorldLayers/RoomFloorLayer
@onready var entities_layer: Node2D = $WorldLayers/Entities
@onready var effect_layer: Node2D = $WorldLayers/EffectLayer
@onready var location_info_label: Label = %LocationInfoLabel
@onready var player_info_label: Label = %PlayerInfoLabel


func _ready() -> void:
	_configure_display_layers()
	player.configure_world(METERS_TO_PIXELS)
	player.position = Vector2(18.0, 30.0) * METERS_TO_PIXELS
	_build_world_layout()
	setup_gameplay_scene_runtime()
	_ensure_interactable_layer()
	_spawn_interactables()
	_mark_world_entered()
	_update_ui()
	_update_standard_skill_ui()


func _process(_delta: float) -> void:
	_update_ui()
	_update_standard_skill_ui()


func _exit_tree() -> void:
	teardown_gameplay_scene_runtime()


func get_return_gate() -> Node2D:
	return return_gate


func handle_dialogue_action(_action_type: String, _payload: Dictionary, _manager: Node) -> bool:
	return false


func handle_gate_interaction(gate_id: String, _gate_node: Node = null) -> bool:
	match gate_id:
		"return_to_god_space":
			return return_to_god_space()
		_:
			return false


func return_to_god_space() -> bool:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null:
		return false
	var target_scene_path := "res://game/scenes/god_space_hub.tscn"
	if game_state.has_method("set_current_world_id"):
		game_state.set_current_world_id("")
	if game_state.has_method("get_god_space_scene_path"):
		target_scene_path = str(game_state.get_god_space_scene_path())
	get_tree().paused = false
	if player != null and player.has_method("unlock_gameplay"):
		player.unlock_gameplay()
	get_tree().change_scene_to_file(target_scene_path)
	return true


func resolve_world_movement(current_position: Vector2, motion: Vector2, half_size_pixels: Vector2) -> Vector2:
	var proposed_position := current_position + motion
	var min_position := WORLD_BOUNDS_METERS.position * METERS_TO_PIXELS + half_size_pixels
	var max_position := (WORLD_BOUNDS_METERS.position + WORLD_BOUNDS_METERS.size) * METERS_TO_PIXELS - half_size_pixels
	return Vector2(
		clampf(proposed_position.x, min_position.x, max_position.x),
		clampf(proposed_position.y, min_position.y, max_position.y)
	)


func _build_world_layout() -> void:
	for child in room_floor_layer.get_children():
		child.queue_free()
	var world_rect := WORLD_BOUNDS_METERS
	ground.color = Color(0.05, 0.10, 0.08, 1.0)
	ground.offset_left = world_rect.position.x * METERS_TO_PIXELS
	ground.offset_top = world_rect.position.y * METERS_TO_PIXELS
	ground.offset_right = (world_rect.position.x + world_rect.size.x) * METERS_TO_PIXELS
	ground.offset_bottom = (world_rect.position.y + world_rect.size.y) * METERS_TO_PIXELS
	grid_overlay.color = Color(0.92, 1.0, 0.92, 0.03)
	grid_overlay.polygon = PackedVector2Array([
		world_rect.position * METERS_TO_PIXELS,
		Vector2(world_rect.position.x + world_rect.size.x, world_rect.position.y) * METERS_TO_PIXELS,
		(world_rect.position + world_rect.size) * METERS_TO_PIXELS,
		Vector2(world_rect.position.x, world_rect.position.y + world_rect.size.y) * METERS_TO_PIXELS,
	])

	_add_floor_rect(Rect2(Vector2(14.0, 14.0), Vector2(56.0, 28.0)), Color(0.11, 0.20, 0.14, 1.0))
	_add_floor_rect(Rect2(Vector2(22.0, 18.0), Vector2(20.0, 10.0)), Color(0.18, 0.30, 0.20, 1.0))
	_add_floor_rect(Rect2(Vector2(48.0, 22.0), Vector2(10.0, 8.0)), Color(0.26, 0.38, 0.24, 1.0))
	_add_outline(Rect2(Vector2(14.0, 14.0), Vector2(56.0, 28.0)), Color(0.84, 0.96, 0.84, 0.5))
	_add_outline(Rect2(Vector2(22.0, 18.0), Vector2(20.0, 10.0)), Color(0.68, 0.92, 0.72, 0.42))


func _add_floor_rect(rect_meters: Rect2, color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.position = rect_meters.position * METERS_TO_PIXELS
	polygon.color = color
	polygon.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(rect_meters.size.x, 0.0) * METERS_TO_PIXELS,
		rect_meters.size * METERS_TO_PIXELS,
		Vector2(0.0, rect_meters.size.y) * METERS_TO_PIXELS,
	])
	room_floor_layer.add_child(polygon)


func _add_outline(rect_meters: Rect2, color: Color) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = color
	line.position = rect_meters.position * METERS_TO_PIXELS
	line.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(rect_meters.size.x, 0.0) * METERS_TO_PIXELS,
		rect_meters.size * METERS_TO_PIXELS,
		Vector2(0.0, rect_meters.size.y) * METERS_TO_PIXELS,
		Vector2.ZERO,
	])
	room_floor_layer.add_child(line)


func _configure_display_layers() -> void:
	ground.z_index = GameLayers.Z_BACKGROUND
	grid_overlay.z_index = GameLayers.Z_BACKGROUND + 1
	room_floor_layer.z_index = GameLayers.Z_ROOM_FLOOR
	entities_layer.z_index = GameLayers.Z_ENTITIES
	effect_layer.z_index = GameLayers.Z_EFFECTS
	canvas_layer.layer = GameLayers.Z_UI


func _get_skill_hover_context_extras() -> Dictionary:
	return {
		"source_context": "cultivation_trial_world",
		"scene_id": "cultivation_trial_world",
	}


func _ensure_interactable_layer() -> void:
	interactable_layer = Node2D.new()
	interactable_layer.name = "Interactables"
	entities_layer.add_child(interactable_layer)


func _spawn_interactables() -> void:
	var gate_scene: PackedScene = load(GATE_SCENE_PATH)
	return_gate = gate_scene.instantiate()
	interactable_layer.add_child(return_gate)
	return_gate.configure(self, player, Vector2(64.0, 28.0), METERS_TO_PIXELS, "return_to_god_space", "返回主神空间", "按 E 返回主神空间")


func _mark_world_entered() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null:
		return
	if game_state.has_method("set_current_world_id"):
		game_state.set_current_world_id("cultivation_world")


func _update_ui() -> void:
	location_info_label.text = "修仙世界  |  当前阶段：正式测试入口占位场景"
	player_info_label.text = "玩家坐标 %.1f, %.1f  |  网格 %.0f, %.0f  |  HP %d/%d" % [
		player.position.x / METERS_TO_PIXELS,
		player.position.y / METERS_TO_PIXELS,
		player.get_grid_position().x,
		player.get_grid_position().y,
		player.get_current_health(),
		player.get_max_health(),
	]


func _update_skill_ui() -> void:
	var skill_id: String = player.get_equipped_skill_id(0) if player.has_method("get_equipped_skill_id") else ""
	if skill_id.is_empty():
		skill_label.text = "技能栏：未配置\n冷却：--\n请在统合菜单的技能页中配置"
		return
	var skill_data: Dictionary = player.get_skill_data(skill_id) if player.has_method("get_skill_data") else {}
	var cooldown_remaining: float = float(skill_data.get("cooldown_remaining", 0.0))
	var cooldown_status := "就绪"
	if cooldown_remaining > 0.01:
		cooldown_status = "%.2f秒" % cooldown_remaining
	var trigger_label := "自动触发" if str(skill_data.get("skill_type", "active")) == "passive" else "主动触发"
	skill_label.text = "技能栏：%s\n冷却：%s\n%s" % [str(skill_data.get("display_name", skill_id)), cooldown_status, trigger_label]


func _on_skill_bar_panel_mouse_entered() -> void:
	var skill_id: String = player.get_equipped_skill_id(0) if player.has_method("get_equipped_skill_id") else ""
	if hover_detail_manager != null and not skill_id.is_empty():
		hover_detail_manager.request_hover(
			"skill_entry",
			skill_id,
			skill_bar_panel,
			Callable(self, "_build_skill_bar_hover_context").bind(skill_id),
			"mouse"
		)


func _on_skill_bar_panel_mouse_exited() -> void:
	var skill_id: String = player.get_equipped_skill_id(0) if player.has_method("get_equipped_skill_id") else ""
	if hover_detail_manager != null and not skill_id.is_empty():
		hover_detail_manager.clear_hover(skill_id)


func _build_skill_bar_hover_context(skill_id: String) -> Dictionary:
	return {
		"player": player,
		"skill_id": skill_id,
		"source_context": "cultivation_trial_world",
		"scene_id": "cultivation_trial_world",
	}


func _set_subtree_process_mode(root: Node, mode: int) -> void:
	root.process_mode = mode
	for child in root.get_children():
		_set_subtree_process_mode(child, mode)
