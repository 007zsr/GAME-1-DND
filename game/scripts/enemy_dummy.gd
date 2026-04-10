extends Node2D

signal enemy_died(enemy: Node2D)

@export var max_health: int = 100

var enemy_data: Dictionary = {}
var size_meters: Vector2 = Vector2(0.3, 0.3)
var meters_to_pixels: float = 16.0

@onready var body: ColorRect = $Body
@onready var name_label: Label = $NameLabel
@onready var health_label: Label = $HealthLabel


func _ready() -> void:
	enemy_data = {
		"health": max_health,
	}
	_apply_visual_size()
	_update_health_label()


func setup_enemy(initial_health: int, new_size_meters: Vector2 = Vector2(0.3, 0.3), new_meters_to_pixels: float = 16.0) -> void:
	enemy_data["health"] = initial_health
	size_meters = new_size_meters
	meters_to_pixels = new_meters_to_pixels
	_apply_visual_size()
	_update_health_label()


func take_damage(damage: int) -> void:
	enemy_data["health"] = max(int(enemy_data["health"]) - damage, 0)
	_update_health_label()

	if int(enemy_data["health"]) <= 0:
		emit_signal("enemy_died", self)


func get_enemy_data() -> Dictionary:
	return enemy_data.duplicate(true)


func get_hitbox_half_size_pixels() -> Vector2:
	return size_meters * meters_to_pixels * 0.5


func _apply_visual_size() -> void:
	var half_size_pixels: Vector2 = get_hitbox_half_size_pixels()
	body.offset_left = -half_size_pixels.x
	body.offset_top = -half_size_pixels.y
	body.offset_right = half_size_pixels.x
	body.offset_bottom = half_size_pixels.y

	name_label.add_theme_font_size_override("font_size", 8)
	health_label.add_theme_font_size_override("font_size", 8)
	name_label.offset_left = -18.0
	name_label.offset_top = -18.0
	name_label.offset_right = 18.0
	name_label.offset_bottom = -4.0
	health_label.offset_left = -20.0
	health_label.offset_top = 6.0
	health_label.offset_right = 20.0
	health_label.offset_bottom = 18.0


func _update_health_label() -> void:
	health_label.text = "HP %d" % int(enemy_data["health"])
