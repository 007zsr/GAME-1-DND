extends Node2D
class_name GameplaySceneBase

const GameplaySceneContract = preload("res://game/scripts/gameplay_scene_contract.gd")
const PlayerMenuSceneScript = preload("res://game/scripts/player_menu_ui_v2.gd")
const ChestMenuScript = preload("res://game/scripts/chest_menu_ui_v2.gd")
const HoverDetailManagerScript = preload("res://game/scripts/hover_detail_manager.gd")

var hover_detail_manager: Control
var player_menu: PanelContainer
var chest_menu: PanelContainer
var active_overlay_control: Control
var dialogue_context_active: bool = false
var gameplay_scene_self_check_errors: Array[String] = []

@onready var player: Node2D = get_node_or_null("WorldLayers/Entities/Player")
@onready var canvas_layer: CanvasLayer = get_node_or_null("CanvasLayer")
@onready var skill_bar_panel: PanelContainer = get_node_or_null("CanvasLayer/SkillBarPanel")
@onready var skill_label: Label = get_node_or_null("CanvasLayer/SkillBarPanel/SkillBarContent/SkillLabel")


func setup_gameplay_scene_runtime() -> void:
	_setup_skill_ui()
	_setup_hover_detail_manager()
	_setup_player_menu()
	_setup_chest_menu()
	_register_dialogue_scene_adapter()
	call_deferred("_run_gameplay_scene_self_check")


func teardown_gameplay_scene_runtime() -> void:
	var dialogue_manager: Node = get_node_or_null("/root/DialogueManager")
	if dialogue_manager != null and dialogue_manager.has_method("unregister_scene_adapter"):
		dialogue_manager.unregister_scene_adapter(self)


func get_player_node() -> Node2D:
	return player


func get_overlay_root() -> CanvasLayer:
	return canvas_layer


func get_hover_detail_manager() -> Control:
	return hover_detail_manager


func get_gameplay_scene_self_check_errors() -> Array[String]:
	return gameplay_scene_self_check_errors.duplicate()


func get_gameplay_scene_contract_snapshot() -> Dictionary:
	return GameplaySceneContract.build_scene_snapshot(self)


func is_result_showing() -> bool:
	return false


func is_overlay_open() -> bool:
	return active_overlay_control != null and is_instance_valid(active_overlay_control) and (active_overlay_control.visible or dialogue_context_active)


func is_dialogue_active() -> bool:
	return dialogue_context_active


func request_open_overlay(overlay_control: Control) -> bool:
	if overlay_control == null or not is_instance_valid(overlay_control):
		return false
	if not _can_open_overlay(overlay_control):
		return false
	active_overlay_control = overlay_control
	_clear_standard_hover_state()
	if hover_detail_manager != null:
		hover_detail_manager.hide_immediately()
	if _should_pause_tree_for_overlay():
		get_tree().paused = true
	return true


func close_overlay(overlay_control: Control) -> void:
	if overlay_control != active_overlay_control:
		return
	active_overlay_control = null
	if _should_resume_tree_after_overlay_close():
		get_tree().paused = false


func begin_dialogue_context(overlay_control: Control, _context: Dictionary = {}) -> bool:
	if overlay_control == null or not is_instance_valid(overlay_control):
		return false
	if not _can_begin_dialogue_context(overlay_control):
		return false
	active_overlay_control = overlay_control
	dialogue_context_active = true
	_clear_standard_hover_state()
	if hover_detail_manager != null:
		hover_detail_manager.hide_immediately()
	if _should_lock_player_during_dialogue() and player != null and player.has_method("lock_gameplay"):
		player.lock_gameplay()
	return true


func end_dialogue_context(overlay_control: Control, _context: Dictionary = {}) -> void:
	if overlay_control != active_overlay_control:
		return
	dialogue_context_active = false
	active_overlay_control = null
	if hover_detail_manager != null:
		hover_detail_manager.hide_immediately()
	if _should_unlock_player_after_dialogue() and player != null and player.has_method("unlock_gameplay"):
		player.unlock_gameplay()


func handle_dialogue_action(_action_type: String, _payload: Dictionary, _manager: Node) -> bool:
	return false


func handle_gate_interaction(_gate_id: String, _gate_node: Node = null) -> bool:
	return false


func _can_open_overlay(_overlay_control: Control) -> bool:
	return not is_result_showing() and not is_overlay_open()


func _can_begin_dialogue_context(_overlay_control: Control) -> bool:
	return not is_result_showing() and not is_overlay_open()


func _should_pause_tree_for_overlay() -> bool:
	return true


func _should_resume_tree_after_overlay_close() -> bool:
	return true


func _should_lock_player_during_dialogue() -> bool:
	return true


func _should_unlock_player_after_dialogue() -> bool:
	return true


func _clear_standard_hover_state() -> void:
	pass


func _setup_skill_ui() -> void:
	if skill_bar_panel == null:
		return
	skill_bar_panel.custom_minimum_size = Vector2(220.0, 86.0)
	skill_bar_panel.offset_right = skill_bar_panel.offset_left + 220.0
	skill_bar_panel.offset_bottom = skill_bar_panel.offset_top + 86.0
	if not skill_bar_panel.mouse_entered.is_connected(_on_skill_bar_panel_mouse_entered):
		skill_bar_panel.mouse_entered.connect(_on_skill_bar_panel_mouse_entered)
	if not skill_bar_panel.mouse_exited.is_connected(_on_skill_bar_panel_mouse_exited):
		skill_bar_panel.mouse_exited.connect(_on_skill_bar_panel_mouse_exited)


func _update_standard_skill_ui() -> void:
	if skill_label == null or player == null:
		return

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
	var skill_id: String = player.get_equipped_skill_id(0) if player != null and player.has_method("get_equipped_skill_id") else ""
	if hover_detail_manager != null and not skill_id.is_empty():
		hover_detail_manager.request_hover(
			"skill_entry",
			skill_id,
			skill_bar_panel,
			Callable(self, "_build_skill_bar_hover_context").bind(skill_id),
			"mouse"
		)


func _on_skill_bar_panel_mouse_exited() -> void:
	var skill_id: String = player.get_equipped_skill_id(0) if player != null and player.has_method("get_equipped_skill_id") else ""
	if hover_detail_manager != null and not skill_id.is_empty():
		hover_detail_manager.clear_hover(skill_id)


func _build_skill_bar_hover_context(skill_id: String) -> Dictionary:
	var context := {
		"player": player,
		"skill_id": skill_id,
	}
	var extra_context := _get_skill_hover_context_extras()
	for key in extra_context.keys():
		context[key] = extra_context[key]
	return context


func _get_skill_hover_context_extras() -> Dictionary:
	return {}


func _setup_hover_detail_manager() -> void:
	if canvas_layer == null:
		return
	hover_detail_manager = Control.new()
	hover_detail_manager.name = "HoverDetailManager"
	hover_detail_manager.set_script(HoverDetailManagerScript)
	canvas_layer.add_child(hover_detail_manager)


func _setup_player_menu() -> void:
	if canvas_layer == null:
		return
	player_menu = PanelContainer.new()
	player_menu.name = "PlayerMenuOverlay"
	player_menu.set_script(PlayerMenuSceneScript)
	canvas_layer.add_child(player_menu)
	_set_subtree_process_mode(player_menu, Node.PROCESS_MODE_ALWAYS)
	player_menu.configure(player, self)


func _setup_chest_menu() -> void:
	if canvas_layer == null:
		return
	chest_menu = PanelContainer.new()
	chest_menu.name = "ChestMenuOverlay"
	chest_menu.set_script(ChestMenuScript)
	canvas_layer.add_child(chest_menu)
	_set_subtree_process_mode(chest_menu, Node.PROCESS_MODE_ALWAYS)
	chest_menu.configure(player, self)


func _register_dialogue_scene_adapter() -> void:
	var dialogue_manager: Node = get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null or not dialogue_manager.has_method("register_scene_adapter"):
		return
	dialogue_manager.register_scene_adapter(self, player, canvas_layer, hover_detail_manager)


func _run_gameplay_scene_self_check() -> void:
	gameplay_scene_self_check_errors = GameplaySceneContract.validate_scene(self, {
		"require_dialogue_registration": true,
	})
	if gameplay_scene_self_check_errors.is_empty():
		return
	for error_text in gameplay_scene_self_check_errors:
		push_error("GameplaySceneContract[%s] %s" % [_get_gameplay_scene_contract_id(), error_text])


func _get_gameplay_scene_contract_id() -> String:
	if not str(scene_file_path).is_empty():
		return scene_file_path
	return name


func _set_subtree_process_mode(root: Node, mode: int) -> void:
	if root == null:
		return
	root.process_mode = mode
	for child in root.get_children():
		_set_subtree_process_mode(child, mode)
