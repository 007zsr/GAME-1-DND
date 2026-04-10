extends RefCounted
class_name DialogueTriggerRegistry

const CharacterCreationRegistry = preload("res://character_creation/scripts/character_creation_registry.gd")

const LEGACY_TRIGGER_ALIASES := {
	"stat_perception_high": "stat_perception_ge_10",
	"choice_asked_about_classroom": "asked_about_old_classroom",
	"story_finished_intro_room": "finished_goddess_intro_dialogue",
}

const STATIC_TRIGGERS := {
	"stat_perception_ge_10": {
		"trigger_id": "stat_perception_ge_10",
		"trigger_name": "高感知",
		"trigger_type": "attribute",
		"source_type": "attribute_threshold",
		"obtain_mode": "derived",
		"description": "感知达到 10 或以上时自动成立。",
		"acquire_conditions": [
			{"type": "stat_at_least", "stat_key": "perception", "value": 10},
		],
		"used_in_dialogues": [],
		"used_in_nodes": [],
		"used_for_options": [],
	},
	"asked_about_old_classroom": {
		"trigger_id": "asked_about_old_classroom",
		"trigger_name": "问过旧教室",
		"trigger_type": "choice",
		"source_type": "historical_choice",
		"obtain_mode": "granted",
		"description": "旧出生房测试引导的兼容历史标记。",
		"acquire_conditions": [],
		"used_in_dialogues": [],
		"used_in_nodes": [],
		"used_for_options": [],
	},
	"finished_goddess_intro_dialogue": {
		"trigger_id": "finished_goddess_intro_dialogue",
		"trigger_name": "完成复活女神引导",
		"trigger_type": "story",
		"source_type": "story_progress",
		"obtain_mode": "granted",
		"description": "完成复活女神在出生房的首轮引导后授予。",
		"acquire_conditions": [],
		"used_in_dialogues": ["spawn_goddess_intro"],
		"used_in_nodes": ["awakening", "trial_briefing"],
		"used_for_options": ["accept_resurrection", "begin_trial"],
	},
	"finished_intro_villager_dialogue": {
		"trigger_id": "finished_intro_villager_dialogue",
		"trigger_name": "完成出生房引导对话",
		"trigger_type": "story",
		"source_type": "story_progress",
		"obtain_mode": "granted",
		"description": "旧出生房引导完成标记，当前由复活女神动作层兼容写入。",
		"acquire_conditions": [],
		"used_in_dialogues": ["spawn_goddess_intro"],
		"used_in_nodes": ["awakening", "trial_briefing"],
		"used_for_options": [],
	},
}

const TRIGGER_USAGE_OVERRIDES := {
	"bg_student": {
		"used_in_dialogues": ["spawn_goddess_intro"],
		"used_in_nodes": ["awakening"],
		"used_for_options": [],
	},
	"bg_worker": {
		"used_in_dialogues": ["spawn_goddess_intro"],
		"used_in_nodes": ["awakening"],
		"used_for_options": [],
	},
	"bg_esports": {
		"used_in_dialogues": ["spawn_goddess_intro"],
		"used_in_nodes": ["awakening"],
		"used_for_options": [],
	},
	"bg_courier": {
		"used_in_dialogues": ["spawn_goddess_intro"],
		"used_in_nodes": ["awakening"],
		"used_for_options": [],
	},
	"bg_idle": {
		"used_in_dialogues": ["spawn_goddess_intro"],
		"used_in_nodes": ["awakening"],
		"used_for_options": [],
	},
}


static func get_trigger(trigger_id: String) -> Dictionary:
	trigger_id = get_canonical_trigger_id(trigger_id)
	var triggers := _build_trigger_map()
	if not triggers.has(trigger_id):
		return {}
	return (triggers[trigger_id] as Dictionary).duplicate(true)


static func has_trigger(trigger_id: String) -> bool:
	return not get_trigger(trigger_id).is_empty()


static func get_canonical_trigger_id(trigger_id: String) -> String:
	if LEGACY_TRIGGER_ALIASES.has(trigger_id):
		return str(LEGACY_TRIGGER_ALIASES[trigger_id])
	return trigger_id


static func get_all_trigger_ids() -> Array[String]:
	var trigger_ids: Array[String] = []
	var triggers := _build_trigger_map()
	for trigger_id in triggers.keys():
		trigger_ids.append(str(trigger_id))
	return trigger_ids


static func _build_trigger_map() -> Dictionary:
	var triggers := STATIC_TRIGGERS.duplicate(true)

	for past_life_id in CharacterCreationRegistry.get_past_life_ids():
		var trigger_id := "bg_%s" % past_life_id
		triggers[trigger_id] = _build_simple_trigger(
			trigger_id,
			"%s前世" % str(CharacterCreationRegistry.get_past_life(past_life_id).get("display_name", past_life_id)),
			"past_life",
			"background",
			[{"type": "background_is", "value": past_life_id}],
			"由正式前世职业字段实时派生。"
		)
		_apply_usage_override(triggers[trigger_id] as Dictionary, trigger_id)

	for trait_id in CharacterCreationRegistry.get_trait_ids():
		var trait_trigger_id := "trait_%s" % trait_id
		triggers[trait_trigger_id] = _build_simple_trigger(
			trait_trigger_id,
			"%s特性" % str(CharacterCreationRegistry.get_trait(trait_id).get("display_name", trait_id)),
			"trait",
			"trait",
			[{"type": "trait_has", "value": trait_id}],
			"由正式特性列表实时派生。"
		)

	for strength_id in CharacterCreationRegistry.get_strength_ids():
		var strength_trigger_id := "strength_%s" % strength_id
		triggers[strength_trigger_id] = _build_simple_trigger(
			strength_trigger_id,
			"%s特长" % str(CharacterCreationRegistry.get_strength(strength_id).get("display_name", strength_id)),
			"strength",
			"strength",
			[{"type": "strength_is", "value": strength_id}],
			"由正式特长字段实时派生。"
		)

	for weakness_id in CharacterCreationRegistry.get_weakness_ids():
		var weakness_trigger_id := "weakness_%s" % weakness_id
		triggers[weakness_trigger_id] = _build_simple_trigger(
			weakness_trigger_id,
			"%s缺点" % str(CharacterCreationRegistry.get_weakness(weakness_id).get("display_name", weakness_id)),
			"weakness",
			"weakness",
			[{"type": "weakness_is", "value": weakness_id}],
			"由正式缺点字段实时派生。"
		)

	for personality_id in CharacterCreationRegistry.get_personality_ids():
		var personality_trigger_id := "personality_%s" % personality_id
		triggers[personality_trigger_id] = _build_simple_trigger(
			personality_trigger_id,
			"%s性格" % str(CharacterCreationRegistry.get_personality(personality_id).get("display_name", personality_id)),
			"personality",
			"personality",
			[{"type": "personality_is", "value": personality_id}],
			"由正式性格字段实时派生。"
		)

	return triggers


static func _build_simple_trigger(trigger_id: String, trigger_name: String, trigger_type: String, source_type: String, acquire_conditions: Array, description: String) -> Dictionary:
	return {
		"trigger_id": trigger_id,
		"trigger_name": trigger_name,
		"trigger_type": trigger_type,
		"source_type": source_type,
		"obtain_mode": "derived",
		"description": description,
		"acquire_conditions": acquire_conditions.duplicate(true),
		"used_in_dialogues": [],
		"used_in_nodes": [],
		"used_for_options": [],
	}


static func _apply_usage_override(trigger_definition: Dictionary, trigger_id: String) -> void:
	if not TRIGGER_USAGE_OVERRIDES.has(trigger_id):
		return
	var override_data: Dictionary = TRIGGER_USAGE_OVERRIDES[trigger_id]
	trigger_definition["used_in_dialogues"] = (override_data.get("used_in_dialogues", []) as Array).duplicate()
	trigger_definition["used_in_nodes"] = (override_data.get("used_in_nodes", []) as Array).duplicate()
	trigger_definition["used_for_options"] = (override_data.get("used_for_options", []) as Array).duplicate()
