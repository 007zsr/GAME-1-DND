extends Node2D
class_name OverheadDisplay

const STYLE_RED := "red"
const STYLE_GREEN := "green"
const STYLE_BLUE := "blue"
const STYLE_NONE := "none"
const STYLE_BOSS_RED_LARGE := "boss_red_large"

const DEFAULT_HEAD_OFFSET := Vector2(0.0, -18.0)
const DEFAULT_NAME_FONT_SIZE := 10
const DEFAULT_NAME_WIDTH := 84.0
const LABEL_HEIGHT := 16.0
const BAR_MARGIN := 1.0

const STYLE_DEFINITIONS := {
	STYLE_RED: {
		"bar_width": 34.0,
		"bar_height": 4.0,
		"name_bar_gap": 1.0,
		"name_offset_y": 3.0,
		"head_display_offset_y": -18.0,
		"name_width": 84.0,
		"background_color": Color(0.16, 0.06, 0.06, 0.88),
		"fill_color": Color(0.90, 0.23, 0.23, 1.0),
	},
	STYLE_GREEN: {
		"bar_width": 34.0,
		"bar_height": 4.0,
		"name_bar_gap": 1.0,
		"name_offset_y": 3.0,
		"head_display_offset_y": -18.0,
		"name_width": 84.0,
		"background_color": Color(0.06, 0.14, 0.08, 0.88),
		"fill_color": Color(0.26, 0.82, 0.42, 1.0),
	},
	STYLE_BLUE: {
		"bar_width": 34.0,
		"bar_height": 4.0,
		"name_bar_gap": 1.0,
		"name_offset_y": 3.0,
		"head_display_offset_y": -18.0,
		"name_width": 84.0,
		"background_color": Color(0.06, 0.08, 0.16, 0.88),
		"fill_color": Color(0.30, 0.58, 0.96, 1.0),
	},
	STYLE_NONE: {
		"hide_bar": true,
		"bar_width": 0.0,
		"bar_height": 0.0,
		"name_bar_gap": 0.0,
		"name_offset_y": 2.0,
		"head_display_offset_y": -20.0,
		"name_width": 84.0,
	},
	STYLE_BOSS_RED_LARGE: {
		"bar_width": 50.0,
		"bar_height": 6.0,
		"name_bar_gap": 2.0,
		"name_offset_y": 3.0,
		"head_display_offset_y": -24.0,
		"name_width": 92.0,
		"background_color": Color(0.18, 0.04, 0.04, 0.92),
		"fill_color": Color(0.96, 0.18, 0.18, 1.0),
	},
}

var _display_name: String = ""
var _hp_bar_style: String = STYLE_RED
var _show_name: bool = true
var _current_hp: float = 1.0
var _max_hp: float = 1.0
var _head_offset_pixels: Vector2 = DEFAULT_HEAD_OFFSET
var _name_font_size: int = DEFAULT_NAME_FONT_SIZE
var _layout_overrides: Dictionary = {}

@onready var name_label: Label = $NameLabel
@onready var bar_background: ColorRect = $BarBackground
@onready var bar_fill: ColorRect = $BarBackground/BarFill


func _ready() -> void:
	z_as_relative = false
	z_index = 45
	_apply_state()


func sync_display(
	display_name: String,
	hp_bar_style: String,
	show_name: bool,
	current_hp: float,
	max_hp: float,
	layout_overrides: Dictionary = {},
	name_font_size: int = DEFAULT_NAME_FONT_SIZE
) -> void:
	_display_name = display_name
	_hp_bar_style = _normalize_style(hp_bar_style)
	_show_name = show_name
	_current_hp = maxf(current_hp, 0.0)
	_max_hp = maxf(max_hp, 1.0)
	_layout_overrides = layout_overrides.duplicate(true)
	_head_offset_pixels = _resolve_head_offset()
	_name_font_size = max(name_font_size, 8)
	if is_inside_tree():
		_apply_state()


func get_debug_state() -> Dictionary:
	var layout := _resolve_layout()
	var bar_size := _get_bar_size(layout)
	return {
		"display_name": _display_name,
		"hp_bar_style": _hp_bar_style,
		"show_name": _show_name,
		"current_hp": _current_hp,
		"max_hp": _max_hp,
		"head_offset_pixels": _head_offset_pixels,
		"name_visible": name_label.visible if name_label != null else false,
		"bar_visible": bar_background.visible if bar_background != null else false,
		"bar_size": bar_size,
		"bar_fill_width": bar_fill.size.x if bar_fill != null else 0.0,
		"hp_ratio": _get_health_ratio(),
		"bar_width": float(layout.get("bar_width", 0.0)),
		"bar_height": float(layout.get("bar_height", 0.0)),
		"name_bar_gap": float(layout.get("name_bar_gap", 0.0)),
		"name_offset_y": float(layout.get("name_offset_y", 0.0)),
		"head_display_offset_y": float(layout.get("head_display_offset_y", 0.0)),
		"name_width": float(layout.get("name_width", DEFAULT_NAME_WIDTH)),
	}


func _apply_state() -> void:
	if name_label == null or bar_background == null or bar_fill == null:
		return

	position = _head_offset_pixels
	var layout := _resolve_layout()
	var has_bar := not bool(layout.get("hide_bar", false))
	var bar_size := _get_bar_size(layout)
	var layout_width := maxf(float(layout.get("name_width", DEFAULT_NAME_WIDTH)), bar_size.x)
	var name_bar_gap := float(layout.get("name_bar_gap", 0.0))
	var name_offset_y := float(layout.get("name_offset_y", 0.0))

	name_label.visible = _show_name
	if _show_name:
		name_label.text = _display_name
		var name_top := -LABEL_HEIGHT + name_offset_y
		if has_bar:
			name_top -= bar_size.y + name_bar_gap
		name_label.position = Vector2(-layout_width * 0.5, name_top)
		name_label.size = Vector2(layout_width, LABEL_HEIGHT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", _name_font_size)
		name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
		name_label.add_theme_constant_override("outline_size", 2)

	bar_background.visible = has_bar
	if has_bar:
		bar_background.position = Vector2(-bar_size.x * 0.5, 0.0)
		bar_background.size = bar_size
		bar_background.color = layout.get("background_color", Color(0.0, 0.0, 0.0, 0.8)) as Color
		bar_fill.position = Vector2(BAR_MARGIN, BAR_MARGIN)
		bar_fill.size = Vector2(_get_fill_width(bar_size.x), maxf(bar_size.y - BAR_MARGIN * 2.0, 0.0))
		bar_fill.color = layout.get("fill_color", Color(1.0, 0.0, 0.0, 1.0)) as Color
	else:
		bar_background.size = Vector2.ZERO
		bar_fill.size = Vector2.ZERO

	visible = _show_name or has_bar


func _get_bar_size(layout: Dictionary) -> Vector2:
	return Vector2(
		float(layout.get("bar_width", 0.0)),
		float(layout.get("bar_height", 0.0))
	)


func _get_fill_width(total_width: float) -> float:
	var available_width := maxf(total_width - BAR_MARGIN * 2.0, 0.0)
	return available_width * _get_health_ratio()


func _get_health_ratio() -> float:
	return clampf(_current_hp / maxf(_max_hp, 1.0), 0.0, 1.0)


func _normalize_style(style_name: String) -> String:
	if STYLE_DEFINITIONS.has(style_name):
		return style_name
	return STYLE_RED


func _resolve_layout() -> Dictionary:
	var base_layout := (STYLE_DEFINITIONS.get(_hp_bar_style, STYLE_DEFINITIONS[STYLE_RED]) as Dictionary).duplicate(true)
	for key in _layout_overrides.keys():
		base_layout[str(key)] = _layout_overrides[key]
	return base_layout


func _resolve_head_offset() -> Vector2:
	var layout := _resolve_layout()
	var override_offset: Variant = _layout_overrides.get("head_offset_pixels", null)
	if override_offset is Vector2:
		return override_offset
	return Vector2(0.0, float(layout.get("head_display_offset_y", DEFAULT_HEAD_OFFSET.y)))
