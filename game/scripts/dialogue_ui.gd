extends Control

const KEYWORD_SOURCE_TYPE := "dialogue_keyword"

var dialogue_manager: Node = null
var hover_detail_manager: Control = null
var current_keyword_ids: Array[String] = []
var option_buttons: Array[Button] = []
var option_commit_locked: bool = false

var panel: PanelContainer
var speaker_label: Label
var text_rows_container: VBoxContainer
var options_container: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_anchors_preset(Control.PRESET_FULL_RECT)

	panel = PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.custom_minimum_size = Vector2(780.0, 250.0)
	panel.anchor_left = 0.12
	panel.anchor_top = 0.60
	panel.anchor_right = 0.88
	panel.anchor_bottom = 0.95
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)

	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 24)
	stack.add_child(speaker_label)

	text_rows_container = VBoxContainer.new()
	text_rows_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_rows_container.add_theme_constant_override("separation", 10)
	stack.add_child(text_rows_container)

	options_container = VBoxContainer.new()
	options_container.add_theme_constant_override("separation", 10)
	stack.add_child(options_container)


func configure(manager_node: Node, hover_manager: Control) -> void:
	dialogue_manager = manager_node
	hover_detail_manager = hover_manager


func open_dialogue() -> void:
	visible = true
	grab_focus()


func close_dialogue() -> void:
	_clear_rendered_content()
	visible = false
	option_commit_locked = false


func show_view_model(view_model: Dictionary) -> void:
	_clear_rendered_content()
	option_commit_locked = false
	speaker_label.text = str(view_model.get("speaker_name", ""))

	for row_data in view_model.get("text_rows", []):
		_render_text_row(row_data as Array)

	for option_data in view_model.get("options", []):
		_render_option(option_data as Dictionary)

	if not option_buttons.is_empty():
		option_buttons[0].grab_focus()


func set_option_commit_locked(locked: bool) -> void:
	option_commit_locked = locked
	for button in option_buttons:
		if button != null:
			button.disabled = locked


func _render_text_row(row_data: Array) -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 0)
	row.add_theme_constant_override("v_separation", 4)
	text_rows_container.add_child(row)

	for fragment_data in row_data:
		var fragment: Dictionary = fragment_data as Dictionary
		var fragment_text: String = str(fragment.get("text", ""))
		if fragment_text == "":
			continue

		var has_tooltip: bool = typeof(fragment.get("tooltip_data", {})) == TYPE_DICTIONARY and not (fragment.get("tooltip_data", {}) as Dictionary).is_empty()
		var is_highlighted: bool = bool(fragment.get("highlight", false))
		if is_highlighted and has_tooltip:
			var keyword_button := Button.new()
			keyword_button.flat = true
			keyword_button.focus_mode = Control.FOCUS_NONE
			keyword_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			keyword_button.text = fragment_text
			keyword_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42, 1.0))
			keyword_button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.66, 1.0))
			row.add_child(keyword_button)

			var keyword_id := "%s:%s:%d" % [
				str(fragment.get("keyword_id", fragment_text)),
				Time.get_ticks_msec(),
				current_keyword_ids.size(),
			]
			current_keyword_ids.append(keyword_id)
			keyword_button.mouse_entered.connect(_on_keyword_mouse_entered.bind(keyword_button, keyword_id, fragment.get("tooltip_data", {})))
			keyword_button.mouse_exited.connect(_on_keyword_mouse_exited.bind(keyword_id))
		else:
			var text_label := Label.new()
			text_label.text = fragment_text
			if is_highlighted:
				text_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42, 1.0))
			row.add_child(text_label)


func _render_option(option_data: Dictionary) -> void:
	var option_button := Button.new()
	option_button.custom_minimum_size = Vector2(0.0, 42.0)
	option_button.text = str(option_data.get("text", ""))
	option_button.disabled = option_commit_locked
	option_button.pressed.connect(_on_option_button_pressed.bind(str(option_data.get("id", ""))))
	options_container.add_child(option_button)
	option_buttons.append(option_button)


func _clear_rendered_content() -> void:
	for keyword_id in current_keyword_ids:
		if hover_detail_manager != null:
			hover_detail_manager.clear_hover(keyword_id)
	current_keyword_ids.clear()

	for child in text_rows_container.get_children():
		child.queue_free()
	for child in options_container.get_children():
		child.queue_free()
	option_buttons.clear()


func _on_option_button_pressed(option_id: String) -> void:
	if option_commit_locked:
		return
	option_commit_locked = true
	set_option_commit_locked(true)
	if dialogue_manager != null and dialogue_manager.has_method("select_option"):
		dialogue_manager.select_option(option_id)


func _on_keyword_mouse_entered(anchor_control: Control, keyword_id: String, tooltip_data: Dictionary) -> void:
	if hover_detail_manager == null:
		return
	hover_detail_manager.request_hover(
		KEYWORD_SOURCE_TYPE,
		keyword_id,
		anchor_control,
		Callable(self, "_build_keyword_hover_context").bind(tooltip_data),
		"target"
	)


func _on_keyword_mouse_exited(keyword_id: String) -> void:
	if hover_detail_manager == null:
		return
	hover_detail_manager.clear_hover(keyword_id)


func _build_keyword_hover_context(tooltip_data: Dictionary) -> Dictionary:
	return {
		"tooltip_data": tooltip_data.duplicate(true),
	}
