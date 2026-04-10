extends Node2D

const GameLayers = preload("res://game/scripts/game_layers.gd")

var village: Node = null
var player: Node = null
var dialogue_id: String = ""
var npc_name: String = ""
var player_in_range: bool = false
var dialogue_source_node: Node = null

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


func configure(village_node: Node, player_node: Node, position_meters: Vector2, meters_to_pixels: float, assigned_dialogue_id: String, display_name: String = "村民") -> void:
	village = village_node
	player = player_node
	dialogue_id = assigned_dialogue_id
	npc_name = display_name
	dialogue_source_node = self
	position = position_meters * meters_to_pixels

	var circle_shape := CircleShape2D.new()
	circle_shape.radius = meters_to_pixels * 1.2
	interaction_shape.shape = circle_shape
	body.visible = true
	name_label.visible = true
	_update_visual_state()


func configure_on_host(village_node: Node, player_node: Node, host_node: Node2D, meters_to_pixels: float, assigned_dialogue_id: String, display_name: String = "NPC", hide_embedded_visuals: bool = true) -> void:
	village = village_node
	player = player_node
	dialogue_id = assigned_dialogue_id
	npc_name = display_name
	dialogue_source_node = host_node
	position = Vector2.ZERO

	var circle_shape := CircleShape2D.new()
	circle_shape.radius = meters_to_pixels * 1.2
	interaction_shape.shape = circle_shape
	if hide_embedded_visuals:
		body.visible = false
		name_label.visible = false
	else:
		body.visible = true
		name_label.visible = true
	_update_visual_state()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not player_in_range:
		return
	if village != null and village.has_method("is_overlay_open") and village.is_overlay_open():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		var dialogue_manager: Node = get_node_or_null("/root/DialogueManager")
		if dialogue_manager != null and dialogue_manager.has_method("start_dialogue"):
			var source_node: Node = dialogue_source_node if dialogue_source_node != null else self
			dialogue_manager.start_dialogue(dialogue_id, source_node, {"npc_name": npc_name})
			get_viewport().set_input_as_handled()


func get_prompt_text() -> String:
	return "按 E 交谈"


func _update_visual_state() -> void:
	if body == null or prompt_label == null or name_label == null:
		return
	body.color = Color(0.42, 0.58, 0.34, 1.0) if player_in_range else Color(0.30, 0.46, 0.26, 1.0)
	name_label.text = npc_name
	prompt_label.text = get_prompt_text()
	prompt_label.visible = player_in_range


func _on_interaction_area_entered(area: Area2D) -> void:
	if player != null and area == player.get_hitbox_area():
		player_in_range = true
		_update_visual_state()


func _on_interaction_area_exited(area: Area2D) -> void:
	if player != null and area == player.get_hitbox_area():
		player_in_range = false
		_update_visual_state()
