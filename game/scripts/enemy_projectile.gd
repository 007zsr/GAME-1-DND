extends Node2D

var village: Node2D
var meters_to_pixels: float = 16.0
var direction: Vector2 = Vector2.RIGHT
var speed_pixels_per_second: float = 0.0
var max_distance_pixels: float = 0.0
var traveled_pixels: float = 0.0
var damage: int = 0
var source_name: String = ""
var size_meters: Vector2 = Vector2(0.2, 0.2)
var attack_profile: Dictionary = {}

@onready var body: ColorRect = $Body


func setup_projectile(projectile_config: Dictionary, village_node: Node2D, start_position: Vector2, fire_direction: Vector2, world_meters_to_pixels: float, attacker_name: String, projectile_attack_profile: Dictionary = {}) -> void:
	village = village_node
	global_position = start_position
	meters_to_pixels = world_meters_to_pixels
	direction = fire_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	speed_pixels_per_second = float(projectile_config["projectile_speed_mps"]) * meters_to_pixels
	max_distance_pixels = float(projectile_config["projectile_range_meters"]) * meters_to_pixels
	damage = int(projectile_config["damage"])
	source_name = attacker_name
	attack_profile = projectile_attack_profile.duplicate(true)
	size_meters = projectile_config["projectile_size_meters"] as Vector2
	body.color = projectile_config["effect_color"] as Color
	_apply_visual_size()


func _process(delta: float) -> void:
	if village != null and village.has_method("is_result_showing") and village.is_result_showing():
		return
	if village != null and village.has_method("is_dialogue_active") and village.is_dialogue_active():
		return

	var motion: Vector2 = direction * speed_pixels_per_second * delta
	global_position += motion
	traveled_pixels += motion.length()

	if village.projectile_hits_player(global_position, get_hitbox_half_size_pixels(), damage, source_name, attack_profile):
		queue_free()
		return

	if traveled_pixels >= max_distance_pixels:
		queue_free()


func get_hitbox_half_size_pixels() -> Vector2:
	return size_meters * meters_to_pixels * 0.5


func _apply_visual_size() -> void:
	var half_size_pixels: Vector2 = get_hitbox_half_size_pixels()
	body.offset_left = -half_size_pixels.x
	body.offset_top = -half_size_pixels.y
	body.offset_right = half_size_pixels.x
	body.offset_bottom = half_size_pixels.y
