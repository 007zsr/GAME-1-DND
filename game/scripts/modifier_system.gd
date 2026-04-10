extends RefCounted
class_name ModifierSystem

const CHANNEL_FLAT := "flat"
const CHANNEL_ADD := "add"
const CHANNEL_MULT := "mult"

const STACK_BEHAVIOR_STACK := "stack"
const STACK_BEHAVIOR_OVERRIDE := "override"
const STACK_BEHAVIOR_EXCLUSIVE := "exclusive"

const TARGET_DEFINITIONS := {
	"a.strength": {"group": "a", "label": "力量", "format": "integer", "min": 0.0},
	"a.agility": {"group": "a", "label": "敏捷", "format": "integer", "min": 0.0},
	"a.intelligence": {"group": "a", "label": "智力", "format": "integer", "min": 0.0},
	"a.perception": {"group": "a", "label": "感知", "format": "integer", "min": 0.0},
	"a.fortitude": {"group": "a", "label": "坚韧", "format": "integer", "min": 0.0},
	"a.willpower": {"group": "a", "label": "意志", "format": "integer", "min": 0.0},
	"b.accuracy": {"group": "b", "label": "命中率", "format": "percent", "min": 0.0},
	"b.critical_rate": {"group": "b", "label": "暴击率", "format": "percent", "min": 0.0, "max": 100.0},
	"b.critical_damage": {"group": "b", "label": "暴击伤害", "format": "critical_damage", "min": 1.0},
	"b.evasion": {"group": "b", "label": "闪避率", "format": "percent", "min": 0.0, "max": 95.0},
	"b.health": {"group": "b", "label": "血量", "format": "integer", "min": 1.0},
	"b.attack_speed": {"group": "b", "label": "攻击速度", "format": "decimal2", "min": 0.1},
	"b.block_rate": {"group": "b", "label": "格挡率", "format": "percent", "min": 0.0, "max": 75.0},
	"b.damage_power": {"group": "b", "label": "伤害能力", "format": "decimal1", "min": 0.0},
	"b.magic_power": {"group": "b", "label": "魔力强度", "format": "decimal1", "min": 0.0},
	"b.move_speed": {"group": "b", "label": "移动速度", "format": "decimal2", "min": 0.1},
	"skill.slash_damage": {"group": "skill", "label": "斩击伤害", "format": "decimal1", "min": 0.0},
	"skill.slash_cooldown": {"group": "skill", "label": "斩击冷却", "format": "seconds2", "min": 0.1},
	"skill.slash_range": {"group": "skill", "label": "斩击范围", "format": "meters2", "min": 0.0},
	"skill.slash_hit_count": {"group": "skill", "label": "斩击命中数", "format": "integer", "min": 1.0},
	"combat.final_damage": {"group": "combat", "label": "最终伤害", "format": "decimal1", "min": 0.0},
	"combat.received_damage": {"group": "combat", "label": "受到伤害", "format": "decimal1", "min": 0.0},
	"combat.healing_done": {"group": "combat", "label": "治疗效果", "format": "decimal1", "min": 0.0},
	"combat.exp_multiplier": {"group": "combat", "label": "经验倍率", "format": "decimal2", "min": 0.0},
	"combat.drop_multiplier": {"group": "combat", "label": "掉落倍率", "format": "decimal2", "min": 0.0},
}


static func is_valid_target_key(target_key: String) -> bool:
	return TARGET_DEFINITIONS.has(target_key)


static func get_target_definition(target_key: String) -> Dictionary:
	if TARGET_DEFINITIONS.has(target_key):
		return (TARGET_DEFINITIONS[target_key] as Dictionary).duplicate(true)
	return {}


static func get_target_label(target_key: String) -> String:
	return str(get_target_definition(target_key).get("label", target_key))


static func get_channel_label(channel: String) -> String:
	match channel:
		CHANNEL_FLAT:
			return "甲类"
		CHANNEL_ADD:
			return "乙类"
		CHANNEL_MULT:
			return "丙类"
		_:
			return channel


static func build_modifier_source(source_id: String, source_name: String, source_type: String, raw_entries: Array, options: Dictionary = {}) -> Dictionary:
	var entries: Array[Dictionary] = []
	for raw_entry in raw_entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var normalized_entry := _normalize_modifier_entry(source_id, source_name, source_type, raw_entry)
		if not normalized_entry.is_empty():
			entries.append(normalized_entry)

	return {
		"source_id": source_id,
		"source_name": source_name,
		"source_type": source_type,
		"enabled": bool(options.get("enabled", true)),
		"stack_behavior": str(options.get("stack_behavior", STACK_BEHAVIOR_STACK)),
		"entries": entries,
	}


static func build_target_breakdown(target_key: String, base_value: float, modifier_sources: Variant) -> Dictionary:
	var entries := _collect_target_entries(target_key, modifier_sources)
	var flat_entries: Array[Dictionary] = []
	var add_entries: Array[Dictionary] = []
	var mult_entries: Array[Dictionary] = []

	var flat_total := 0.0
	var add_total := 0.0
	var mult_total := 1.0

	for entry in entries:
		match str(entry.get("channel", "")):
			CHANNEL_FLAT:
				flat_entries.append(entry)
				flat_total += float(entry.get("value", 0.0))
			CHANNEL_ADD:
				add_entries.append(entry)
				add_total += float(entry.get("value", 0.0))
			CHANNEL_MULT:
				mult_entries.append(entry)
				mult_total *= 1.0 + float(entry.get("value", 0.0))

	var unclamped_value := (base_value + flat_total) * (1.0 + add_total) * mult_total
	var clamped_value := clamp_target_value(target_key, unclamped_value)

	return {
		"target_key": target_key,
		"target_label": get_target_label(target_key),
		"base_value": base_value,
		"flat_total": flat_total,
		"add_total": add_total,
		"mult_total": mult_total,
		"final_value": clamped_value,
		"unclamped_value": unclamped_value,
		"is_clamped": absf(clamped_value - unclamped_value) >= 0.0001,
		"flat_entries": flat_entries,
		"add_entries": add_entries,
		"mult_entries": mult_entries,
		"all_entries": entries,
	}


static func clamp_target_value(target_key: String, value: float) -> float:
	var target_definition := get_target_definition(target_key)
	if target_definition.is_empty():
		return value
	if target_definition.has("min"):
		value = maxf(value, float(target_definition["min"]))
	if target_definition.has("max"):
		value = minf(value, float(target_definition["max"]))
	return value


static func format_target_value(target_key: String, value: float, signed: bool = false) -> String:
	var format_id := str(get_target_definition(target_key).get("format", "decimal2"))
	match format_id:
		"integer":
			return "%+d" % int(round(value)) if signed else "%d" % int(round(value))
		"percent":
			return "%+.1f%%" % value if signed else "%.1f%%" % value
		"critical_damage":
			var display_value := value * 100.0
			return "%+d%%" % int(round(display_value)) if signed else "%d%%" % int(round(display_value))
		"decimal1":
			return "%+.1f" % value if signed else "%.1f" % value
		"decimal2":
			return "%+.2f" % value if signed else "%.2f" % value
		"seconds2":
			return "%+.2f秒" % value if signed else "%.2f秒" % value
		"meters2":
			return "%+.2f米" % value if signed else "%.2f米" % value
		_:
			return "%+.2f" % value if signed else "%.2f" % value


static func format_channel_total(target_key: String, channel: String, value: float) -> String:
	match channel:
		CHANNEL_FLAT:
			return format_target_value(target_key, value, true)
		CHANNEL_ADD:
			return _format_percent_delta(value)
		CHANNEL_MULT:
			return "×%.2f" % value
		_:
			return str(value)


static func describe_entry(entry: Dictionary) -> String:
	var target_key := str(entry.get("target_key", ""))
	var channel := str(entry.get("channel", ""))
	var source_name := str(entry.get("source_name", entry.get("source_id", "未知来源")))
	var value := float(entry.get("value", 0.0))
	match channel:
		CHANNEL_FLAT:
			return "%s：%s %s" % [source_name, get_channel_label(channel), format_target_value(target_key, value, true)]
		CHANNEL_ADD:
			return "%s：%s %s" % [source_name, get_channel_label(channel), _format_percent_delta(value)]
		CHANNEL_MULT:
			return "%s：%s ×%.2f" % [source_name, get_channel_label(channel), 1.0 + value]
		_:
			return "%s：%s %s" % [source_name, get_channel_label(channel), str(value)]


static func build_breakdown_hover_detail_data(title: String, breakdown: Dictionary, options: Dictionary = {}) -> Dictionary:
	var target_key := str(breakdown.get("target_key", ""))
	var summary_lines: Array[String] = [
		"当前值：%s" % format_target_value(target_key, float(breakdown.get("final_value", 0.0))),
		"基础值：%s" % format_target_value(target_key, float(breakdown.get("base_value", 0.0))),
		"甲类合计：%s" % format_channel_total(target_key, CHANNEL_FLAT, float(breakdown.get("flat_total", 0.0))),
		"乙类合计：%s" % format_channel_total(target_key, CHANNEL_ADD, float(breakdown.get("add_total", 0.0))),
		"丙类合计：%s" % format_channel_total(target_key, CHANNEL_MULT, float(breakdown.get("mult_total", 1.0))),
	]

	var detail_lines: Array[String] = []
	for base_line in options.get("base_detail_lines", []):
		var line_text := str(base_line)
		if line_text != "":
			detail_lines.append(line_text)

	for entry in breakdown.get("flat_entries", []):
		detail_lines.append(describe_entry(entry))
	for entry in breakdown.get("add_entries", []):
		detail_lines.append(describe_entry(entry))
	for entry in breakdown.get("mult_entries", []):
		detail_lines.append(describe_entry(entry))

	if bool(breakdown.get("is_clamped", false)):
		detail_lines.append("结果钳制后：%s" % format_target_value(target_key, float(breakdown.get("final_value", 0.0))))

	detail_lines.append("最终值：%s" % format_target_value(target_key, float(breakdown.get("final_value", 0.0))))

	var result := {
		"title": title,
		"summary_lines": summary_lines,
		"detail_lines": detail_lines,
		"supports_shift": true,
	}
	if options.has("context_flags"):
		result["context_flags"] = (options["context_flags"] as Dictionary).duplicate(true)
	return result


static func _normalize_modifier_entry(source_id: String, source_name: String, source_type: String, raw_entry: Dictionary) -> Dictionary:
	var target_key := str(raw_entry.get("target_key", ""))
	var channel := str(raw_entry.get("channel", ""))
	if not is_valid_target_key(target_key):
		return {}
	if channel not in [CHANNEL_FLAT, CHANNEL_ADD, CHANNEL_MULT]:
		return {}

	return {
		"entry_id": str(raw_entry.get("entry_id", "%s:%s:%s" % [source_id, target_key, channel])),
		"source_id": source_id,
		"source_name": source_name,
		"source_type": source_type,
		"target_key": target_key,
		"channel": channel,
		"value": float(raw_entry.get("value", 0.0)),
		"enabled": bool(raw_entry.get("enabled", true)),
		"stack_behavior": str(raw_entry.get("stack_behavior", STACK_BEHAVIOR_STACK)),
		"stack_group": str(raw_entry.get("stack_group", "")),
	}


static func _collect_target_entries(target_key: String, modifier_sources: Variant) -> Array[Dictionary]:
	var stacked_entries: Array[Dictionary] = []
	var override_entries: Dictionary = {}
	var exclusive_entries: Dictionary = {}
	if typeof(modifier_sources) == TYPE_DICTIONARY:
		for source_id in modifier_sources.keys():
			var source_data: Variant = modifier_sources[source_id]
			_append_target_entries(stacked_entries, override_entries, exclusive_entries, target_key, source_data)
	elif typeof(modifier_sources) == TYPE_ARRAY:
		for source_data: Variant in modifier_sources:
			_append_target_entries(stacked_entries, override_entries, exclusive_entries, target_key, source_data)

	var entries: Array[Dictionary] = stacked_entries
	for override_entry in override_entries.values():
		entries.append((override_entry as Dictionary).duplicate(true))
	for exclusive_entry in exclusive_entries.values():
		entries.append((exclusive_entry as Dictionary).duplicate(true))
	return entries


static func _append_target_entries(stacked_entries: Array[Dictionary], override_entries: Dictionary, exclusive_entries: Dictionary, target_key: String, source_data: Variant) -> void:
	if typeof(source_data) != TYPE_DICTIONARY:
		return
	if not bool(source_data.get("enabled", true)):
		return
	for raw_entry in source_data.get("entries", []):
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		if not bool(entry.get("enabled", true)):
			continue
		if str(entry.get("target_key", "")) != target_key:
			continue
		var stack_behavior := str(entry.get("stack_behavior", STACK_BEHAVIOR_STACK))
		var stack_group := str(entry.get("stack_group", target_key))
		match stack_behavior:
			STACK_BEHAVIOR_OVERRIDE:
				override_entries[stack_group] = entry.duplicate(true)
			STACK_BEHAVIOR_EXCLUSIVE:
				if not exclusive_entries.has(stack_group):
					exclusive_entries[stack_group] = entry.duplicate(true)
			_:
				stacked_entries.append(entry.duplicate(true))


static func _format_percent_delta(value: float) -> String:
	return "%+.1f%%" % (value * 100.0)
