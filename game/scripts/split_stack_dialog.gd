extends PanelContainer

signal split_confirmed(count: int, split_context: Dictionary)
signal dialog_closed

const SCREEN_PADDING := 8.0
const MOUSE_OFFSET := Vector2(16.0, 14.0)

var title_label: Label
var hint_label: Label
var count_spinner: SpinBox
var confirm_button: Button
var current_context: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	z_index = 2700
	z_as_relative = false
	custom_minimum_size = Vector2(260.0, 0.0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.14, 0.98)
	panel_style.border_color = Color(0.78, 0.74, 0.60, 0.98)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	title_label = Label.new()
	title_label.text = "拆分堆叠"
	title_label.add_theme_font_size_override("font_size", 18)
	stack.add_child(title_label)

	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(hint_label)

	var spinner_label := Label.new()
	spinner_label.text = "拆分数量"
	stack.add_child(spinner_label)

	count_spinner = SpinBox.new()
	count_spinner.min_value = 1.0
	count_spinner.step = 1.0
	count_spinner.rounded = true
	count_spinner.allow_greater = false
	count_spinner.allow_lesser = false
	count_spinner.custom_minimum_size = Vector2(160.0, 36.0)
	stack.add_child(count_spinner)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 8)
	stack.add_child(action_row)

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(hide_dialog)
	action_row.add_child(cancel_button)

	confirm_button = Button.new()
	confirm_button.text = "确认拆分"
	confirm_button.focus_mode = Control.FOCUS_NONE
	confirm_button.pressed.connect(_on_confirm_pressed)
	action_row.add_child(confirm_button)


func popup_for_stack(item_name: String, total_count: int, default_count: int, split_context: Dictionary, mouse_position: Vector2) -> void:
	var max_split: int = max(total_count - 1, 1)
	current_context = split_context.duplicate(true)
	title_label.text = "拆分 %s" % item_name
	hint_label.text = "输入想要拆出的数量。当前堆叠 %d，允许范围 1 到 %d。" % [total_count, max_split]
	count_spinner.min_value = 1.0
	count_spinner.max_value = float(max_split)
	count_spinner.value = clampi(default_count, 1, max_split)
	visible = true
	call_deferred("_position_dialog", mouse_position)


func hide_dialog() -> void:
	if not visible:
		return
	visible = false
	current_context.clear()
	emit_signal("dialog_closed")


func is_open() -> bool:
	return visible


func contains_global_point(global_point: Vector2) -> bool:
	if not visible:
		return false
	return get_global_rect().has_point(global_point)


func _position_dialog(mouse_position: Vector2) -> void:
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

	position = Vector2(
		clampf(target_x, SCREEN_PADDING, maxf(viewport_size.x - popup_size.x - SCREEN_PADDING, SCREEN_PADDING)),
		clampf(target_y, SCREEN_PADDING, maxf(viewport_size.y - popup_size.y - SCREEN_PADDING, SCREEN_PADDING))
	)


func _on_confirm_pressed() -> void:
	var split_count := clampi(int(round(count_spinner.value)), int(count_spinner.min_value), int(count_spinner.max_value))
	var split_context := current_context.duplicate(true)
	hide_dialog()
	emit_signal("split_confirmed", split_count, split_context)
