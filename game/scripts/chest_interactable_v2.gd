extends Node2D

const GameLayers = preload("res://game/scripts/game_layers.gd")
const ItemSystem = preload("res://game/scripts/item_system.gd")

var village: Node
var player: Node
var chest_slots: Array = []
var player_in_range := false
var has_been_opened := false

@onready var body: ColorRect = $Body
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_shape: CollisionShape2D = $InteractionArea/CollisionShape2D
@onready var prompt_label: Label = $PromptLabel


func _ready() -> void:
	interaction_area.collision_layer = GameLayers.bit(GameLayers.ENEMY_DETECT)
	interaction_area.collision_mask = GameLayers.bit(GameLayers.PLAYER_ENTITY)
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	_update_visual_state()


func configure(village_node: Node, player_node: Node, position_meters: Vector2, meters_to_pixels: float, initial_slots: Array) -> void:
	village = village_node
	player = player_node
	position = position_meters * meters_to_pixels
	chest_slots.clear()
	for item_stack in initial_slots:
		chest_slots.append(ItemSystem.normalize_item_stack((item_stack as Dictionary).duplicate(true)))
	while chest_slots.size() < 10:
		chest_slots.append({})

	var circle_shape := CircleShape2D.new()
	circle_shape.radius = meters_to_pixels * 1.2
	interaction_shape.shape = circle_shape
	_update_visual_state()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not player_in_range:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if is_empty():
			return
		if village != null and village.has_method("open_chest_for_interaction"):
			village.open_chest_for_interaction(self)
			get_viewport().set_input_as_handled()


func get_slots() -> Array:
	var result: Array = []
	for item_stack in chest_slots:
		result.append(ItemSystem.normalize_item_stack((item_stack as Dictionary).duplicate(true)))
	return result


func get_stack(index: int) -> Dictionary:
	if index < 0 or index >= chest_slots.size():
		return {}
	return ItemSystem.normalize_item_stack((chest_slots[index] as Dictionary).duplicate(true))


func replace_stack(index: int, item_stack: Dictionary) -> bool:
	if index < 0 or index >= chest_slots.size():
		return false
	chest_slots[index] = ItemSystem.normalize_item_stack(item_stack)
	_update_visual_state()
	return true


func find_receive_target_index(item_stack: Dictionary) -> int:
	var normalized_stack := ItemSystem.normalize_item_stack(item_stack)
	if normalized_stack.is_empty():
		return -1

	var definition: Dictionary = ItemSystem.get_item_definition(ItemSystem.get_stack_template_id(normalized_stack))
	if definition.is_empty():
		return -1

	var max_stack: int = ItemSystem.get_max_stack_for_definition(definition)

	for index in range(chest_slots.size()):
		var existing_stack := ItemSystem.normalize_item_stack(chest_slots[index] as Dictionary)
		if existing_stack.is_empty():
			continue
		if not ItemSystem.can_merge_stacks(existing_stack, normalized_stack):
			continue
		var existing_count: int = int(existing_stack.get("count", 1))
		if existing_count < max_stack:
			return index

	for index in range(chest_slots.size()):
		if (chest_slots[index] as Dictionary).is_empty():
			return index

	return -1


func split_stack(index: int) -> bool:
	var item_stack := ItemSystem.normalize_item_stack(chest_slots[index] as Dictionary)
	var split_count: int = int(item_stack.get("count", 1)) / 2
	return split_stack_by_count(index, split_count)


func split_stack_by_count(index: int, split_count: int) -> bool:
	if index < 0 or index >= chest_slots.size():
		return false
	var item_stack := ItemSystem.normalize_item_stack(chest_slots[index] as Dictionary)
	if item_stack.is_empty():
		return false
	var definition := ItemSystem.get_item_definition(ItemSystem.get_stack_template_id(item_stack))
	if definition.is_empty() or not bool(definition.get("can_split", false)):
		return false
	var count: int = int(item_stack.get("count", 1))
	if count <= 1:
		return false
	if split_count < 1 or split_count >= count:
		return false
	var empty_index := _find_first_empty_slot()
	if empty_index == -1:
		return false
	item_stack["count"] = count - split_count
	chest_slots[index] = item_stack
	var new_stack := item_stack.duplicate(true)
	new_stack["count"] = split_count
	chest_slots[empty_index] = ItemSystem.normalize_item_stack(new_stack)
	_update_visual_state()
	return true


func is_empty() -> bool:
	for item_stack in chest_slots:
		if not (item_stack as Dictionary).is_empty():
			return false
	return true


func get_prompt_text() -> String:
	if is_empty():
		return "宝箱已空"
	if has_been_opened:
		return "按 E 查看宝箱"
	return "按 E 打开宝箱"


func mark_opened() -> void:
	has_been_opened = true
	_update_visual_state()


func _find_first_empty_slot() -> int:
	for index in range(chest_slots.size()):
		if (chest_slots[index] as Dictionary).is_empty():
			return index
	return -1


func _update_visual_state() -> void:
	if prompt_label == null or body == null:
		return
	prompt_label.visible = player_in_range
	prompt_label.text = get_prompt_text()
	if is_empty():
		body.color = Color(0.42, 0.30, 0.18, 1.0)
	elif has_been_opened:
		body.color = Color(0.72, 0.52, 0.22, 1.0)
	else:
		body.color = Color(0.62, 0.42, 0.16, 1.0)


func _on_interaction_area_entered(area: Area2D) -> void:
	if player != null and area == player.get_hitbox_area():
		player_in_range = true
		_update_visual_state()


func _on_interaction_area_exited(area: Area2D) -> void:
	if player != null and area == player.get_hitbox_area():
		player_in_range = false
		_update_visual_state()
