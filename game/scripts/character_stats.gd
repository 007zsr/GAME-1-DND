extends RefCounted
class_name CharacterStats

const ModifierSystem = preload("res://game/scripts/modifier_system.gd")

const A_STAT_ORDER := [
	{"key": "strength", "label": "\u529b\u91cf"},
	{"key": "agility", "label": "\u654f\u6377"},
	{"key": "intelligence", "label": "\u667a\u529b"},
	{"key": "perception", "label": "\u611f\u77e5"},
	{"key": "fortitude", "label": "\u575a\u97e7"},
	{"key": "willpower", "label": "\u610f\u5fd7"},
]

const B_STAT_ORDER := [
	{"key": "accuracy", "label": "\u547d\u4e2d\u7387"},
	{"key": "critical_rate", "label": "\u66b4\u51fb\u7387"},
	{"key": "critical_damage", "label": "\u66b4\u51fb\u4f24\u5bb3"},
	{"key": "evasion", "label": "\u95ea\u907f\u7387"},
	{"key": "health", "label": "\u8840\u91cf"},
	{"key": "attack_speed", "label": "\u653b\u51fb\u901f\u5ea6"},
	{"key": "block_rate", "label": "\u683c\u6321\u7387"},
	{"key": "damage_power", "label": "\u4f24\u5bb3\u80fd\u529b"},
	{"key": "magic_power", "label": "\u9b54\u529b\u5f3a\u5ea6"},
	{"key": "move_speed", "label": "\u79fb\u52a8\u901f\u5ea6"},
]

const FIXED_MOVE_SPEED := 8.0

const B_STAT_FORMULA_INFO := {
	"accuracy": {
		"formula": "公式：72 + 感知 × 2.4 + 敏捷 × 0.8",
		"sources": ["perception", "agility"],
	},
	"critical_rate": {
		"formula": "公式：4 + 敏捷 × 0.7 + 感知 × 0.5",
		"sources": ["agility", "perception"],
	},
	"critical_damage": {
		"formula": "公式：1.5 + 力量 × 0.03 + 智力 × 0.02",
		"sources": ["strength", "intelligence"],
	},
	"evasion": {
		"formula": "公式：3 + 敏捷 × 1.2 + 感知 × 0.35",
		"sources": ["agility", "perception"],
	},
	"health": {
		"formula": "公式：90 + 坚韧 × 14 + 力量 × 4 + 意志 × 3",
		"sources": ["fortitude", "strength", "willpower"],
	},
	"attack_speed": {
		"formula": "公式：0.85 + 敏捷 × 0.025 + 感知 × 0.01",
		"sources": ["agility", "perception"],
	},
	"block_rate": {
		"formula": "公式：5 + 坚韧 × 1.15 + 力量 × 0.45 + 意志 × 0.25",
		"sources": ["fortitude", "strength", "willpower"],
	},
	"damage_power": {
		"formula": "公式：5 + 力量 × 1.6 + 敏捷 × 0.5 + 感知 × 0.2",
		"sources": ["strength", "agility", "perception"],
	},
	"magic_power": {
		"formula": "公式：5 + 智力 × 1.8 + 感知 × 0.6 + 意志 × 0.5",
		"sources": ["intelligence", "perception", "willpower"],
	},
	"move_speed": {
		"formula": "固定值：2.00，不受 A 类属性影响",
		"sources": [],
	},
}


static func calculate_b_stats(a_stats: Dictionary) -> Dictionary:
	var strength: float = float(a_stats.get("strength", 0.0))
	var agility: float = float(a_stats.get("agility", 0.0))
	var intelligence: float = float(a_stats.get("intelligence", 0.0))
	var perception: float = float(a_stats.get("perception", 0.0))
	var fortitude: float = float(a_stats.get("fortitude", 0.0))
	var willpower: float = float(a_stats.get("willpower", 0.0))

	return {
		"accuracy": 72.0 + perception * 2.4 + agility * 0.8,
		"critical_rate": 4.0 + agility * 0.7 + perception * 0.5,
		"critical_damage": 1.5 + strength * 0.03 + intelligence * 0.02,
		"evasion": 3.0 + agility * 1.2 + perception * 0.35,
		"health": 90.0 + fortitude * 14.0 + strength * 4.0 + willpower * 3.0,
		"attack_speed": 0.85 + agility * 0.025 + perception * 0.01,
		"block_rate": 5.0 + fortitude * 1.15 + strength * 0.45 + willpower * 0.25,
		"damage_power": 5.0 + strength * 1.6 + agility * 0.5 + perception * 0.2,
		"magic_power": 5.0 + intelligence * 1.8 + perception * 0.6 + willpower * 0.5,
		"move_speed": FIXED_MOVE_SPEED,
	}


static func get_b_target_key(stat_key: String) -> String:
	return "b.%s" % stat_key


static func normalize_b_stats(a_stats: Dictionary, b_stats: Dictionary) -> Dictionary:
	var normalized: Dictionary = calculate_b_stats(a_stats)
	for stat_definition in B_STAT_ORDER:
		var stat_key: String = str(stat_definition["key"])
		if b_stats.has(stat_key):
			normalized[stat_key] = b_stats[stat_key]
	return normalized


static func format_b_stat_value(stat_key: String, stat_value: float) -> String:
	match stat_key:
		"health":
			return str(int(round(stat_value)))
		"critical_damage":
			return "%d%%" % int(round(stat_value * 100.0))
		"attack_speed", "move_speed":
			return "%.2f" % stat_value
		"damage_power", "magic_power":
			return "%.1f" % stat_value
		_:
			return "%.1f%%" % stat_value


static func get_a_stat_label(stat_key: String) -> String:
	for stat_definition in A_STAT_ORDER:
		if str(stat_definition["key"]) == stat_key:
			return str(stat_definition["label"])
	if stat_key == "level":
		return "等级"
	return stat_key


static func get_b_stat_label(stat_key: String) -> String:
	for stat_definition in B_STAT_ORDER:
		if str(stat_definition["key"]) == stat_key:
			return str(stat_definition["label"])
	return stat_key


static func build_b_stat_hover_detail_data(stat_key: String, current_b_stats: Dictionary, effective_a_stats: Dictionary, source_context: String = "") -> Dictionary:
	var derived_b_stats := calculate_b_stats(effective_a_stats)
	var derived_value := float(derived_b_stats.get(stat_key, 0.0))
	var breakdown := ModifierSystem.build_target_breakdown(get_b_target_key(stat_key), derived_value, [])
	breakdown["final_value"] = float(current_b_stats.get(stat_key, 0.0))
	breakdown["unclamped_value"] = breakdown["final_value"]
	breakdown["flat_total"] = breakdown["final_value"] - derived_value
	var formula_info: Dictionary = B_STAT_FORMULA_INFO.get(stat_key, {})
	return build_b_stat_hover_detail_from_breakdown(stat_key, breakdown, effective_a_stats, source_context, formula_info)


static func build_b_stat_hover_detail_from_breakdown(stat_key: String, breakdown: Dictionary, effective_a_stats: Dictionary, source_context: String = "", formula_info: Dictionary = {}) -> Dictionary:
	var base_detail_lines: Array[String] = []
	if formula_info.is_empty():
		formula_info = B_STAT_FORMULA_INFO.get(stat_key, {})

	if not formula_info.is_empty():
		var formula_text := str(formula_info.get("formula", ""))
		if formula_text != "":
			base_detail_lines.append(formula_text)
		var source_parts: Array[String] = []
		for source_key in formula_info.get("sources", []):
			var key_text := str(source_key)
			source_parts.append("%s %s" % [get_a_stat_label(key_text), _format_a_source_value(float(effective_a_stats.get(key_text, 0.0)))])
		if not source_parts.is_empty():
			base_detail_lines.append("A 类来源：%s" % "、".join(source_parts))

	var result := ModifierSystem.build_breakdown_hover_detail_data(
		get_b_stat_label(stat_key),
		breakdown,
		{
			"base_detail_lines": base_detail_lines,
		}
	)
	result["source_type"] = "attribute_b_entry"
	if source_context != "":
		result["context_flags"] = {"source_context": source_context}
	return result


static func _format_signed_b_stat_value(stat_key: String, stat_value: float) -> String:
	match stat_key:
		"health":
			return "%+d" % int(round(stat_value))
		"critical_damage":
			return "%+d%%" % int(round(stat_value * 100.0))
		"attack_speed", "move_speed":
			return "%+.2f" % stat_value
		"damage_power", "magic_power":
			return "%+.1f" % stat_value
		_:
			return "%+.1f%%" % stat_value


static func _format_a_source_value(stat_value: float) -> String:
	if absf(stat_value - round(stat_value)) < 0.001:
		return str(int(round(stat_value)))
	return "%.2f" % stat_value
