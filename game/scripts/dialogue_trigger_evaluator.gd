extends RefCounted
class_name DialogueTriggerEvaluator

const DialogueTriggerRegistryScript = preload("res://game/scripts/dialogue_trigger_registry.gd")


func get_trigger_definition(trigger_id: String) -> Dictionary:
	return DialogueTriggerRegistryScript.get_trigger(trigger_id)


func is_trigger_defined(trigger_id: String) -> bool:
	return DialogueTriggerRegistryScript.has_trigger(trigger_id)


func has_trigger(trigger_id: String, context: Dictionary) -> bool:
	if trigger_id == "":
		return false
	trigger_id = DialogueTriggerRegistryScript.get_canonical_trigger_id(trigger_id)

	var definition: Dictionary = get_trigger_definition(trigger_id)
	if definition.is_empty():
		push_warning("DialogueTriggerEvaluator[undefined_trigger] trigger_id=%s" % trigger_id)
		return false

	var obtain_mode: String = str(definition.get("obtain_mode", "derived"))
	if obtain_mode == "granted":
		return _has_granted_trigger(trigger_id, context)

	return _are_conditions_met(definition.get("acquire_conditions", []), context)


func build_hover_detail(trigger_id: String, context: Dictionary, base_tooltip: Dictionary = {}) -> Dictionary:
	var definition: Dictionary = get_trigger_definition(trigger_id)
	if definition.is_empty():
		return base_tooltip.duplicate(true)

	var detail_data := base_tooltip.duplicate(true)
	if str(detail_data.get("title", "")) == "":
		detail_data["title"] = str(definition.get("trigger_name", trigger_id))

	var summary_lines: Array = detail_data.get("summary_lines", []).duplicate()
	summary_lines.append("触发项：%s" % str(definition.get("trigger_name", trigger_id)))
	summary_lines.append("触发来源：%s" % str(definition.get("description", "")))
	detail_data["summary_lines"] = summary_lines

	var detail_lines: Array = detail_data.get("detail_lines", []).duplicate()
	detail_lines.append("trigger_id：%s" % trigger_id)
	detail_lines.append("source_type：%s" % str(definition.get("source_type", "")))
	detail_lines.append("obtain_mode：%s" % str(definition.get("obtain_mode", "")))
	detail_lines.append("当前是否成立：%s" % ("是" if has_trigger(trigger_id, context) else "否"))
	detail_data["detail_lines"] = detail_lines
	detail_data["supports_shift"] = true
	return detail_data


func _has_granted_trigger(trigger_id: String, context: Dictionary) -> bool:
	var game_state: Node = context.get("game_state")
	if game_state != null and game_state.has_method("has_granted_trigger"):
		return bool(game_state.has_granted_trigger(trigger_id))

	if game_state != null and "current_character" in game_state:
		for entry in game_state.current_character.get("granted_triggers", []):
			if str(entry) == trigger_id:
				return true
	return false


func _are_conditions_met(conditions: Variant, context: Dictionary) -> bool:
	if typeof(conditions) != TYPE_ARRAY:
		return false
	if (conditions as Array).is_empty():
		return true

	for raw_condition in conditions:
		if typeof(raw_condition) != TYPE_DICTIONARY:
			return false
		if not _is_condition_met(raw_condition as Dictionary, context):
			return false
	return true


func _is_condition_met(condition: Dictionary, context: Dictionary) -> bool:
	var condition_type: String = str(condition.get("type", ""))
	match condition_type:
		"", "always":
			return true
		"background_is", "past_life_is":
			return _get_background_id(context) == str(condition.get("value", ""))
		"class_is":
			return _get_class_id(context) == str(condition.get("value", ""))
		"has_tag":
			return _get_profile_tags(context).has(str(condition.get("value", "")))
		"trait_has":
			return _get_trait_ids(context).has(str(condition.get("value", "")))
		"strength_is":
			return _get_strength_id(context) == str(condition.get("value", ""))
		"weakness_is":
			return _get_weakness_id(context) == str(condition.get("value", ""))
		"personality_is":
			return _get_personality_id(context) == str(condition.get("value", ""))
		"stat_at_least":
			return _get_stat_value(context, str(condition.get("stat_key", ""))) >= float(condition.get("value", 0.0))
		"event_flag_is":
			return _get_event_flag(context, str(condition.get("flag_id", "")), false) == bool(condition.get("value", true))
		_:
			return false


func _get_background_id(context: Dictionary) -> String:
	var player: Node = context.get("player")
	if player != null and player.has_method("get_background_id"):
		return str(player.get_background_id())

	var game_state: Node = context.get("game_state")
	if game_state != null and "current_character" in game_state:
		return str(game_state.current_character.get("background_id", game_state.current_character.get("past_life_id", "")))
	return ""


func _get_class_id(context: Dictionary) -> String:
	var player: Node = context.get("player")
	if player != null and player.has_method("get_reborn_job_id"):
		return str(player.get_reborn_job_id())

	var game_state: Node = context.get("game_state")
	if game_state != null and "current_character" in game_state:
		return str(game_state.current_character.get("class_id", game_state.current_character.get("reborn_job_id", "")))
	return ""


func _get_profile_tags(context: Dictionary) -> Array[String]:
	var player: Node = context.get("player")
	if player != null and player.has_method("get_profile_tags"):
		return player.get_profile_tags()

	var results: Array[String] = []
	var game_state: Node = context.get("game_state")
	if game_state != null and "current_character" in game_state:
		for entry in game_state.current_character.get("profile_tags", []):
			results.append(str(entry))
	return results


func _get_trait_ids(context: Dictionary) -> Array[String]:
	var player: Node = context.get("player")
	if player != null and player.has_method("get_trait_ids"):
		return player.get_trait_ids()

	var results: Array[String] = []
	var game_state: Node = context.get("game_state")
	if game_state != null and "current_character" in game_state:
		for entry in game_state.current_character.get("trait_ids", []):
			results.append(str(entry))
	return results


func _get_strength_id(context: Dictionary) -> String:
	var player: Node = context.get("player")
	if player != null and player.has_method("get_strength_id"):
		return str(player.get_strength_id())

	var game_state: Node = context.get("game_state")
	if game_state != null and "current_character" in game_state:
		return str(game_state.current_character.get("strength_id", ""))
	return ""


func _get_weakness_id(context: Dictionary) -> String:
	var player: Node = context.get("player")
	if player != null and player.has_method("get_weakness_id"):
		return str(player.get_weakness_id())

	var game_state: Node = context.get("game_state")
	if game_state != null and "current_character" in game_state:
		return str(game_state.current_character.get("weakness_id", ""))
	return ""


func _get_personality_id(context: Dictionary) -> String:
	var player: Node = context.get("player")
	if player != null and player.has_method("get_personality_id"):
		return str(player.get_personality_id())

	var game_state: Node = context.get("game_state")
	if game_state != null and "current_character" in game_state:
		return str(game_state.current_character.get("personality_id", ""))
	return ""


func _get_stat_value(context: Dictionary, stat_key: String) -> float:
	if stat_key == "":
		return 0.0

	var player: Node = context.get("player")
	if player != null:
		if player.has_method("get_character_a_stats"):
			var a_stats: Dictionary = player.get_character_a_stats()
			if a_stats.has(stat_key):
				return float(a_stats.get(stat_key, 0.0))
		if player.has_method("get_character_b_stats"):
			var b_stats: Dictionary = player.get_character_b_stats()
			if b_stats.has(stat_key):
				return float(b_stats.get(stat_key, 0.0))

	var game_state: Node = context.get("game_state")
	if game_state != null and "current_character" in game_state:
		var current_character: Dictionary = game_state.current_character
		var a_stats_from_state: Dictionary = current_character.get("a_stats", {})
		if a_stats_from_state.has(stat_key):
			return float(a_stats_from_state.get(stat_key, 0.0))
		var b_stats_from_state: Dictionary = current_character.get("b_stats", {})
		if b_stats_from_state.has(stat_key):
			return float(b_stats_from_state.get(stat_key, 0.0))

	return 0.0


func _get_event_flag(context: Dictionary, flag_id: String, default_value: bool) -> bool:
	if flag_id == "":
		return default_value

	var game_state: Node = context.get("game_state")
	if game_state != null and game_state.has_method("get_event_flag"):
		return bool(game_state.get_event_flag(flag_id, default_value))
	if game_state != null and "current_character" in game_state:
		return bool((game_state.current_character.get("event_flags", {}) as Dictionary).get(flag_id, default_value))
	return default_value
