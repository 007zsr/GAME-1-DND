extends Node

const SkillRegistry = preload("res://game/skills/skill_registry.gd")

var current_character: Dictionary = {}
var created_characters: Array[Dictionary] = []


func set_current_character(character_data: Dictionary) -> void:
	current_character = character_data.duplicate(true)
	_ensure_runtime_state_defaults()
	created_characters.append(current_character.duplicate(true))


func get_current_character() -> Dictionary:
	return current_character.duplicate(true)


func get_granted_triggers() -> Array[String]:
	var results: Array[String] = []
	for entry in current_character.get("granted_triggers", []):
		results.append(str(entry))
	return results


func has_granted_trigger(trigger_id: String) -> bool:
	if trigger_id == "":
		return false
	for entry in get_granted_triggers():
		if entry == trigger_id:
			return true
	return false


func grant_trigger(trigger_id: String) -> void:
	if trigger_id == "":
		return
	_ensure_runtime_state_defaults()
	if has_granted_trigger(trigger_id):
		return
	var granted_triggers: Array = current_character.get("granted_triggers", [])
	granted_triggers.append(trigger_id)
	current_character["granted_triggers"] = granted_triggers


func revoke_trigger(trigger_id: String) -> void:
	if trigger_id == "":
		return
	_ensure_runtime_state_defaults()
	var granted_triggers: Array = []
	for entry in current_character.get("granted_triggers", []):
		if str(entry) != trigger_id:
			granted_triggers.append(str(entry))
	current_character["granted_triggers"] = granted_triggers


func get_event_flags() -> Dictionary:
	_ensure_runtime_state_defaults()
	return (current_character.get("event_flags", {}) as Dictionary).duplicate(true)


func get_event_flag(flag_id: String, default_value: bool = false) -> bool:
	if flag_id == "":
		return default_value
	return bool(get_event_flags().get(flag_id, default_value))


func set_event_flag(flag_id: String, value: bool = true) -> void:
	if flag_id == "":
		return
	_ensure_runtime_state_defaults()
	var event_flags: Dictionary = current_character.get("event_flags", {})
	event_flags[flag_id] = value
	current_character["event_flags"] = event_flags


func _ensure_runtime_state_defaults() -> void:
	if not current_character.has("past_life_id"):
		current_character["past_life_id"] = str(current_character.get("background_id", ""))
	if not current_character.has("past_life_name"):
		current_character["past_life_name"] = str(current_character.get("background_name", ""))
	if not current_character.has("background_id"):
		current_character["background_id"] = str(current_character.get("past_life_id", ""))
	if not current_character.has("background_name"):
		current_character["background_name"] = str(current_character.get("past_life_name", ""))
	if not current_character.has("reborn_job_id"):
		current_character["reborn_job_id"] = str(current_character.get("class_id", ""))
	if not current_character.has("reborn_job_name"):
		current_character["reborn_job_name"] = str(current_character.get("class_name", ""))
	if not current_character.has("class_id"):
		current_character["class_id"] = str(current_character.get("reborn_job_id", ""))
	if not current_character.has("class_name"):
		current_character["class_name"] = str(current_character.get("reborn_job_name", ""))
	if not current_character.has("trait_ids"):
		current_character["trait_ids"] = []
	if not current_character.has("trait_names"):
		current_character["trait_names"] = []
	if not current_character.has("strength_id"):
		current_character["strength_id"] = ""
	if not current_character.has("strength_name"):
		current_character["strength_name"] = ""
	if not current_character.has("weakness_id"):
		current_character["weakness_id"] = ""
	if not current_character.has("weakness_name"):
		current_character["weakness_name"] = ""
	if not current_character.has("personality_id"):
		current_character["personality_id"] = ""
	if not current_character.has("personality_name"):
		current_character["personality_name"] = ""
	if not current_character.has("profile_tags"):
		current_character["profile_tags"] = []
	if not current_character.has("granted_triggers"):
		current_character["granted_triggers"] = []
	if not current_character.has("event_flags"):
		current_character["event_flags"] = {}
	var skill_persistence: Dictionary = SkillRegistry.export_player_skill_persistence(
		SkillRegistry.build_player_skill_runtime(current_character)
	)
	if not current_character.has("owned_skill_ids"):
		current_character["owned_skill_ids"] = skill_persistence.get("owned_skill_ids", [])
	if not current_character.has("equipped_skill_ids"):
		current_character["equipped_skill_ids"] = skill_persistence.get("equipped_skill_ids", [])
	if not current_character.has("skill_state_overrides"):
		current_character["skill_state_overrides"] = {}
	if not current_character.has("skill_slot_count"):
		current_character["skill_slot_count"] = SkillRegistry.get_default_player_skill_slot_count()
