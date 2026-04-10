extends RefCounted
class_name DialogueTestData

const DialogueDataRegistry = preload("res://game/scripts/dialogue_data_registry.gd")


static func get_dialogue(dialogue_id: String) -> Dictionary:
	return DialogueDataRegistry.get_dialogue(dialogue_id)
