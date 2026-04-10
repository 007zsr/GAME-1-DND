extends Control

const HoverDetailPopupScript = preload("res://game/scripts/hover_detail_popup.gd")
const HoverDetailResolver = preload("res://game/scripts/hover_detail_resolver.gd")
const HOVER_DELAY_SECONDS := 0.22
const POPUP_OFFSET := Vector2(14.0, 14.0)
const SCREEN_PADDING := 8.0
const MANAGER_Z_INDEX := 2000

var hover_timer: Timer
var hover_popup: PanelContainer
var current_source_id := ""
var current_source_type := ""
var current_anchor: Control
var current_context_provider: Callable
var current_position_mode := "mouse"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = MANAGER_Z_INDEX
	z_as_relative = false

	hover_timer = Timer.new()
	hover_timer.one_shot = true
	hover_timer.wait_time = HOVER_DELAY_SECONDS
	hover_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(hover_timer)

	hover_popup = PanelContainer.new()
	hover_popup.set_script(HoverDetailPopupScript)
	hover_popup.top_level = true
	hover_popup.z_index = MANAGER_Z_INDEX + 1
	hover_popup.z_as_relative = false
	add_child(hover_popup)


func request_hover(source_type: String, source_id: String, anchor_control: Control, context_provider: Callable, position_mode: String = "mouse") -> void:
	if anchor_control == null or not is_instance_valid(anchor_control):
		return
	if context_provider.is_null():
		return

	var source_changed := source_id != current_source_id or source_type != current_source_type
	current_source_type = source_type
	current_source_id = source_id
	current_anchor = anchor_control
	current_context_provider = context_provider
	current_position_mode = position_mode

	if hover_popup.visible and source_changed:
		_refresh_popup()
		return

	if hover_popup.visible:
		_refresh_popup()
		return

	hover_timer.stop()
	hover_timer.start()


func clear_hover(source_id: String = "") -> void:
	if source_id != "" and source_id != current_source_id:
		return
	hide_immediately()


func hide_immediately() -> void:
	current_source_id = ""
	current_source_type = ""
	current_anchor = null
	current_context_provider = Callable()
	current_position_mode = "mouse"
	if hover_timer != null:
		hover_timer.stop()
	if hover_popup != null:
		hover_popup.hide_detail()


func _process(_delta: float) -> void:
	if current_source_id == "" or current_context_provider.is_null():
		return
	if current_anchor == null or not is_instance_valid(current_anchor):
		hide_immediately()
		return
	if hover_popup != null and hover_popup.visible:
		_refresh_popup()


func _on_hover_timer_timeout() -> void:
	if current_source_id == "" or current_context_provider.is_null():
		return
	_refresh_popup()


func _refresh_popup() -> void:
	if current_context_provider.is_null():
		return

	var context: Dictionary = current_context_provider.call()
	if typeof(context) != TYPE_DICTIONARY:
		context = {}
	context["source_type"] = current_source_type
	context["source_id"] = current_source_id
	context["anchor_control"] = current_anchor
	context["detail_mode"] = "shift" if Input.is_key_pressed(KEY_SHIFT) else "summary"

	var detail_data: Dictionary = HoverDetailResolver.resolve(current_source_type, current_source_id, context)
	if typeof(detail_data) != TYPE_DICTIONARY or (detail_data as Dictionary).is_empty():
		if hover_popup != null:
			hover_popup.hide_detail()
		return

	var show_detail_lines := Input.is_key_pressed(KEY_SHIFT) and bool(detail_data.get("supports_shift", false))
	hover_popup.show_detail(detail_data, show_detail_lines)
	_update_popup_position()


func _update_popup_position() -> void:
	if hover_popup == null or not hover_popup.visible:
		return

	var popup_size: Vector2 = hover_popup.get_popup_size()
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_position: Vector2
	if current_position_mode == "target":
		target_position = _get_target_anchor_position(popup_size, viewport_size)
	else:
		target_position = _get_mouse_anchor_position(popup_size, viewport_size)

	hover_popup.position = target_position


func _get_target_anchor_position(popup_size: Vector2, viewport_size: Vector2) -> Vector2:
	if current_anchor == null or not is_instance_valid(current_anchor):
		return _get_mouse_anchor_position(popup_size, viewport_size)

	var anchor_rect: Rect2 = current_anchor.get_global_rect()
	var place_right := anchor_rect.end.x + POPUP_OFFSET.x + popup_size.x <= viewport_size.x - SCREEN_PADDING
	var left_x := anchor_rect.position.x - popup_size.x - POPUP_OFFSET.x
	var target_x := anchor_rect.end.x + POPUP_OFFSET.x if place_right or left_x < SCREEN_PADDING else left_x
	var target_y := anchor_rect.position.y

	if target_y + popup_size.y > viewport_size.y - SCREEN_PADDING:
		target_y = anchor_rect.end.y - popup_size.y

	return Vector2(
		clampf(target_x, SCREEN_PADDING, maxf(viewport_size.x - popup_size.x - SCREEN_PADDING, SCREEN_PADDING)),
		clampf(target_y, SCREEN_PADDING, maxf(viewport_size.y - popup_size.y - SCREEN_PADDING, SCREEN_PADDING))
	)


func _get_mouse_anchor_position(popup_size: Vector2, viewport_size: Vector2) -> Vector2:
	var mouse_position := get_viewport().get_mouse_position()
	var target_x := mouse_position.x + POPUP_OFFSET.x
	var target_y := mouse_position.y + POPUP_OFFSET.y

	if target_x + popup_size.x > viewport_size.x - SCREEN_PADDING:
		target_x = mouse_position.x - popup_size.x - POPUP_OFFSET.x
	if target_y + popup_size.y > viewport_size.y - SCREEN_PADDING:
		target_y = mouse_position.y - popup_size.y - POPUP_OFFSET.y

	return Vector2(
		clampf(target_x, SCREEN_PADDING, maxf(viewport_size.x - popup_size.x - SCREEN_PADDING, SCREEN_PADDING)),
		clampf(target_y, SCREEN_PADDING, maxf(viewport_size.y - popup_size.y - SCREEN_PADDING, SCREEN_PADDING))
	)
