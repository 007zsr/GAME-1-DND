extends RefCounted
class_name DialogueConditionEvaluator

var trigger_evaluator = null


func configure(trigger_eval) -> void:
	trigger_evaluator = trigger_eval


func are_conditions_met(conditions: Array, context: Dictionary, log_context: Dictionary = {}, owner_data: Dictionary = {}) -> bool:
	if not _evaluate_trigger_requirements(owner_data, context, log_context):
		return false
	if conditions.is_empty():
		return true

	for raw_condition in conditions:
		if typeof(raw_condition) != TYPE_DICTIONARY:
			_warn("condition_entry_invalid", log_context, {"raw_condition": raw_condition})
			return false

		var condition: Dictionary = raw_condition
		if not _is_condition_met(condition, context, log_context):
			return false

	return true


func _is_condition_met(condition: Dictionary, context: Dictionary, log_context: Dictionary) -> bool:
	var condition_type: String = str(condition.get("type", ""))
	match condition_type:
		"", "always":
			return true
		"background_is", "past_life_is":
			return _get_background_id(context) == str(condition.get("value", ""))
		"background_in":
			return _array_contains_string(condition.get("values", []), _get_background_id(context))
		"class_is":
			return _get_class_id(context) == str(condition.get("value", ""))
		"has_tag":
			return _array_contains_string(_get_profile_tags(context), str(condition.get("value", "")))
		"trait_has":
			return _array_contains_string(_get_trait_ids(context), str(condition.get("value", "")))
		"strength_is":
			return _get_strength_id(context) == str(condition.get("value", ""))
		"weakness_is":
			return _get_weakness_id(context) == str(condition.get("value", ""))
		"personality_is":
			return _get_personality_id(context) == str(condition.get("value", ""))
		"flag_is":
			var dialogue_flag_id: String = str(condition.get("flag_id", ""))
			if dialogue_flag_id == "":
				_warn("flag_condition_missing_flag_id", log_context, condition)
				return false
			return bool(_get_dialogue_flags(context).get(dialogue_flag_id, false)) == bool(condition.get("value", true))
		"event_flag_is":
			var event_flag_id: String = str(condition.get("flag_id", ""))
			if event_flag_id == "":
				_warn("event_flag_condition_missing_flag_id", log_context, condition)
				return false
			return _get_event_flag(context, event_flag_id, false) == bool(condition.get("value", true))
		"stat_at_least":
			var stat_key := str(condition.get("stat_key", ""))
			if stat_key == "":
				_warn("stat_condition_missing_stat_key", log_context, condition)
				return false
			return _get_stat_value(context, stat_key) >= float(condition.get("value", 0.0))
		"trigger_has":
			return _require_trigger(str(condition.get("trigger_id", "")), context, log_context, condition)
		"requires_trigger":
			return _require_trigger(str(condition.get("trigger_id", "")), context, log_context, condition)
		"trigger_missing":
			return _forbid_trigger(str(condition.get("trigger_id", "")), context, log_context, condition)
		"forbid_trigger":
			return _forbid_trigger(str(condition.get("trigger_id", "")), context, log_context, condition)
		_:
			_warn("unknown_condition_type", log_context, condition)
			return false


func _evaluate_trigger_requirements(owner_data: Dictionary, context: Dictionary, log_context: Dictionary) -> bool:
	for trigger_id in _coerce_trigger_list(owner_data.get("requires_trigger", [])):
		if not _require_trigger(trigger_id, context, log_context, owner_data):
			return false
	for trigger_id in _coerce_trigger_list(owner_data.get("forbid_trigger", [])):
		if not _forbid_trigger(trigger_id, context, log_context, owner_data):
			return false
	return true


func _require_trigger(trigger_id: String, context: Dictionary, log_context: Dictionary, extra: Variant) -> bool:
	if trigger_id == "":
		_warn("trigger_condition_missing_trigger_id", log_context, extra)
		return false
	if trigger_evaluator == null:
		_warn("trigger_evaluator_missing", log_context, extra)
		return false
	if not trigger_evaluator.is_trigger_defined(trigger_id):
		_warn("trigger_not_defined", log_context, {"trigger_id": trigger_id})
		return false
	return bool(trigger_evaluator.has_trigger(trigger_id, context))


func _forbid_trigger(trigger_id: String, context: Dictionary, log_context: Dictionary, extra: Variant) -> bool:
	if trigger_id == "":
		_warn("trigger_condition_missing_trigger_id", log_context, extra)
		return false
	if trigger_evaluator == null:
		_warn("trigger_evaluator_missing", log_context, extra)
		return false
	if not trigger_evaluator.is_trigger_defined(trigger_id):
		_warn("trigger_not_defined", log_context, {"trigger_id": trigger_id})
		return false
	return not bool(trigger_evaluator.has_trigger(trigger_id, context))


func _coerce_trigger_list(raw_value: Variant) -> Array[String]:
	var results: Array[String] = []
	match typeof(raw_value):
		TYPE_STRING:
			if str(raw_value) != "":
				results.append(str(raw_value))
		TYPE_ARRAY:
			for entry in raw_value:
				var trigger_id := str(entry)
				if trigger_id != "":
					results.append(trigger_id)
	return results


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

	var tags: Array[String] = []
	var game_state: Node = context.get("game_state")
	if game_state != null and "current_character" in game_state:
		for entry in game_state.current_character.get("profile_tags", []):
			tags.append(str(entry))
	return tags


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


func _get_dialogue_flags(context: Dictionary) -> Dictionary:
	var manager: Node = context.get("dialogue_manager")
	if manager != null and manager.has_method("get_dialogue_flags"):
		return manager.get_dialogue_flags()
	return {}


func _get_event_flag(context: Dictionary, flag_id: String, default_value: bool) -> bool:
	var game_state: Node = context.get("game_state")
	if game_state != null and game_state.has_method("get_event_flag"):
		return bool(game_state.get_event_flag(flag_id, default_value))
	if game_state != null and "current_character" in game_state:
		return bool((game_state.current_character.get("event_flags", {}) as Dictionary).get(flag_id, default_value))
	return default_value


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


func _array_contains_string(values: Variant, target: String) -> bool:
	if typeof(values) != TYPE_ARRAY:
		return false

	for entry in values:
		if str(entry) == target:
			return true
	return false


func _warn(code: String, log_context: Dictionary, extra: Variant = null) -> void:
	var dialogue_id: String = str(log_context.get("dialogue_id", ""))
	var node_id: String = str(log_context.get("node_id", ""))
	var option_id: String = str(log_context.get("option_id", ""))
	push_warning(
		"DialogueConditionEvaluator[%s] dialogue_id=%s node_id=%s option_id=%s extra=%s" % [
			code,
			dialogue_id,
			node_id,
			option_id,
			str(extra),
		]
	)
