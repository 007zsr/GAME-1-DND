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
	title_label.text = "世界选择"
	title_label.add_theme_font_size_override("font_size", 28)
	root.add_child(title_label)

	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.text = "主神空间的正式出口目前统一在这里打开。先跑通一个正式入口，其余世界保留结构占位。"
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
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(140.0, 42.0)
	close_button.pressed.connect(close_panel)
	action_row.add_child(close_button)


func _refresh_entries() -> void:
	for child in entry_button_container.get_children():
		child.queue_free()

	var entries := get_entry_state_snapshot()
	if entries.is_empty():
		status_label.text = "世界配置暂时不可用。"
		return

	var available_count := 0
	for entry in entries:
		if bool((entry as Dictionary).get("is_available", false)):
			available_count += 1
		entry_button_container.add_child(_build_entry_card(entry as Dictionary))

	status_label.text = "当前共显示 %d 个世界入口，其中 %d 个可正式进入。" % [entries.size(), available_count]


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

	var world_id := str(entry.get("world_id", ""))
	var display_name := str(entry.get("display_name", world_id))
	var is_available := bool(entry.get("is_available", false))
	var is_test_world := bool(entry.get("is_test_world", false))
	var tag_text := "正式测试入口" if is_test_world else "暂未开放"
	if is_available and not is_test_world:
		tag_text = "已开放"
	var button := Button.new()
	button.text = "%s  |  %s" % [display_name, tag_text]
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.disabled = not is_available
	button.pressed.connect(_on_world_button_pressed.bind(world_id))
	stack.add_child(button)

	var detail_label := Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_available:
		detail_label.text = "当前可正式进入并验证往返闭环。"
	else:
		detail_label.text = "本轮先保留结构入口，暂不允许误入半成品流程。"
	stack.add_child(detail_label)

	return card


func _on_world_button_pressed(world_id: String) -> void:
	if scene_adapter == null or not scene_adapter.has_method("handle_world_selection"):
		return
	scene_adapter.handle_world_selection(world_id)
