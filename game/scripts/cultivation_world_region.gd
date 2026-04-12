extends "res://game/scripts/gameplay_scene_base.gd"

const CultivationWorldStructure = preload("res://game/scripts/cultivation_world_structure.gd")
const GameLayers = preload("res://game/scripts/game_layers.gd")
const GATE_SCENE_PATH := "res://game/scenes/scene_gate_interactable.tscn"
const METERS_TO_PIXELS := 16.0
const WORLD_BOUNDS_METERS := Rect2(Vector2(8.0, 8.0), Vector2(76.0, 44.0))

var interactable_layer: Node2D
var return_gate: Node2D
var transition_gates: Array[Node2D] = []
var battle_result_locked: bool = false
var current_result_type: String = ""
var death_panel: PanelContainer
var death_summary_label: Label
var death_return_button: Button
var region_id: String = ""
var region_definition: Dictionary = {}

@onready var ground: ColorRect = $Ground
@onready var grid_overlay: Polygon2D = $GridOverlay
@onready var room_floor_layer: Node2D = $WorldLayers/RoomFloorLayer
@onready var entities_layer: Node2D = $WorldLayers/Entities
@onready var effect_layer: Node2D = $WorldLayers/EffectLayer
@onready var location_info_label: Label = %LocationInfoLabel
@onready var player_info_label: Label = %PlayerInfoLabel


func _ready() -> void:
	_resolve_region_definition()
	_configure_display_layers()
	player.configure_world(METERS_TO_PIXELS)
	player.position = Vector2(18.0, 30.0) * METERS_TO_PIXELS
	_build_world_layout()
	setup_gameplay_scene_runtime()
	_setup_result_panel()
	_ensure_interactable_layer()
	_sync_region_runtime_state()
	_spawn_interactables()
	_connect_player_signals()
	_update_ui()
	_update_standard_skill_ui()


func _process(_delta: float) -> void:
	_update_ui()
	if not battle_result_locked:
		_update_standard_skill_ui()


func _exit_tree() -> void:
	if player != null and player.death_requested.is_connected(request_player_death):
		player.death_requested.disconnect(request_player_death)
	teardown_gameplay_scene_runtime()


func get_return_gate() -> Node2D:
	return return_gate


func get_region_id() -> String:
	return region_id


func get_region_definition_snapshot() -> Dictionary:
	return region_definition.duplicate(true)


func get_world_bounds_meters() -> Rect2:
	return WORLD_BOUNDS_METERS


func get_player_global_position() -> Vector2:
	return player.global_position if player != null else Vector2.ZERO


func is_player_alive() -> bool:
	return player != null and player.has_method("is_alive") and player.is_alive()


func get_player_facing_direction() -> Vector2:
	if player != null and player.has_method("get_facing_direction"):
		var facing: Vector2 = player.get_facing_direction()
		if facing != Vector2.ZERO:
			return facing
	return Vector2.RIGHT


func get_transition_gate_targets() -> Array[String]:
	var results: Array[String] = []
	for gate in transition_gates:
		if gate == null or not is_instance_valid(gate):
			continue
		if gate.has_method("get_gate_id"):
			results.append(str(gate.get_gate_id()).trim_prefix("travel:"))
	return results


func is_result_showing() -> bool:
	return battle_result_locked


func handle_gate_interaction(gate_id: String, _gate_node: Node = null) -> bool:
	if gate_id == "return_to_god_space":
		return return_to_god_space("manual_return")
	if gate_id.begins_with("travel:"):
		return travel_to_region(gate_id.trim_prefix("travel:"))
	return false


func return_to_god_space(exit_reason: String = "manual_return") -> bool:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null:
		return false
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
	var proposed_position := current_position + motion
	var world_bounds := get_world_bounds_meters()
	var min_position := world_bounds.position * METERS_TO_PIXELS + half_size_pixels
	var max_position := (world_bounds.position + world_bounds.size) * METERS_TO_PIXELS - half_size_pixels
	return Vector2(
		clampf(proposed_position.x, min_position.x, max_position.x),
		clampf(proposed_position.y, min_position.y, max_position.y)
	)


func request_player_death() -> void:
	if battle_result_locked:
		return
	_show_death_result()


func complete_death_return() -> bool:
	return _complete_death_return()


func travel_to_region(target_region_id: String) -> bool:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null or not game_state.has_method("travel_in_cultivation_world"):
		return false
	var target_scene_path := str(game_state.travel_in_cultivation_world(target_region_id))
	if target_scene_path.is_empty():
		return false
	get_tree().paused = false
	if player != null and player.has_method("unlock_gameplay"):
		player.unlock_gameplay()
	get_tree().change_scene_to_file(target_scene_path)
	return true


func _resolve_region_definition() -> void:
	region_id = CultivationWorldStructure.get_region_id_by_scene_path(str(scene_file_path))
	if region_id.is_empty():
		region_id = CultivationWorldStructure.get_default_start_region_id()
	region_definition = CultivationWorldStructure.get_region_definition(region_id)


func _connect_player_signals() -> void:
	if player == null:
		return
	if not player.death_requested.is_connected(request_player_death):
		player.death_requested.connect(request_player_death)


func _ensure_interactable_layer() -> void:
	interactable_layer = Node2D.new()
	interactable_layer.name = "Interactables"
	entities_layer.add_child(interactable_layer)


func _setup_result_panel() -> void:
	death_panel = PanelContainer.new()
	death_panel.name = "DeathPanel"
	death_panel.visible = false
	death_panel.offset_left = 280.0
	death_panel.offset_top = 120.0
	death_panel.offset_right = 860.0
	death_panel.offset_bottom = 480.0
	canvas_layer.add_child(death_panel)
	_set_subtree_process_mode(death_panel, Node.PROCESS_MODE_ALWAYS)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	death_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "\u63a2\u7d22\u5931\u8d25"
	title.add_theme_font_size_override("font_size", 28)
	stack.add_child(title)

	death_summary_label = Label.new()
	death_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(death_summary_label)

	death_return_button = Button.new()
	death_return_button.text = "\u8fd4\u56de\u4e3b\u795e\u7a7a\u95f4\u590d\u6d3b"
	death_return_button.custom_minimum_size = Vector2(220.0, 44.0)
	death_return_button.pressed.connect(_on_death_return_button_pressed)
	stack.add_child(death_return_button)


func _spawn_interactables() -> void:
	for gate in transition_gates:
		if gate != null and is_instance_valid(gate):
			gate.queue_free()
	transition_gates.clear()
	if return_gate != null and is_instance_valid(return_gate):
		return_gate.queue_free()

	var gate_scene: PackedScene = load(GATE_SCENE_PATH)
	var available_entries: Array[Dictionary] = _get_available_region_entries()
	var transition_positions: Array[Vector2] = _build_transition_gate_positions(available_entries.size())
	for index in range(available_entries.size()):
		var entry: Dictionary = available_entries[index]
		var gate: Node2D = gate_scene.instantiate()
		interactable_layer.add_child(gate)
		var target_region_id := str(entry.get("region_id", ""))
		var target_name := str(entry.get("display_name", target_region_id))
		gate.configure(
			self,
			player,
			transition_positions[index],
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
		Vector2(16.0, 16.0),
		METERS_TO_PIXELS,
		"return_to_god_space",
		"\u8fd4\u56de\u4e3b\u795e\u7a7a\u95f4",
		"\u6309 E \u7ed3\u675f\u672c\u8f6e\u63a2\u7d22"
	)


func _build_transition_gate_positions(gate_count: int) -> Array[Vector2]:
	if gate_count <= 0:
		return []
	if gate_count == 1:
		return [Vector2(66.0, 28.0)]
	if gate_count == 2:
		return [Vector2(62.0, 20.0), Vector2(62.0, 36.0)]
	var results: Array[Vector2] = []
	for index in range(gate_count):
		results.append(Vector2(60.0, 18.0 + float(index) * 8.0))
	return results


func _get_available_region_entries() -> Array[Dictionary]:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("get_available_cultivation_region_entries"):
		return game_state.get_available_cultivation_region_entries()
	var results: Array[Dictionary] = []
	for target_region_id in CultivationWorldStructure.get_connected_region_ids(region_id):
		results.append(CultivationWorldStructure.get_region_definition(target_region_id))
	return results


func _sync_region_runtime_state() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null:
		return
	if game_state.has_method("sync_cultivation_world_region_context"):
		game_state.sync_cultivation_world_region_context(region_id)


func _show_death_result() -> void:
	_begin_battle_result("death")
	var game_state: Node = get_node_or_null("/root/GameState")
	var exploration_state: Dictionary = {}
	if game_state != null and game_state.has_method("get_world_exploration_state"):
		exploration_state = game_state.get_world_exploration_state()
	var summary: Dictionary = player.get_combat_summary()
	death_summary_label.text = "\u5f53\u524d\u533a\u57df\uff1a%s\n\u672c\u8f6e\u8d77\u70b9\uff1a%s\n\u5f53\u524d\u751f\u547d\uff1a%d / %d\n\u65a9\u51fb\u4f24\u5bb3\uff1a%.1f\n\u6b7b\u4ea1\u540e\u672c\u8f6e\u63a2\u7d22\u7ed3\u675f\uff0c\u5c06\u8fd4\u56de\u4e3b\u795e\u7a7a\u95f4\u590d\u6d3b\u3002" % [
		str(region_definition.get("display_name", region_id)),
		CultivationWorldStructure.get_region_display_name(str(exploration_state.get("start_region_id", ""))),
		int(summary.get("current_hp", 0)),
		int(summary.get("max_hp", 0)),
		float(summary.get("slash_damage", 0.0)),
	]
	death_panel.visible = true


func _begin_battle_result(result_type: String) -> void:
	if battle_result_locked:
		return
	var dialogue_manager: Node = get_node_or_null("/root/DialogueManager")
	if dialogue_manager != null and dialogue_manager.has_method("close_dialogue"):
		dialogue_manager.close_dialogue("battle_result")
	battle_result_locked = true
	current_result_type = result_type
	if player != null and player.has_method("lock_gameplay"):
		player.lock_gameplay()
	if hover_detail_manager != null:
		hover_detail_manager.hide_immediately()
	get_tree().paused = true


func _complete_death_return() -> bool:
	return return_to_god_space("death")


func _on_death_return_button_pressed() -> void:
	_complete_death_return()


func _build_world_layout() -> void:
	for child in room_floor_layer.get_children():
		child.queue_free()

	var palette: Dictionary = _get_region_palette()
	var world_bounds: Rect2 = get_world_bounds_meters()
	ground.color = palette["background"]
	grid_overlay.color = palette["grid"]
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

	_add_floor_rect(Rect2(Vector2(14.0, 14.0), Vector2(56.0, 28.0)), palette["main_floor"])
	_add_floor_rect(Rect2(Vector2(24.0, 18.0), Vector2(16.0, 10.0)), palette["accent_floor"])
	_add_floor_rect(Rect2(Vector2(48.0, 24.0), Vector2(14.0, 10.0)), palette["accent_floor_dark"])
	_add_outline(Rect2(Vector2(14.0, 14.0), Vector2(56.0, 28.0)), palette["outline"])
	_add_outline(Rect2(Vector2(24.0, 18.0), Vector2(16.0, 10.0)), palette["outline_soft"])


func _get_region_palette() -> Dictionary:
	var region_type := str(region_definition.get("region_type", ""))
	match region_type:
		CultivationWorldStructure.REGION_TYPE_EDGE_REGION:
			return {
				"background": Color(0.06, 0.11, 0.08, 1.0),
				"grid": Color(0.86, 0.98, 0.88, 0.04),
				"main_floor": Color(0.12, 0.24, 0.16, 1.0),
				"accent_floor": Color(0.20, 0.34, 0.24, 1.0),
				"accent_floor_dark": Color(0.16, 0.28, 0.20, 1.0),
				"outline": Color(0.84, 0.96, 0.84, 0.56),
				"outline_soft": Color(0.68, 0.92, 0.72, 0.44),
			}
		CultivationWorldStructure.REGION_TYPE_CENTER_CORE:
			return {
				"background": Color(0.10, 0.08, 0.05, 1.0),
				"grid": Color(1.0, 0.96, 0.86, 0.04),
				"main_floor": Color(0.26, 0.20, 0.12, 1.0),
				"accent_floor": Color(0.34, 0.26, 0.16, 1.0),
				"accent_floor_dark": Color(0.30, 0.22, 0.14, 1.0),
				"outline": Color(0.98, 0.88, 0.62, 0.60),
				"outline_soft": Color(0.92, 0.78, 0.52, 0.42),
			}
		_:
			return {
				"background": Color(0.05, 0.10, 0.08, 1.0),
				"grid": Color(0.92, 1.0, 0.92, 0.03),
				"main_floor": Color(0.11, 0.20, 0.14, 1.0),
				"accent_floor": Color(0.18, 0.30, 0.20, 1.0),
				"accent_floor_dark": Color(0.26, 0.38, 0.24, 1.0),
				"outline": Color(0.84, 0.96, 0.84, 0.50),
				"outline_soft": Color(0.68, 0.92, 0.72, 0.42),
			}


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
		"source_context": "cultivation_world_region",
		"scene_id": region_id,
		"world_id": CultivationWorldStructure.get_world_id(),
	}


func _update_ui() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	var exploration_state: Dictionary = {}
	if game_state != null and game_state.has_method("get_world_exploration_state"):
		exploration_state = game_state.get_world_exploration_state()

	var next_region_names: Array[String] = []
	for entry in _get_available_region_entries():
		next_region_names.append(str((entry as Dictionary).get("display_name", "")))
	var next_region_text := "\u5f53\u524d\u5df2\u5230\u7ec8\u70b9\u5c42"
	if not next_region_names.is_empty():
		next_region_text = ", ".join(next_region_names)

	location_info_label.text = "\u4fee\u4ed9\u4e16\u754c  |  \u5f53\u524d\u533a\u57df\uff1a%s  |  \u533a\u57df\u7c7b\u578b\uff1a%s  |  \u4e0b\u4e00\u6b65\uff1a%s" % [
		str(region_definition.get("display_name", region_id)),
		_format_region_type(str(region_definition.get("region_type", ""))),
		next_region_text,
	]
	player_info_label.text = "\u672c\u8f6e\u8d77\u70b9\uff1a%s  |  \u5f53\u524d\u533a\u57df\uff1a%s  |  \u5df2\u5230\u8fb9\u7f18\uff1a%s  |  \u5df2\u5165\u4e2d\u5dde\uff1a%s  |  HP %d/%d" % [
		CultivationWorldStructure.get_region_display_name(str(exploration_state.get("start_region_id", ""))),
		CultivationWorldStructure.get_region_display_name(str(exploration_state.get("current_region_id", region_id))),
		"\u662f" if bool(exploration_state.get("entered_edge", false)) else "\u5426",
		"\u662f" if bool(exploration_state.get("entered_core", false)) else "\u5426",
		player.get_current_health(),
		player.get_max_health(),
	]


func _format_region_type(region_type: String) -> String:
	match region_type:
		CultivationWorldStructure.REGION_TYPE_CORNER_START:
			return "\u89d2\u843d\u8d77\u59cb\u533a\u57df"
		CultivationWorldStructure.REGION_TYPE_EDGE_REGION:
			return "\u8fb9\u7f18\u63a8\u8fdb\u533a\u57df"
		CultivationWorldStructure.REGION_TYPE_CENTER_CORE:
			return "\u4e2d\u5dde\u6838\u5fc3\u533a\u57df"
		_:
			return region_type
