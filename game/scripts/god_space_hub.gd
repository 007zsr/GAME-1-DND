extends "res://game/scripts/gameplay_scene_base.gd"

const GameLayers = preload("res://game/scripts/game_layers.gd")
const METERS_TO_PIXELS := 16.0
const HUB_WALKABLE_BOUNDS_METERS := Rect2(Vector2(6.0, 6.0), Vector2(72.0, 48.0))
const ENEMY_SCENE_PATH := "res://game/scenes/enemy_actor.tscn"
const NPC_DIALOGUE_SCENE_PATH := "res://game/scenes/npc_dialogue_interactor.tscn"
const GATE_SCENE_PATH := "res://game/scenes/scene_gate_interactable.tscn"
const WORLD_SELECTION_PANEL_SCENE_PATH := "res://game/scenes/world_selection_panel.tscn"
const GOD_SPACE_GODDESS_DIALOGUE_ID := "god_space_goddess_intro"

const GODDESS_ACTOR_CONFIG := {
	"actor_kind": "npc",
	"name": "复活女神",
	"role": "npc",
	"max_health": 999,
	"move_speed": 0.0,
	"attack_range": 0.0,
	"attack_cooldown": 0.0,
	"windup": 0.0,
	"recovery": 0.0,
	"size_meters": Vector2(0.7, 1.1),
	"display_color": Color(0.92, 0.86, 0.60, 1.0),
	"label_font_size": 10,
	"hp_bar_style": "none",
	"show_name": true,
	"show_name_label": true,
	"show_health_label": false,
}

var world_selection_panel: PanelContainer
var interactable_layer: Node2D
var goddess_actor: Node2D
var world_gate: Node2D

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
	_build_hub_layout()
	setup_gameplay_scene_runtime()
	_setup_world_selection_panel()
	_ensure_interactable_layer()
	_spawn_interactables()
	_mark_hub_entered()
	_update_ui()
	_update_standard_skill_ui()


func _process(_delta: float) -> void:
	_update_ui()
	_update_standard_skill_ui()


func _exit_tree() -> void:
	teardown_gameplay_scene_runtime()


func get_world_gate() -> Node2D:
	return world_gate


func open_dialogue_for_interaction(npc_node: Node, dialogue_id: String) -> bool:
	var dialogue_manager: Node = get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null or not dialogue_manager.has_method("start_dialogue"):
		return false
	return bool(dialogue_manager.start_dialogue(dialogue_id, npc_node, {}))


func handle_dialogue_action(action_type: String, payload: Dictionary, _manager: Node) -> bool:
	match action_type:
		"call_hook":
			if str(payload.get("hook_id", "")) == "open_world_selection":
				return open_world_selection()
			return true
		_:
			return false


func handle_gate_interaction(gate_id: String, _gate_node: Node = null) -> bool:
	match gate_id:
		"world_selection_gate":
			return open_world_selection()
		_:
			return false


func open_world_selection() -> bool:
	if world_selection_panel == null:
		return false
	if not request_open_overlay(world_selection_panel):
		return false
	world_selection_panel.open_panel()
	return true


func handle_world_selection(entry_id: String) -> bool:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null:
		return false
	var can_enter := false
	if game_state.has_method("can_enter_world_selection_entry"):
		can_enter = game_state.can_enter_world_selection_entry(entry_id)
	elif game_state.has_method("can_enter_world"):
		can_enter = game_state.can_enter_world(entry_id)
	if not can_enter:
		return false
	if world_selection_panel != null and world_selection_panel.has_method("close_panel"):
		world_selection_panel.close_panel()
	var target_scene_path := ""
	if game_state.has_method("begin_world_selection_entry"):
		target_scene_path = str(game_state.begin_world_selection_entry(entry_id))
	elif game_state.has_method("begin_world_exploration"):
		target_scene_path = str(game_state.begin_world_exploration(entry_id))
	else:
		target_scene_path = str(game_state.get_world_scene_path(entry_id))
	if target_scene_path.is_empty():
		return false
	if not game_state.has_method("begin_world_selection_entry") and not game_state.has_method("begin_world_exploration") and game_state.has_method("set_current_world_id"):
		game_state.set_current_world_id(entry_id)
	get_tree().paused = false
	if player != null and player.has_method("unlock_gameplay"):
		player.unlock_gameplay()
	get_tree().change_scene_to_file(target_scene_path)
	return true


func resolve_world_movement(current_position: Vector2, motion: Vector2, half_size_pixels: Vector2) -> Vector2:
	var proposed_position := current_position + motion
	var min_position := HUB_WALKABLE_BOUNDS_METERS.position * METERS_TO_PIXELS + half_size_pixels
	var max_position := (HUB_WALKABLE_BOUNDS_METERS.position + HUB_WALKABLE_BOUNDS_METERS.size) * METERS_TO_PIXELS - half_size_pixels
	return Vector2(
		clampf(proposed_position.x, min_position.x, max_position.x),
		clampf(proposed_position.y, min_position.y, max_position.y)
	)


func _build_hub_layout() -> void:
	for child in room_floor_layer.get_children():
		child.queue_free()

	var world_rect := HUB_WALKABLE_BOUNDS_METERS
	ground.color = Color(0.05, 0.08, 0.12, 1.0)
	ground.offset_left = world_rect.position.x * METERS_TO_PIXELS
	ground.offset_top = world_rect.position.y * METERS_TO_PIXELS
	ground.offset_right = (world_rect.position.x + world_rect.size.x) * METERS_TO_PIXELS
	ground.offset_bottom = (world_rect.position.y + world_rect.size.y) * METERS_TO_PIXELS
	grid_overlay.color = Color(0.92, 0.96, 1.0, 0.035)
	grid_overlay.polygon = PackedVector2Array([
		world_rect.position * METERS_TO_PIXELS,
		Vector2(world_rect.position.x + world_rect.size.x, world_rect.position.y) * METERS_TO_PIXELS,
		(world_rect.position + world_rect.size) * METERS_TO_PIXELS,
		Vector2(world_rect.position.x, world_rect.position.y + world_rect.size.y) * METERS_TO_PIXELS,
	])

	_add_floor_rect(Rect2(Vector2(12.0, 12.0), Vector2(60.0, 36.0)), Color(0.10, 0.16, 0.22, 1.0))
	_add_floor_rect(Rect2(Vector2(28.0, 18.0), Vector2(16.0, 12.0)), Color(0.16, 0.22, 0.30, 1.0))
	_add_floor_rect(Rect2(Vector2(52.0, 20.0), Vector2(12.0, 8.0)), Color(0.20, 0.26, 0.34, 1.0))
	_add_outline(Rect2(Vector2(12.0, 12.0), Vector2(60.0, 36.0)), Color(0.86, 0.90, 0.98, 0.55))
	_add_outline(Rect2(Vector2(28.0, 18.0), Vector2(16.0, 12.0)), Color(0.92, 0.84, 0.52, 0.45))
	_add_outline(Rect2(Vector2(52.0, 20.0), Vector2(12.0, 8.0)), Color(0.72, 0.82, 0.98, 0.40))


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
		"source_context": "god_space_hub",
		"scene_id": "god_space_hub",
	}


func _setup_world_selection_panel() -> void:
	var panel_scene: PackedScene = load(WORLD_SELECTION_PANEL_SCENE_PATH)
	world_selection_panel = panel_scene.instantiate()
	world_selection_panel.name = "WorldSelectionPanel"
	canvas_layer.add_child(world_selection_panel)
	_set_subtree_process_mode(world_selection_panel, Node.PROCESS_MODE_ALWAYS)
	world_selection_panel.configure(self)


func _ensure_interactable_layer() -> void:
	interactable_layer = Node2D.new()
	interactable_layer.name = "Interactables"
	entities_layer.add_child(interactable_layer)


func _spawn_interactables() -> void:
	var actor_scene: PackedScene = load(ENEMY_SCENE_PATH)
	var npc_scene: PackedScene = load(NPC_DIALOGUE_SCENE_PATH)
	var gate_scene: PackedScene = load(GATE_SCENE_PATH)

	goddess_actor = actor_scene.instantiate()
	interactable_layer.add_child(goddess_actor)
	goddess_actor.setup_actor(GODDESS_ACTOR_CONFIG, self, Vector2(24.0, 28.0), METERS_TO_PIXELS, "npc_guard_friendly_idle", "friendly")

	var goddess_dialogue: Node2D = npc_scene.instantiate()
	goddess_dialogue.name = "DialogueInteractor"
	goddess_actor.add_child(goddess_dialogue)
	goddess_dialogue.configure_on_host(self, player, goddess_actor, METERS_TO_PIXELS, GOD_SPACE_GODDESS_DIALOGUE_ID, "复活女神")

	world_gate = gate_scene.instantiate()
	interactable_layer.add_child(world_gate)
	world_gate.configure(self, player, Vector2(60.0, 28.0), METERS_TO_PIXELS, "world_selection_gate", "世界选择出口", "按 E 选择目标世界")


func _mark_hub_entered() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null:
		return
	if game_state.has_method("clear_active_scene_entry_context"):
		game_state.clear_active_scene_entry_context()
	if game_state.has_method("mark_entered_god_space"):
		game_state.mark_entered_god_space()
	if game_state.has_method("set_current_world_id"):
		game_state.set_current_world_id("")


func _update_ui() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	var current_character: Dictionary = {}
	var current_test_world_name := "修仙世界"
	if game_state != null and "current_character" in game_state:
		current_character = game_state.current_character
	if game_state != null and game_state.has_method("get_world_display_name"):
		current_test_world_name = str(game_state.get_world_display_name(game_state.get_current_test_world_id()))
	location_info_label.text = "主神空间  |  当前职业：%s  |  正式测试入口：%s" % [
		str(current_character.get("class_name", "战士")),
		current_test_world_name,
	]
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
		"source_context": "god_space_hub",
		"scene_id": "god_space_hub",
	}


func _set_subtree_process_mode(root: Node, mode: int) -> void:
	root.process_mode = mode
	for child in root.get_children():
		_set_subtree_process_mode(child, mode)
