extends PanelContainer

const SUMMARY_MIN_POPUP_WIDTH := 220.0
const SUMMARY_MAX_POPUP_WIDTH := 280.0
const DETAIL_MIN_POPUP_WIDTH := 300.0
const DETAIL_MAX_POPUP_WIDTH := 420.0

var title_label: Label
var content_label: RichTextLabel
var current_min_popup_width := SUMMARY_MIN_POPUP_WIDTH
var current_max_popup_width := SUMMARY_MAX_POPUP_WIDTH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(SUMMARY_MIN_POPUP_WIDTH, 0.0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.14, 0.92)
	panel_style.border_color = Color(0.46, 0.58, 0.72, 0.95)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)

	title_label = Label.new()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 16)
	stack.add_child(title_label)

	content_label = RichTextLabel.new()
	content_label.bbcode_enabled = true
	content_label.fit_content = true
	content_label.scroll_active = false
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_label.focus_mode = Control.FOCUS_NONE
	content_label.custom_minimum_size = Vector2(SUMMARY_MIN_POPUP_WIDTH - 20.0, 0.0)
	stack.add_child(content_label)


func show_detail(data: Dictionary, show_detail_lines: bool) -> void:
	if title_label == null or content_label == null:
		return

	if show_detail_lines:
		current_min_popup_width = float(data.get("detail_min_width", DETAIL_MIN_POPUP_WIDTH))
		current_max_popup_width = float(data.get("detail_max_width", DETAIL_MAX_POPUP_WIDTH))
	else:
		current_min_popup_width = float(data.get("summary_min_width", SUMMARY_MIN_POPUP_WIDTH))
		current_max_popup_width = float(data.get("summary_max_width", SUMMARY_MAX_POPUP_WIDTH))

	custom_minimum_size = Vector2(current_min_popup_width, 0.0)
	title_label.text = str(data.get("title", ""))
	content_label.custom_minimum_size = Vector2(current_min_popup_width - 20.0, 0.0)
	content_label.size = Vector2.ZERO
	content_label.clear()
	content_label.append_text(_build_body_text(data, show_detail_lines))
	visible = true


func hide_detail() -> void:
	visible = false


func get_popup_size() -> Vector2:
	var popup_size := get_combined_minimum_size()
	popup_size.x = clampf(popup_size.x, current_min_popup_width, current_max_popup_width)
	return popup_size


func _build_body_text(data: Dictionary, show_detail_lines: bool) -> String:
	var lines: Array[String] = []

	for summary_line in data.get("summary_lines", []):
		var line_text := str(summary_line)
		if line_text != "":
			lines.append(line_text)

	var supports_shift := bool(data.get("supports_shift", false))
	if show_detail_lines and supports_shift:
		for detail_line in data.get("detail_lines", []):
			var line_text := str(detail_line)
			if line_text != "":
				lines.append("[color=#aebed0]%s[/color]" % line_text)

	return "\n".join(lines)
