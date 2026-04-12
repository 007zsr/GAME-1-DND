extends RefCounted
class_name GameplaySceneContract

# Gameplay scenes are expected to wire global services through the scene adapter
# layer, while leaving business truth in the existing player/system managers.

const HOVER_MANAGER_SCRIPT_PATH := "res://game/scripts/hover_detail_manager.gd"
const PLAYER_MENU_SCRIPT_PATH := "res://game/scripts/player_menu_ui_v2.gd"
const CHEST_MENU_SCRIPT_PATH := "res://game/scripts/chest_menu_ui_v2.gd"

const REQUIRED_SCENE_METHODS := [
	"get_player_node",
	"get_overlay_root",
	"get_hover_detail_manager",
	"is_result_showing",
	"is_overlay_open",
	"is_dialogue_active",
	"request_open_overlay",
	"close_overlay",
	"begin_dialogue_context",
	"end_dialogue_context",
	"resolve_world_movement",
]


static func build_scene_snapshot(scene: Node) -> Dictionary:
	var canvas_layer: CanvasLayer = scene.get_node_or_null("CanvasLayer")
	var player_node: Node = scene.get_node_or_null("WorldLayers/Entities/Player")
	var skill_bar_panel: PanelContainer = scene.get_node_or_null("CanvasLayer/SkillBarPanel")
	var skill_label: Label = scene.get_node_or_null("CanvasLayer/SkillBarPanel/SkillBarContent/SkillLabel")
	var hover_managers := _collect_nodes_by_script_path(canvas_layer, HOVER_MANAGER_SCRIPT_PATH)
	var player_menus := _collect_nodes_by_script_path(canvas_layer, PLAYER_MENU_SCRIPT_PATH)
	var chest_menus := _collect_nodes_by_script_path(canvas_layer, CHEST_MENU_SCRIPT_PATH)
	var dialogue_manager: Node = scene.get_node_or_null("/root/DialogueManager")
	var self_check_errors: Array[String] = []
	if scene != null and scene.has_method("get_gameplay_scene_self_check_errors"):
		self_check_errors.assign(scene.get_gameplay_scene_self_check_errors())

	var has_all_required_methods := true
	var missing_methods: Array[String] = []
	for method_name in REQUIRED_SCENE_METHODS:
		if not scene.has_method(method_name):
			has_all_required_methods = false
			missing_methods.append(method_name)

	var overlay_root_matches := false
	if scene != null and scene.has_method("get_overlay_root"):
		overlay_root_matches = scene.get_overlay_root() == canvas_layer

	var registered_dialogue_adapter_matches := false
	if dialogue_manager != null and dialogue_manager.has_method("get_scene_adapter"):
		registered_dialogue_adapter_matches = dialogue_manager.get_scene_adapter() == scene

	var hover_manager_matches := false
	if scene != null and scene.has_method("get_hover_detail_manager"):
		hover_manager_matches = scene.get_hover_detail_manager() == (hover_managers[0] if hover_managers.size() == 1 else null)

	var player_binding_matches := false
	if scene != null and scene.has_method("get_player_node"):
		player_binding_matches = scene.get_player_node() == player_node

	var skill_hover_enter_connected := false
	var skill_hover_exit_connected := false
	if skill_bar_panel != null and scene != null:
		if scene.has_method("_on_skill_bar_panel_mouse_entered"):
			skill_hover_enter_connected = skill_bar_panel.mouse_entered.is_connected(Callable(scene, "_on_skill_bar_panel_mouse_entered"))
		if scene.has_method("_on_skill_bar_panel_mouse_exited"):
			skill_hover_exit_connected = skill_bar_panel.mouse_exited.is_connected(Callable(scene, "_on_skill_bar_panel_mouse_exited"))

	return {
		"scene_name": scene.name if scene != null else "",
		"scene_file_path": str(scene.scene_file_path) if scene != null else "",
		"player_present": player_node != null,
		"overlay_root_present": canvas_layer != null,
		"overlay_root_matches": overlay_root_matches,
		"skill_bar_present": skill_bar_panel != null,
		"skill_label_present": skill_label != null,
		"skill_bar_minimum_size": skill_bar_panel.custom_minimum_size if skill_bar_panel != null else Vector2.ZERO,
		"skill_bar_size": Vector2(
			skill_bar_panel.offset_right - skill_bar_panel.offset_left,
			skill_bar_panel.offset_bottom - skill_bar_panel.offset_top
		) if skill_bar_panel != null else Vector2.ZERO,
		"hover_manager_count": hover_managers.size(),
		"hover_manager_matches": hover_manager_matches,
		"skill_hover_enter_connected": skill_hover_enter_connected,
		"skill_hover_exit_connected": skill_hover_exit_connected,
		"player_menu_count": player_menus.size(),
		"chest_menu_count": chest_menus.size(),
		"dialogue_adapter_registered": registered_dialogue_adapter_matches,
		"player_binding_matches": player_binding_matches,
		"has_all_required_methods": has_all_required_methods,
		"missing_methods": missing_methods,
		"self_check_errors": self_check_errors,
	}


static func validate_scene(scene: Node, options: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	if scene == null:
		errors.append("scene is null")
		return errors

	var snapshot := build_scene_snapshot(scene)
	if not bool(snapshot.get("has_all_required_methods", false)):
		errors.append("missing adapter methods: %s" % str(snapshot.get("missing_methods", [])))
	if not bool(snapshot.get("player_present", false)):
		errors.append("player node missing at WorldLayers/Entities/Player")
	if not bool(snapshot.get("overlay_root_present", false)):
		errors.append("overlay root missing at CanvasLayer")
	if not bool(snapshot.get("overlay_root_matches", false)):
		errors.append("get_overlay_root() does not match CanvasLayer")
	if not bool(snapshot.get("skill_bar_present", false)):
		errors.append("skill bar panel missing at CanvasLayer/SkillBarPanel")
	if not bool(snapshot.get("skill_label_present", false)):
		errors.append("skill label missing under SkillBarPanel/SkillBarContent")
	if not bool(snapshot.get("skill_hover_enter_connected", false)):
		errors.append("skill bar mouse_entered hook missing")
	if not bool(snapshot.get("skill_hover_exit_connected", false)):
		errors.append("skill bar mouse_exited hook missing")

	var minimum_size: Vector2 = snapshot.get("skill_bar_minimum_size", Vector2.ZERO)
	var panel_size: Vector2 = snapshot.get("skill_bar_size", Vector2.ZERO)
	if minimum_size.x < 220.0 or minimum_size.y < 86.0:
		errors.append("skill bar minimum size not normalized to 220x86")
	if panel_size.x < 220.0 or panel_size.y < 86.0:
		errors.append("skill bar offsets not normalized to 220x86")

	var hover_manager_count := int(snapshot.get("hover_manager_count", 0))
	if hover_manager_count != 1:
		errors.append("hover detail manager count should be 1, got %d" % hover_manager_count)
	if not bool(snapshot.get("hover_manager_matches", false)):
		errors.append("scene hover detail manager reference does not match overlay instance")

	var player_menu_count := int(snapshot.get("player_menu_count", 0))
	if player_menu_count != 1:
		errors.append("player menu overlay count should be 1, got %d" % player_menu_count)
	var chest_menu_count := int(snapshot.get("chest_menu_count", 0))
	if chest_menu_count != 1:
		errors.append("chest menu overlay count should be 1, got %d" % chest_menu_count)

	if bool(options.get("require_dialogue_registration", true)) and not bool(snapshot.get("dialogue_adapter_registered", false)):
		errors.append("DialogueManager scene adapter registration missing or mismatched")
	if not bool(snapshot.get("player_binding_matches", false)):
		errors.append("get_player_node() does not match scene player node")

	var self_check_errors: Array[String] = []
	self_check_errors.assign(snapshot.get("self_check_errors", []))
	for self_check_error in self_check_errors:
		errors.append("scene self-check: %s" % self_check_error)

	return errors


static func _collect_nodes_by_script_path(root: Node, script_path: String) -> Array[Node]:
	var matches: Array[Node] = []
	if root == null:
		return matches

	var root_script: Script = root.get_script()
	if root_script != null and str(root_script.resource_path) == script_path:
		matches.append(root)

	for child in root.get_children():
		matches.append_array(_collect_nodes_by_script_path(child, script_path))
	return matches
