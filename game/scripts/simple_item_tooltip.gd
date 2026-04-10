extends PanelContainer

const TOOLTIP_OFFSET := Vector2(14.0, 14.0)
const MAX_TOOLTIP_SIZE := Vector2(260.0, 170.0)

var content_label: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(240.0, 0.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	content_label = RichTextLabel.new()
	content_label.bbcode_enabled = true
	content_label.fit_content = true
	content_label.scroll_active = false
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.custom_minimum_size = Vector2(220.0, 0.0)
	margin.add_child(content_label)


func show_tooltip(bbcode_text: String) -> void:
	if content_label == null:
		return
	content_label.clear()
	content_label.append_text(bbcode_text)
	visible = true


func hide_tooltip() -> void:
	visible = false


func update_position(local_mouse_position: Vector2, viewport_size: Vector2) -> void:
	if not visible:
		return

	var tooltip_size := size
	if tooltip_size.x <= 0.0:
		tooltip_size = MAX_TOOLTIP_SIZE

	var target_position := local_mouse_position + TOOLTIP_OFFSET
	if target_position.x + tooltip_size.x > viewport_size.x - 8.0:
		target_position.x = local_mouse_position.x - tooltip_size.x - TOOLTIP_OFFSET.x
	if target_position.y + tooltip_size.y > viewport_size.y - 8.0:
		target_position.y = local_mouse_position.y - tooltip_size.y - TOOLTIP_OFFSET.y

	target_position.x = clampf(target_position.x, 8.0, maxf(viewport_size.x - tooltip_size.x - 8.0, 8.0))
	target_position.y = clampf(target_position.y, 8.0, maxf(viewport_size.y - tooltip_size.y - 8.0, 8.0))
	position = target_position
