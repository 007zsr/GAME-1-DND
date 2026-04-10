extends PanelContainer

var owner_menu: Control
var slot_kind: String = ""
var slot_key: Variant = null
var accept_slot_type: String = ""
var empty_text_override: String = ""
var slot_min_size := Vector2(72.0, 72.0)
var item_stack: Dictionary = {}
var item_definition: Dictionary = {}

var name_label: Label
var count_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = slot_min_size
	_build_ui()
	mouse_entered.connect(_mouse_enter)
	mouse_exited.connect(_mouse_exit)


func setup(menu_ref: Control, new_slot_kind: String, new_slot_key: Variant, new_accept_slot_type: String = "", new_empty_text_override: String = "", new_slot_min_size: Vector2 = Vector2(72.0, 72.0)) -> void:
	owner_menu = menu_ref
	slot_kind = new_slot_kind
	slot_key = new_slot_key
	accept_slot_type = new_accept_slot_type
	empty_text_override = new_empty_text_override
	slot_min_size = new_slot_min_size
	custom_minimum_size = slot_min_size


func set_item_view(new_item_stack: Dictionary, new_item_definition: Dictionary) -> void:
	item_stack = new_item_stack.duplicate(true)
	item_definition = new_item_definition.duplicate(true)
	if name_label == null:
		return

	if item_stack.is_empty() or item_definition.is_empty():
		name_label.text = _get_empty_slot_text()
		count_label.text = ""
		modulate = Color(1.0, 1.0, 1.0, 0.7)
		return

	name_label.text = str(item_definition.get("name", ""))
	count_label.text = "x%d" % int(item_stack.get("count", 1)) if int(item_stack.get("count", 1)) > 1 else ""
	modulate = Color(1.0, 1.0, 1.0, 1.0)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)

	name_label = Label.new()
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.max_lines_visible = 1
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	stack.add_child(name_label)

	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 12)
	stack.add_child(count_label)

	set_item_view({}, {})


func _get_empty_slot_text() -> String:
	if empty_text_override != "":
		return empty_text_override
	if slot_kind == "equipment":
		return accept_slot_type
	return "\u7a7a"


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_event.double_click and owner_menu != null and owner_menu.has_method("handle_slot_double_click"):
			owner_menu.handle_slot_double_click(slot_kind, slot_key)
			accept_event()
			return
		if owner_menu != null and owner_menu.has_method("select_slot"):
			owner_menu.select_slot(slot_kind, slot_key)
		return

	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if owner_menu != null and owner_menu.has_method("select_slot"):
			owner_menu.select_slot(slot_kind, slot_key)
		if owner_menu != null and owner_menu.has_method("handle_slot_right_click"):
			owner_menu.handle_slot_right_click(slot_kind, slot_key, get_viewport().get_mouse_position(), get_global_rect())
			accept_event()


func _mouse_enter() -> void:
	if owner_menu != null and owner_menu.has_method("hover_slot"):
		owner_menu.hover_slot(slot_kind, slot_key)


func _mouse_exit() -> void:
	if owner_menu != null and owner_menu.has_method("unhover_slot"):
		owner_menu.unhover_slot(slot_kind, slot_key)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_stack.is_empty():
		return null

	if owner_menu != null and owner_menu.has_method("select_slot"):
		owner_menu.select_slot(slot_kind, slot_key)
	if owner_menu != null and owner_menu.has_method("notify_item_drag_started"):
		owner_menu.notify_item_drag_started()

	var preview := Label.new()
	preview.text = str(item_definition.get("name", ""))
	set_drag_preview(preview)

	return {
		"slot_kind": slot_kind,
		"slot_key": slot_key,
		"item_stack": item_stack.duplicate(true),
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if owner_menu == null or not owner_menu.has_method("can_drop_on_slot"):
		return false
	return owner_menu.can_drop_on_slot(slot_kind, slot_key, data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if owner_menu != null and owner_menu.has_method("handle_drop_on_slot"):
		owner_menu.handle_drop_on_slot(slot_kind, slot_key, data)
