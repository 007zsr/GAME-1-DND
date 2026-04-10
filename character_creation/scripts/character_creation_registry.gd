extends RefCounted
class_name CharacterCreationRegistry

const CharacterStats = preload("res://game/scripts/character_stats.gd")

const DEFAULT_LEVEL := 1
const DEFAULT_BONUS_POINTS := 8
const DEFAULT_REBORN_JOB_ID := "warrior"

const PAST_LIVES := {
	"student": {
		"id": "student",
		"display_name": "学生",
		"summary": "还在学习世界的规则，吸收信息更快。",
		"description": "长期处在考试、课程与适应变化的节奏里，更容易理解知识、线索与规则类内容。",
		"a_modifiers": {
			"intelligence": 2,
			"perception": 1,
			"willpower": 1,
			"strength": -1,
		},
	},
	"worker": {
		"id": "worker",
		"display_name": "打工人",
		"summary": "习惯承压、执行与撑完整个流程。",
		"description": "长期处在重复任务和现实压力里，更熟悉节奏管理、工作要求与忍耐成本。",
		"a_modifiers": {
			"fortitude": 2,
			"perception": 1,
			"willpower": 1,
			"agility": -1,
		},
	},
	"esports": {
		"id": "esports",
		"display_name": "电竞选手",
		"summary": "依赖反应、判断与瞬时操作活着。",
		"description": "更擅长在高压信息流里做出即时判断，对战局变化和节奏切换更敏感。",
		"a_modifiers": {
			"agility": 2,
			"perception": 1,
			"intelligence": 1,
			"fortitude": -1,
		},
	},
	"courier": {
		"id": "courier",
		"display_name": "外卖员",
		"summary": "熟悉赶路、找路与顶着时限移动。",
		"description": "更擅长判断路线、位移节奏与时间压力下的行动安排。",
		"a_modifiers": {
			"agility": 2,
			"fortitude": 1,
			"perception": 1,
			"intelligence": -1,
		},
	},
	"idle": {
		"id": "idle",
		"display_name": "无业游民",
		"summary": "看似游离在秩序之外，却更会观察缝隙。",
		"description": "长期在有限资源里打转，更容易留意环境异常、可乘之机与低成本生存方式。",
		"a_modifiers": {
			"perception": 2,
			"agility": 1,
			"willpower": -1,
			"fortitude": -1,
		},
	},
}

const TRAITS := {
	"eager_learner": {
		"id": "eager_learner",
		"display_name": "求知欲",
		"summary": "更愿意吸收信息与新方法。",
		"category": "职业相关特性",
		"allowed_past_lives": ["student"],
		"a_modifiers": {
			"intelligence": 1,
		},
	},
	"exam_memory": {
		"id": "exam_memory",
		"display_name": "应试记忆",
		"summary": "更擅长短时记忆与快速提取信息。",
		"category": "职业相关特性",
		"allowed_past_lives": ["student"],
		"a_modifiers": {
			"perception": 1,
		},
	},
	"pressure_inertia": {
		"id": "pressure_inertia",
		"display_name": "抗压惯性",
		"summary": "面对重复任务和持续压力时，更不容易先崩掉。",
		"category": "职业相关特性",
		"allowed_past_lives": ["worker"],
		"a_modifiers": {
			"willpower": 1,
		},
	},
	"process_familiarity": {
		"id": "process_familiarity",
		"display_name": "流程熟练",
		"summary": "对固定流程、执行要求与问题节点更敏感。",
		"category": "职业相关特性",
		"allowed_past_lives": ["worker"],
		"a_modifiers": {
			"perception": 1,
		},
	},
	"rapid_response": {
		"id": "rapid_response",
		"display_name": "高速反应",
		"summary": "更擅长瞬时判断与操作反应。",
		"category": "职业相关特性",
		"allowed_past_lives": ["esports"],
		"a_modifiers": {
			"agility": 1,
		},
	},
	"momentum_read": {
		"id": "momentum_read",
		"display_name": "局势判断",
		"summary": "更容易捕捉战局变化与节奏拐点。",
		"category": "职业相关特性",
		"allowed_past_lives": ["esports"],
		"a_modifiers": {
			"perception": 1,
		},
	},
	"route_instinct": {
		"id": "route_instinct",
		"display_name": "路线直觉",
		"summary": "更容易判断路径、拐点与位移节奏。",
		"category": "职业相关特性",
		"allowed_past_lives": ["courier"],
		"a_modifiers": {
			"agility": 1,
		},
	},
	"race_against_time": {
		"id": "race_against_time",
		"display_name": "争分夺秒",
		"summary": "在时间压力下也更容易保持行动。",
		"category": "职业相关特性",
		"allowed_past_lives": ["courier"],
		"a_modifiers": {
			"willpower": 1,
		},
	},
	"idle_observer": {
		"id": "idle_observer",
		"display_name": "闲散观察",
		"summary": "更容易注意环境里的异常、缝隙与机会。",
		"category": "职业相关特性",
		"allowed_past_lives": ["idle"],
		"a_modifiers": {
			"perception": 1,
		},
	},
	"low_cost_survival": {
		"id": "low_cost_survival",
		"display_name": "低成本生存",
		"summary": "更擅长在资源紧张时维持基本状态。",
		"category": "职业相关特性",
		"allowed_past_lives": ["idle"],
		"a_modifiers": {
			"fortitude": 1,
		},
	},
	"observant": {
		"id": "observant",
		"display_name": "观察入微",
		"summary": "更容易捕捉细节与异常。",
		"category": "通用特性",
		"a_modifiers": {
			"perception": 1,
		},
	},
	"steady_breathing": {
		"id": "steady_breathing",
		"display_name": "呼吸平稳",
		"summary": "面对压力时更能维持状态。",
		"category": "通用特性",
		"a_modifiers": {
			"willpower": 1,
		},
	},
	"nimble_steps": {
		"id": "nimble_steps",
		"display_name": "步伐轻快",
		"summary": "移动与调整动作更灵活。",
		"category": "通用特性",
		"a_modifiers": {
			"agility": 1,
		},
	},
}

const STRENGTHS := {
	"keen_senses": {
		"id": "keen_senses",
		"display_name": "敏锐感官",
		"summary": "总能更早发现异常。",
		"a_modifiers": {
			"perception": 2,
		},
	},
	"sturdy_frame": {
		"id": "sturdy_frame",
		"display_name": "结实体格",
		"summary": "更能承受正面冲击。",
		"a_modifiers": {
			"fortitude": 2,
		},
	},
	"quick_hands": {
		"id": "quick_hands",
		"display_name": "动作利落",
		"summary": "更擅长快速出手与调整。",
		"a_modifiers": {
			"agility": 2,
		},
	},
	"iron_will": {
		"id": "iron_will",
		"display_name": "意志坚定",
		"summary": "更难在压力中动摇。",
		"a_modifiers": {
			"willpower": 2,
		},
	},
}

const WEAKNESSES := {
	"frail": {
		"id": "frail",
		"display_name": "体格单薄",
		"summary": "承压能力略差。",
		"a_modifiers": {
			"fortitude": -1,
		},
	},
	"impulsive": {
		"id": "impulsive",
		"display_name": "容易急躁",
		"summary": "判断容易被情绪带偏。",
		"a_modifiers": {
			"willpower": -1,
		},
	},
	"bookish": {
		"id": "bookish",
		"display_name": "纸上谈兵",
		"summary": "动手与临场反应偏慢。",
		"a_modifiers": {
			"agility": -1,
		},
	},
	"short_sighted": {
		"id": "short_sighted",
		"display_name": "忽略细节",
		"summary": "容易漏看环境线索。",
		"a_modifiers": {
			"perception": -1,
		},
	},
}

const PERSONALITIES := {
	"calm": {
		"id": "calm",
		"display_name": "冷静",
		"summary": "处理信息时更偏稳妥分析。",
		"a_modifiers": {
			"willpower": 1,
		},
	},
	"bold": {
		"id": "bold",
		"display_name": "大胆",
		"summary": "更愿意先手尝试与承担风险。",
		"a_modifiers": {
			"strength": 1,
		},
	},
	"compassionate": {
		"id": "compassionate",
		"display_name": "仁厚",
		"summary": "更重视他人的状态与反应。",
		"a_modifiers": {
			"intelligence": 1,
		},
	},
	"cautious": {
		"id": "cautious",
		"display_name": "谨慎",
		"summary": "更常提前评估风险与退路。",
		"a_modifiers": {
			"perception": 1,
		},
	},
	"curious": {
		"id": "curious",
		"display_name": "好奇",
		"summary": "更愿意探究异常与未知。",
		"a_modifiers": {
			"intelligence": 1,
		},
	},
	"stubborn": {
		"id": "stubborn",
		"display_name": "固执",
		"summary": "不轻易改变决定。",
		"a_modifiers": {
			"fortitude": 1,
		},
	},
}

const REBORN_JOBS := {
	"warrior": {
		"id": "warrior",
		"display_name": "战士",
		"description": "前排近战职业，拥有较强的生存能力和稳定输出。",
		"base_a": {
			"strength": 8,
			"agility": 5,
			"intelligence": 3,
			"perception": 4,
			"fortitude": 7,
			"willpower": 5,
		},
		"bonus_points": DEFAULT_BONUS_POINTS,
		"starting_skills": [
			{
				"id": "slash_skill",
				"display_name": "斩击",
				"summary": "范围内有敌人时自动触发，造成近身斩击伤害。",
			},
		],
	},
}


static func get_past_life_ids() -> Array[String]:
	return _dictionary_keys_as_strings(PAST_LIVES)


static func get_trait_ids() -> Array[String]:
	return _dictionary_keys_as_strings(TRAITS)


static func get_strength_ids() -> Array[String]:
	return _dictionary_keys_as_strings(STRENGTHS)


static func get_weakness_ids() -> Array[String]:
	return _dictionary_keys_as_strings(WEAKNESSES)


static func get_personality_ids() -> Array[String]:
	return _dictionary_keys_as_strings(PERSONALITIES)


static func get_reborn_job_ids() -> Array[String]:
	return _dictionary_keys_as_strings(REBORN_JOBS)


static func get_default_reborn_job_id() -> String:
	return DEFAULT_REBORN_JOB_ID


static func get_default_level() -> int:
	return DEFAULT_LEVEL


static func get_past_life(past_life_id: String) -> Dictionary:
	return _duplicate_entry(PAST_LIVES, past_life_id)


static func get_trait(trait_id: String) -> Dictionary:
	return _duplicate_entry(TRAITS, trait_id)


static func get_strength(strength_id: String) -> Dictionary:
	return _duplicate_entry(STRENGTHS, strength_id)


static func get_weakness(weakness_id: String) -> Dictionary:
	return _duplicate_entry(WEAKNESSES, weakness_id)


static func get_personality(personality_id: String) -> Dictionary:
	return _duplicate_entry(PERSONALITIES, personality_id)


static func get_reborn_job(job_id: String) -> Dictionary:
	return _duplicate_entry(REBORN_JOBS, job_id)


static func get_selection_config(selection_type: String, selection_id: String) -> Dictionary:
	match selection_type:
		"past_life":
			return get_past_life(selection_id)
		"trait":
			return get_trait(selection_id)
		"strength":
			return get_strength(selection_id)
		"weakness":
			return get_weakness(selection_id)
		"personality":
			return get_personality(selection_id)
		"reborn_job":
			return get_reborn_job(selection_id)
	return {}


static func is_trait_available_for_past_life(trait_id: String, past_life_id: String) -> bool:
	var trait_config: Dictionary = get_trait(trait_id)
	if trait_config.is_empty():
		return false
	var allowed_past_lives: Array = trait_config.get("allowed_past_lives", [])
	if allowed_past_lives.is_empty():
		return true
	for allowed_id in allowed_past_lives:
		if str(allowed_id) == past_life_id:
			return true
	return false


static func get_available_trait_ids_for_past_life(past_life_id: String) -> Array[String]:
	var available_ids: Array[String] = []
	for trait_id in get_trait_ids():
		if is_trait_available_for_past_life(trait_id, past_life_id):
			available_ids.append(trait_id)
	return available_ids


static func get_reborn_job_base_a(job_id: String) -> Dictionary:
	var job_config: Dictionary = get_reborn_job(job_id)
	return (job_config.get("base_a", {}) as Dictionary).duplicate(true)


static func get_reborn_job_bonus_points(job_id: String) -> int:
	var job_config: Dictionary = get_reborn_job(job_id)
	return int(job_config.get("bonus_points", DEFAULT_BONUS_POINTS))


static func get_reborn_job_starting_skills(job_id: String) -> Array[Dictionary]:
	var skills: Array[Dictionary] = []
	var job_config: Dictionary = get_reborn_job(job_id)
	for entry in job_config.get("starting_skills", []):
		if typeof(entry) == TYPE_DICTIONARY:
			skills.append((entry as Dictionary).duplicate(true))
	return skills


static func build_profile_tags(selection_state: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	var past_life_id := str(selection_state.get("past_life_id", ""))
	if past_life_id != "":
		tags.append(past_life_id)
	for trait_id in selection_state.get("trait_ids", []):
		tags.append("trait_%s" % str(trait_id))
	var strength_id := str(selection_state.get("strength_id", ""))
	if strength_id != "":
		tags.append("strength_%s" % strength_id)
	var weakness_id := str(selection_state.get("weakness_id", ""))
	if weakness_id != "":
		tags.append("weakness_%s" % weakness_id)
	var personality_id := str(selection_state.get("personality_id", ""))
	if personality_id != "":
		tags.append("personality_%s" % personality_id)
	return tags


static func build_selection_a_modifiers(selection_state: Dictionary) -> Dictionary:
	var totals := {
		"strength": 0,
		"agility": 0,
		"intelligence": 0,
		"perception": 0,
		"fortitude": 0,
		"willpower": 0,
	}
	_apply_stat_modifier_totals(totals, get_past_life(str(selection_state.get("past_life_id", ""))).get("a_modifiers", {}))
	for trait_id in selection_state.get("trait_ids", []):
		_apply_stat_modifier_totals(totals, get_trait(str(trait_id)).get("a_modifiers", {}))
	_apply_stat_modifier_totals(totals, get_strength(str(selection_state.get("strength_id", ""))).get("a_modifiers", {}))
	_apply_stat_modifier_totals(totals, get_weakness(str(selection_state.get("weakness_id", ""))).get("a_modifiers", {}))
	_apply_stat_modifier_totals(totals, get_personality(str(selection_state.get("personality_id", ""))).get("a_modifiers", {}))
	return totals


static func build_preview_summary(selection_state: Dictionary) -> Dictionary:
	return {
		"past_life_name": get_past_life(str(selection_state.get("past_life_id", ""))).get("display_name", "未选择"),
		"trait_names": _collect_display_names(selection_state.get("trait_ids", []), TRAITS),
		"strength_name": get_strength(str(selection_state.get("strength_id", ""))).get("display_name", "未选择"),
		"weakness_name": get_weakness(str(selection_state.get("weakness_id", ""))).get("display_name", "未选择"),
		"personality_name": get_personality(str(selection_state.get("personality_id", ""))).get("display_name", "未选择"),
		"reborn_job_name": get_reborn_job(str(selection_state.get("reborn_job_id", ""))).get("display_name", "未选择"),
	}


static func build_selection_hover_detail(selection_type: String, selection_id: String, _selection_state: Dictionary = {}) -> Dictionary:
	var config := get_selection_config(selection_type, selection_id)
	if config.is_empty():
		return {}

	var title := str(config.get("display_name", selection_id))
	var summary_text := str(config.get("summary", config.get("description", "")))
	var description_text := str(config.get("description", ""))
	var summary_lines: Array[String] = []
	var detail_lines: Array[String] = []
	var modifier_summary_parts: Array[String] = []

	if summary_text != "":
		summary_lines.append(summary_text)
	if description_text != "" and description_text != summary_text:
		detail_lines.append(description_text)

	var modifier_lines := _build_modifier_lines(config.get("a_modifiers", {}))
	for modifier_line in modifier_lines:
		var summary_part := str(modifier_line.get("summary", ""))
		var detail_part := str(modifier_line.get("detail", ""))
		if summary_part != "":
			modifier_summary_parts.append(summary_part)
		if detail_part != "":
			detail_lines.append(detail_part)

	if not modifier_summary_parts.is_empty():
		summary_lines.append("属性变化：" + "，".join(modifier_summary_parts))
	else:
		summary_lines.append("当前不直接改动 A 类属性。")

	return {
		"title": title,
		"summary_lines": summary_lines,
		"detail_lines": detail_lines,
		"supports_shift": true,
		"summary_min_width": 240.0,
		"summary_max_width": 320.0,
		"detail_min_width": 300.0,
		"detail_max_width": 420.0,
	}


static func _collect_display_names(ids: Variant, source_map: Dictionary) -> Array[String]:
	var names: Array[String] = []
	if typeof(ids) != TYPE_ARRAY:
		return names
	for entry in ids:
		var entry_id := str(entry)
		if source_map.has(entry_id):
			names.append(str((source_map[entry_id] as Dictionary).get("display_name", entry_id)))
	return names


static func _apply_stat_modifier_totals(target: Dictionary, modifier_data: Variant) -> void:
	if typeof(modifier_data) != TYPE_DICTIONARY:
		return
	for stat_key in modifier_data.keys():
		var normalized_key := str(stat_key)
		target[normalized_key] = int(target.get(normalized_key, 0)) + int((modifier_data as Dictionary).get(stat_key, 0))


static func _duplicate_entry(source_map: Dictionary, entry_id: String) -> Dictionary:
	if not source_map.has(entry_id):
		return {}
	return (source_map[entry_id] as Dictionary).duplicate(true)


static func _dictionary_keys_as_strings(source_map: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for entry_key in source_map.keys():
		keys.append(str(entry_key))
	return keys


static func _build_modifier_lines(modifier_data: Variant) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if typeof(modifier_data) != TYPE_DICTIONARY:
		return lines

	for stat_definition in CharacterStats.A_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		if not (modifier_data as Dictionary).has(stat_key):
			continue
		var delta_value := int((modifier_data as Dictionary).get(stat_key, 0))
		if delta_value == 0:
			continue
		lines.append({
			"summary": "%s %s" % [CharacterStats.get_a_stat_label(stat_key), _format_signed_int(delta_value)],
			"detail": "%s：%s" % [CharacterStats.get_a_stat_label(stat_key), _format_signed_int(delta_value)],
		})
	return lines


static func _format_signed_int(value: int) -> String:
	return "%+d" % value
