extends Node2D

const GameLayers = preload("res://game/scripts/game_layers.gd")

var scene_adapter: Node = null
var player: Node = null
var gate_id: String = ""
var display_name: String = "出口"
var prompt_text: String = "按 E 交互"
var player_in_range: bool = false

@onready var body: ColorRect = $Body
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_shape: CollisionShape2D = $InteractionArea/CollisionShape2D
@onready var name_label: Label = $NameLabel
@onready var prompt_label: Label = $PromptLabel


func _ready() -> void:
	interaction_area.collision_layer = GameLayers.bit(GameLayers.ENEMY_DETECT)
	interaction_area.collision_mask = GameLayers.bit(GameLayers.PLAYER_ENTITY)
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	_update_visual_state()


func configure(scene_node: Node, player_node: Node, position_meters: Vector2, meters_to_pixels: float, assigned_gate_id: String, assigned_name: String, assigned_prompt: String) -> void:
	scene_adapter = scene_node
	player = player_node
	gate_id = assigned_gate_id
	display_name = assigned_name
	prompt_text = assigned_prompt
	position = position_meters * meters_to_pixels

	var circle_shape := CircleShape2D.new()
	circle_shape.radius = meters_to_pixels * 1.3
	interaction_shape.shape = circle_shape
	_update_visual_state()


func get_gate_id() -> String:
	return gate_id


func get_display_name() -> String:
	return display_name


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not player_in_range:
		return
	if scene_adapter != null and scene_adapter.has_method("is_overlay_open") and scene_adapter.is_overlay_open():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if scene_adapter != null and scene_adapter.has_method("handle_gate_interaction"):
			if bool(scene_adapter.handle_gate_interaction(gate_id, self)):
				get_viewport().set_input_as_handled()


func _update_visual_state() -> void:
	if body == null or name_label == null or prompt_label == null:
		return
	body.color = Color(0.36, 0.54, 0.78, 1.0) if player_in_range else Color(0.24, 0.34, 0.52, 1.0)
	name_label.text = display_name
	prompt_label.text = prompt_text
	prompt_label.visible = player_in_range


func _on_interaction_area_entered(area: Area2D) -> void:
	if player != null and area == player.get_hitbox_area():
		player_in_range = true
		_update_visual_state()


func _on_interaction_area_exited(area: Area2D) -> void:
	if player != null and area == player.get_hitbox_area():
		player_in_range = false
		_update_visual_state()
