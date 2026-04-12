extends PanelContainer

var scene_adapter: Node = null
var game_state: Node = null
var entry_button_container: VBoxContainer
var status_label: Label
var title_label: Label
var description_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(760.0, 500.0)
	_build_ui()


func configure(scene_node: Node) -> void:
	scene_adapter = scene_node
	game_state = get_node_or_null("/root/GameState")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_panel()
		get_viewport().set_input_as_handled()


func open_panel() -> void:
	_refresh_entries()
	visible = true


func close_panel(notify_scene: bool = true) -> void:
	visible = false
	if notify_scene and scene_adapter != null and scene_adapter.has_method("close_overlay"):
		scene_adapter.close_overlay(self)


func get_entry_state_snapshot() -> Array[Dictionary]:
	if game_state == null or not game_state.has_method("get_world_selection_entries"):
		return []
	return game_state.get_world_selection_entries()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	title_label = Label.new()
	title_label.text = "\u4e16\u754c\u9009\u62e9"
	title_label.add_theme_font_size_override("font_size", 28)
	root.add_child(title_label)

	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.text = "\u6b63\u5f0f\u4e16\u754c\u5165\u53e3\u548c\u5f00\u53d1\u6d4b\u8bd5\u5165\u53e3\u90fd\u4ece\u8fd9\u91cc\u8fdb\u5165\u3002\u6b63\u5f0f\u5165\u53e3\u4fdd\u6301\u539f\u6709\u89c4\u5219\uff0c\u6d4b\u8bd5\u5165\u53e3\u4ec5\u7528\u4e8e\u89c2\u5bdf\u5bd2\u971c\u8352\u539f\u8349\u6a21\u3002"
	root.add_child(description_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	entry_button_container = VBoxContainer.new()
	entry_button_container.add_theme_constant_override("separation", 12)
	scroll.add_child(entry_button_container)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	root.add_child(action_row)

	var close_button := Button.new()
	close_button.text = "\u5173\u95ed"
	close_button.custom_minimum_size = Vector2(140.0, 42.0)
	close_button.pressed.connect(close_panel)
	action_row.add_child(close_button)


func _refresh_entries() -> void:
	for child in entry_button_container.get_children():
		child.queue_free()

	var entries := get_entry_state_snapshot()
	if entries.is_empty():
		status_label.text = "\u4e16\u754c\u5165\u53e3\u914d\u7f6e\u6682\u65f6\u4e0d\u53ef\u7528\u3002"
		return

	var available_count := 0
	for entry in entries:
		if bool((entry as Dictionary).get("is_available", false)):
			available_count += 1
		entry_button_container.add_child(_build_entry_card(entry as Dictionary))

	status_label.text = "\u5f53\u524d\u5171\u663e\u793a %d \u4e2a\u5165\u53e3\uff0c\u5176\u4e2d %d \u4e2a\u53ef\u76f4\u63a5\u8fdb\u5165\u3002" % [entries.size(), available_count]


func _build_entry_card(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 92.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var entry_id := str(entry.get("entry_id", entry.get("world_id", "")))
	var display_name := str(entry.get("display_name", entry_id))
	var is_available := bool(entry.get("is_available", false))
	var tag_text := str(entry.get("badge_text", ""))
	if tag_text.is_empty():
		tag_text = "\u5df2\u5f00\u653e" if is_available else "\u6682\u672a\u5f00\u653e"

	var button := Button.new()
	button.text = "%s  |  %s" % [display_name, tag_text]
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.disabled = not is_available
	button.pressed.connect(_on_world_button_pressed.bind(entry_id))
	stack.add_child(button)

	var detail_label := Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.text = str(entry.get("detail_text", ""))
	if detail_label.text.is_empty():
		detail_label.text = "\u5f53\u524d\u53ef\u6b63\u5f0f\u8fdb\u5165\u5e76\u9a8c\u8bc1\u5f80\u8fd4\u95ed\u73af\u3002" if is_available else "\u672c\u8f6e\u5148\u4fdd\u7559\u7ed3\u6784\u5165\u53e3\uff0c\u6682\u4e0d\u5141\u8bb8\u8bef\u5165\u534a\u6210\u54c1\u6d41\u7a0b\u3002"
	stack.add_child(detail_label)

	return card


func _on_world_button_pressed(entry_id: String) -> void:
	if scene_adapter == null or not scene_adapter.has_method("handle_world_selection"):
		return
	scene_adapter.handle_world_selection(entry_id)
