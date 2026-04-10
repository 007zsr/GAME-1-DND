extends PanelContainer

signal action_selected(action_id: String, action_context: Dictionary)
signal menu_closed

const SCREEN_PADDING := 8.0
const MOUSE_OFFSET := Vector2(10.0, 8.0)

var title_label: Label
var action_list: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	z_index = 2600
	z_as_relative = false

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.14, 0.96)
	panel_style.border_color = Color(0.62, 0.71, 0.82, 0.98)
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
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(title_label)

	var separator := HSeparator.new()
	stack.add_child(separator)

	action_list = VBoxContainer.new()
	action_list.add_theme_constant_override("separation", 4)
	stack.add_child(action_list)


func show_actions(title_text: String, actions: Array, mouse_position: Vector2, anchor_rect: Rect2 = Rect2()) -> void:
	_clear_action_buttons()
	title_label.text = title_text

	for action_data_variant in actions:
		var action_data := action_data_variant as Dictionary
		var button := Button.new()
		button.text = str(action_data.get("label", ""))
		button.custom_minimum_size = Vector2(140.0, 34.0)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_action_pressed.bind(str(action_data.get("id", "")), action_data.duplicate(true)))
		action_list.add_child(button)

	if action_list.get_child_count() <= 0:
		hide_menu()
		return

	visible = true
	call_deferred("_position_menu", mouse_position, anchor_rect)


func hide_menu() -> void:
	if not visible:
		return
	visible = false
	emit_signal("menu_closed")


func is_open() -> bool:
	return visible


func contains_global_point(global_point: Vector2) -> bool:
	if not visible:
		return false
	return get_global_rect().has_point(global_point)


func _clear_action_buttons() -> void:
	if action_list == null:
		return
	for child in action_list.get_children():
		action_list.remove_child(child)
		child.queue_free()


func _position_menu(mouse_position: Vector2, anchor_rect: Rect2) -> void:
	if not visible:
		return

	var popup_size := get_combined_minimum_size()
	var viewport_size := get_viewport_rect().size
	var target_x := mouse_position.x + MOUSE_OFFSET.x
	var target_y := mouse_position.y + MOUSE_OFFSET.y

	if target_x + popup_size.x > viewport_size.x - SCREEN_PADDING:
		target_x = mouse_position.x - popup_size.x - MOUSE_OFFSET.x
	if target_y + popup_size.y > viewport_size.y - SCREEN_PADDING:
		target_y = mouse_position.y - popup_size.y - MOUSE_OFFSET.y

	var popup_rect := Rect2(Vector2(target_x, target_y), popup_size)
	if anchor_rect.size != Vector2.ZERO and popup_rect.intersects(anchor_rect.grow(4.0)):
		var below_y := anchor_rect.end.y + MOUSE_OFFSET.y
		var above_y := anchor_rect.position.y - popup_size.y - MOUSE_OFFSET.y
		if below_y + popup_size.y <= viewport_size.y - SCREEN_PADDING:
			target_y = below_y
		elif above_y >= SCREEN_PADDING:
			target_y = above_y

	return_position(Vector2(
		clampf(target_x, SCREEN_PADDING, maxf(viewport_size.x - popup_size.x - SCREEN_PADDING, SCREEN_PADDING)),
		clampf(target_y, SCREEN_PADDING, maxf(viewport_size.y - popup_size.y - SCREEN_PADDING, SCREEN_PADDING))
	))


func return_position(target_position: Vector2) -> void:
	position = target_position


func _on_action_pressed(action_id: String, action_context: Dictionary) -> void:
	hide_menu()
	emit_signal("action_selected", action_id, action_context)
