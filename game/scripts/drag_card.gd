extends PanelContainer

var owner_ui: Control
var card_role: String = ""
var card_id: String = ""
var card_payload: Dictionary = {}
var allow_drag := true
var activate_on_single_click := false
var badge_label: Label
var title_label: Label
var summary_label: Label
var footer_label: Label
var _view_state := {
	"title_text": "",
	"summary_text": "",
	"badge_text": "",
	"footer_text": "",
	"empty_state": false,
	"locked_state": false,
	"selected_state": false,
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_apply_view_state()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func setup(
	owner_ref: Control,
	role: String,
	entry_id: String,
	payload: Dictionary = {},
	draggable: bool = true,
	single_click_activation: bool = false
) -> void:
	owner_ui = owner_ref
	card_role = role
	card_id = entry_id
	card_payload = payload.duplicate(true)
	allow_drag = draggable
	activate_on_single_click = single_click_activation


func set_card_content(
	title_text: String,
	summary_text: String,
	badge_text: String = "",
	footer_text: String = "",
	empty_state: bool = false,
	locked_state: bool = false,
	selected_state: bool = false
) -> void:
	_view_state = {
		"title_text": title_text,
		"summary_text": summary_text,
		"badge_text": badge_text,
		"footer_text": footer_text,
		"empty_state": empty_state,
		"locked_state": locked_state,
		"selected_state": selected_state,
	}
	_apply_view_state()


func _build_ui() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.17, 0.18, 0.22, 0.96)
	panel_style.border_color = Color(0.42, 0.47, 0.58, 0.95)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)

	badge_label = Label.new()
	badge_label.visible = false
	badge_label.add_theme_font_size_override("font_size", 13)
	badge_label.add_theme_color_override("font_color", Color(0.90, 0.80, 0.52, 1.0))
	stack.add_child(badge_label)

	title_label = Label.new()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99, 1.0))
	stack.add_child(title_label)

	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92, 1.0))
	stack.add_child(summary_label)

	footer_label = Label.new()
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_label.visible = false
	footer_label.add_theme_font_size_override("font_size", 13)
	footer_label.add_theme_color_override("font_color", Color(0.68, 0.78, 0.90, 1.0))
	stack.add_child(footer_label)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.double_click:
		if owner_ui != null and owner_ui.has_method("handle_drag_card_double_click"):
			owner_ui.handle_drag_card_double_click(card_role, card_id, card_payload)
		accept_event()
		return

	if activate_on_single_click:
		if owner_ui != null and owner_ui.has_method("handle_drag_card_single_click"):
			owner_ui.handle_drag_card_single_click(card_role, card_id, card_payload)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not allow_drag:
		return null
	if owner_ui != null and owner_ui.has_method("notify_drag_card_started"):
		owner_ui.notify_drag_card_started()
	var preview := Label.new()
	preview.text = title_label.text
	set_drag_preview(preview)
	return {
		"card_role": card_role,
		"card_id": card_id,
		"payload": card_payload.duplicate(true),
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if owner_ui == null or not owner_ui.has_method("can_drop_on_drag_card"):
		return false
	return owner_ui.can_drop_on_drag_card(card_role, card_id, card_payload, data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if owner_ui != null and owner_ui.has_method("handle_drop_on_drag_card"):
		owner_ui.handle_drop_on_drag_card(card_role, card_id, card_payload, data)


func _on_mouse_entered() -> void:
	if owner_ui != null and owner_ui.has_method("handle_drag_card_hover"):
		owner_ui.handle_drag_card_hover(true, card_role, card_id, card_payload, self)


func _on_mouse_exited() -> void:
	if owner_ui != null and owner_ui.has_method("handle_drag_card_hover"):
		owner_ui.handle_drag_card_hover(false, card_role, card_id, card_payload, self)


func get_render_debug_state() -> Dictionary:
	return {
		"visible": visible,
		"self_modulate_alpha": self_modulate.a,
		"title_text": str(_view_state.get("title_text", "")),
		"summary_text": str(_view_state.get("summary_text", "")),
		"size": size,
		"minimum_size": get_combined_minimum_size(),
	}


func _apply_view_state() -> void:
	if title_label == null or summary_label == null or badge_label == null or footer_label == null:
		return
	badge_label.text = str(_view_state.get("badge_text", ""))
	badge_label.visible = not badge_label.text.is_empty()
	title_label.text = str(_view_state.get("title_text", ""))
	summary_label.text = str(_view_state.get("summary_text", ""))
	footer_label.text = str(_view_state.get("footer_text", ""))
	footer_label.visible = not footer_label.text.is_empty()

	if bool(_view_state.get("locked_state", false)):
		self_modulate = Color(0.78, 0.80, 0.88, 0.86)
	elif bool(_view_state.get("empty_state", false)):
		self_modulate = Color(0.92, 0.95, 1.0, 0.92)
	elif bool(_view_state.get("selected_state", false)):
		self_modulate = Color(1.0, 0.97, 0.90, 1.0)
	else:
		self_modulate = Color(1.0, 1.0, 1.0, 1.0)
