extends RefCounted
class_name HoverDetailResolver

const HoverDetailDataScript = preload("res://game/scripts/hover_detail_data.gd")
const CharacterStats = preload("res://game/scripts/character_stats.gd")
const CharacterCreationRegistry = preload("res://character_creation/scripts/character_creation_registry.gd")
const ItemSystem = preload("res://game/scripts/item_system.gd")


static func resolve(source_type: String, source_id: String, context: Dictionary) -> Dictionary:
	match source_type:
		"skill_entry":
			return _resolve_skill(source_id, context)
		"attribute_b_entry":
			return _resolve_b_stat(source_id, context)
		"item_entry":
			return _resolve_item_entry(source_id, context)
		"equipment_slot":
			return _resolve_equipment_slot(source_id, context)
		"creation_selection":
			return _resolve_creation_selection(source_id, context)
		"dialogue_keyword":
			return _resolve_dialogue_keyword(source_id, context)
		_:
			return {}


static func _resolve_skill(source_id: String, context: Dictionary) -> Dictionary:
	var player: Node = context.get("player")
	if player == null:
		return {}
	var skill_id := str(context.get("skill_id", source_id))
	if player.has_method("get_skill_hover_detail_data"):
		var detail_data: Dictionary = player.get_skill_hover_detail_data(skill_id)
		detail_data["source_type"] = "skill_entry"
		detail_data["source_id"] = skill_id
		return detail_data
	if skill_id == "slash_skill" and player.has_method("get_slash_skill_hover_detail_data"):
		var detail_data: Dictionary = player.get_slash_skill_hover_detail_data()
		detail_data["source_type"] = "skill_entry"
		detail_data["source_id"] = skill_id
		return detail_data
	return {}


static func _resolve_b_stat(source_id: String, context: Dictionary) -> Dictionary:
	var player: Node = context.get("player")
	var stat_key := str(context.get("stat_key", ""))
	var source_context := str(context.get("source_context", ""))
	if player != null and stat_key != "" and player.has_method("get_b_stat_hover_detail_data"):
		var player_detail_data: Dictionary = player.get_b_stat_hover_detail_data(stat_key, source_context)
		player_detail_data["source_type"] = "attribute_b_entry"
		player_detail_data["source_id"] = source_id
		return player_detail_data

	if player == null or stat_key == "":
		var current_b_stats: Dictionary = context.get("current_b_stats", {})
		var effective_a_stats: Dictionary = context.get("effective_a_stats", {})
		if stat_key == "" or current_b_stats.is_empty() or effective_a_stats.is_empty():
			return {}
		var creation_detail_data: Dictionary = CharacterStats.build_b_stat_hover_detail_data(
			stat_key,
			current_b_stats,
			effective_a_stats,
			source_context
		)
		creation_detail_data["source_type"] = "attribute_b_entry"
		creation_detail_data["source_id"] = source_id
		return creation_detail_data

	var detail_data: Dictionary = CharacterStats.build_b_stat_hover_detail_data(
		stat_key,
		player.get_character_b_stats(),
		player.get_character_a_stats(),
		source_context
	)
	detail_data["source_type"] = "attribute_b_entry"
	detail_data["source_id"] = source_id
	return detail_data


static func _resolve_item_entry(source_id: String, context: Dictionary) -> Dictionary:
	var item_stack: Dictionary = context.get("item_stack", {})
	var definition: Dictionary = context.get("item_definition", {})
	if item_stack.is_empty() or definition.is_empty():
		return {}

	var detail_data: Dictionary = ItemSystem.build_hover_detail_data(
		definition,
		item_stack,
		bool(context.get("is_equipped", false))
	)
	detail_data["source_type"] = "item_entry"
	detail_data["source_id"] = source_id
	return detail_data


static func _resolve_equipment_slot(source_id: String, context: Dictionary) -> Dictionary:
	var player: Node = context.get("player")
	var slot_type := str(context.get("slot_key", ""))
	if player == null or slot_type == "":
		return {}

	var item_stack: Dictionary = player.get_equipment_slot_stack(slot_type)
	var definition: Dictionary = player.get_item_stack_definition(item_stack)
	if not definition.is_empty():
		var detail_data: Dictionary = ItemSystem.build_hover_detail_data(definition, item_stack, true)
		detail_data["source_type"] = "equipment_slot"
		detail_data["source_id"] = source_id
		return detail_data

	var empty_detail := HoverDetailDataScript.new()
	empty_detail.title = "%s槽" % ItemSystem.get_slot_label(slot_type)
	empty_detail.source_type = "equipment_slot"
	empty_detail.source_id = source_id
	empty_detail.supports_shift = true
	empty_detail.summary_lines = ["当前未装备物品"]
	empty_detail.detail_lines = ["可装备类型：%s" % ItemSystem.get_slot_label(slot_type)]
	return empty_detail.to_dictionary()


static func _resolve_dialogue_keyword(source_id: String, context: Dictionary) -> Dictionary:
	var tooltip_data: Dictionary = context.get("tooltip_data", {})
	if tooltip_data.is_empty():
		return {}

	var detail_data := tooltip_data.duplicate(true)
	detail_data["source_type"] = "dialogue_keyword"
	detail_data["source_id"] = source_id
	return detail_data


static func _resolve_creation_selection(source_id: String, context: Dictionary) -> Dictionary:
	var selection_type := str(context.get("selection_type", ""))
	var selection_id := str(context.get("selection_id", ""))
	if selection_type == "" or selection_id == "":
		var source_parts := source_id.split(":", false, 1)
		if source_parts.size() == 2:
			selection_type = str(source_parts[0])
			selection_id = str(source_parts[1])
	if selection_type == "" or selection_id == "":
		return {}

	var detail_data := CharacterCreationRegistry.build_selection_hover_detail(
		selection_type,
		selection_id,
		context.get("selection_state", {})
	)
	if detail_data.is_empty():
		return {}
	detail_data["source_type"] = "creation_selection"
	detail_data["source_id"] = source_id
	return detail_data
