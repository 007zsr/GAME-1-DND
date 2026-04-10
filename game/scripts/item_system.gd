extends RefCounted
class_name ItemSystem

const CharacterStats = preload("res://game/scripts/character_stats.gd")
const ModifierSystem = preload("res://game/scripts/modifier_system.gd")

const MERGE_DIFF_KEYS := [
	"locked",
	"bound",
	"durability",
	"enchantments",
	"random_affixes",
	"custom_effects",
]

const EQUIP_SLOT_ORDER := [
	{"slot": "helmet", "label": "\u5934\u76d4", "accept_slot_type": "helmet", "group": "main"},
	{"slot": "weapon", "label": "\u6b66\u5668", "accept_slot_type": "weapon", "group": "main"},
	{"slot": "offhand", "label": "\u526f\u624b", "accept_slot_type": "offhand", "group": "main"},
	{"slot": "top", "label": "\u8863\u670d", "accept_slot_type": "top", "group": "main"},
	{"slot": "pants", "label": "\u88e4\u5b50", "accept_slot_type": "pants", "group": "main"},
	{"slot": "shoes", "label": "\u978b\u5b50", "accept_slot_type": "shoes", "group": "main"},
	{"slot": "accessory_1", "label": "\u9970\u54c1 1", "accept_slot_type": "accessory", "group": "accessory"},
	{"slot": "accessory_2", "label": "\u9970\u54c1 2", "accept_slot_type": "accessory", "group": "accessory"},
	{"slot": "accessory_3", "label": "\u9970\u54c1 3", "accept_slot_type": "accessory", "group": "accessory"},
	{"slot": "accessory_4", "label": "\u9970\u54c1 4", "accept_slot_type": "accessory", "group": "accessory"},
	{"slot": "accessory_5", "label": "\u9970\u54c1 5", "accept_slot_type": "accessory", "group": "accessory"},
	{"slot": "accessory_6", "label": "\u9970\u54c1 6", "accept_slot_type": "accessory", "group": "accessory"},
]

const ITEM_DEFINITIONS := {
	"iron_sword": {
		"template_id": "iron_sword",
		"display_name": "\u94c1\u5251",
		"icon": "",
		"item_type": "equipment",
		"equip_slot_type": "weapon",
		"rarity": "\u666e\u901a",
		"stackable": true,
		"max_stack": 5,
		"modifier_entries": [
			{"target_key": "b.damage_power", "channel": "flat", "value": 10.0},
			{"target_key": "skill.slash_damage", "channel": "mult", "value": 0.10},
		],
		"effects": [],
		"special_effects": [],
		"description": "\u57fa\u7840\u94c1\u5236\u6b66\u5668\uff0c\u80fd\u7a33\u5b9a\u63d0\u5347\u7269\u7406\u4f24\u5bb3\u3002",
		"flavor_text": "\u5251\u8eab\u867d\u65e7\uff0c\u4f46\u8fd8\u80fd\u7528\u3002",
		"can_drop": true,
		"can_equip": true,
		"can_split": true,
	},
	"leather_helmet": {
		"template_id": "leather_helmet",
		"display_name": "\u76ae\u5934\u76d4",
		"icon": "",
		"item_type": "equipment",
		"equip_slot_type": "helmet",
		"rarity": "\u666e\u901a",
		"stackable": true,
		"max_stack": 5,
		"modifier_entries": [
			{"target_key": "a.fortitude", "channel": "flat", "value": 1.0},
			{"target_key": "b.health", "channel": "flat", "value": 14.0},
			{"target_key": "b.block_rate", "channel": "flat", "value": 2.0},
		],
		"effects": [],
		"special_effects": [],
		"description": "\u8f7b\u4fbf\u76ae\u5934\u76d4\uff0c\u80fd\u63d0\u5347\u751f\u5b58\u80fd\u529b\u3002",
		"flavor_text": "\u7f1d\u7ebf\u8fd8\u7b97\u7ed3\u5b9e\u3002",
		"can_drop": true,
		"can_equip": true,
		"can_split": true,
	},
	"training_coat": {
		"template_id": "training_coat",
		"display_name": "\u8bad\u7ec3\u4e0a\u8863",
		"icon": "",
		"item_type": "equipment",
		"equip_slot_type": "top",
		"rarity": "\u666e\u901a",
		"stackable": true,
		"max_stack": 5,
		"modifier_entries": [
			{"target_key": "a.strength", "channel": "flat", "value": 1.0},
			{"target_key": "a.fortitude", "channel": "flat", "value": 1.0},
			{"target_key": "b.health", "channel": "flat", "value": 10.0},
		],
		"effects": [],
		"special_effects": [],
		"description": "\u7528\u4e8e\u65b0\u624b\u8bad\u7ec3\u7684\u8f7b\u7532\u3002",
		"flavor_text": "\u80a9\u90e8\u6709\u5f88\u591a\u7ec3\u4e60\u75d5\u8ff9\u3002",
		"can_drop": true,
		"can_equip": true,
		"can_split": true,
	},
	"training_pants": {
		"template_id": "training_pants",
		"display_name": "\u8bad\u7ec3\u88e4",
		"icon": "",
		"item_type": "equipment",
		"equip_slot_type": "pants",
		"rarity": "\u666e\u901a",
		"stackable": true,
		"max_stack": 5,
		"modifier_entries": [
			{"target_key": "a.agility", "channel": "flat", "value": 1.0},
			{"target_key": "b.evasion", "channel": "flat", "value": 2.5},
		],
		"effects": [],
		"special_effects": [],
		"description": "\u4fbf\u4e8e\u79fb\u52a8\u7684\u8bad\u7ec3\u88e4\u3002",
		"flavor_text": "\u8dd1\u8d77\u6765\u4e0d\u4f1a\u62d6\u817f\u3002",
		"can_drop": true,
		"can_equip": true,
		"can_split": true,
	},
	"swift_boots": {
		"template_id": "swift_boots",
		"display_name": "\u8f7b\u6377\u9774",
		"icon": "",
		"item_type": "equipment",
		"equip_slot_type": "shoes",
		"rarity": "\u7cbe\u826f",
		"stackable": true,
		"max_stack": 5,
		"modifier_entries": [
			{"target_key": "b.move_speed", "channel": "flat", "value": 0.25},
			{"target_key": "b.attack_speed", "channel": "flat", "value": 0.05},
		],
		"effects": [],
		"special_effects": [],
		"description": "\u63d0\u9ad8\u6b65\u4f10\u8282\u594f\u7684\u9774\u5b50\u3002",
		"flavor_text": "\u978b\u5e95\u8f7b\uff0c\u8d70\u8d77\u6765\u6ca1\u58f0\u97f3\u3002",
		"can_drop": true,
		"can_equip": true,
		"can_split": true,
	},
	"training_shield": {
		"template_id": "training_shield",
		"display_name": "\u8bad\u7ec3\u76fe",
		"icon": "",
		"item_type": "equipment",
		"equip_slot_type": "offhand",
		"rarity": "\u666e\u901a",
		"stackable": true,
		"max_stack": 5,
		"modifier_entries": [
			{"target_key": "b.block_rate", "channel": "flat", "value": 6.0},
			{"target_key": "b.health", "channel": "flat", "value": 12.0},
		],
		"effects": [],
		"special_effects": [],
		"description": "\u65b0\u624b\u7528\u7684\u5c0f\u5706\u76fe\uff0c\u4e3b\u8981\u7528\u6765\u7ec3\u4e60\u683c\u6321\u3002",
		"flavor_text": "\u76fe\u9762\u8fd8\u6709\u88ab\u51fb\u4e2d\u7684\u5212\u75d5\u3002",
		"can_drop": true,
		"can_equip": true,
		"can_split": true,
	},
	"bronze_ring": {
		"template_id": "bronze_ring",
		"display_name": "\u9752\u94dc\u6212",
		"icon": "",
		"item_type": "equipment",
		"equip_slot_type": "accessory",
		"rarity": "\u666e\u901a",
		"stackable": true,
		"max_stack": 10,
		"modifier_entries": [
			{"target_key": "b.critical_rate", "channel": "flat", "value": 3.0},
			{"target_key": "skill.slash_damage", "channel": "add", "value": 0.05},
		],
		"effects": [],
		"special_effects": [],
		"description": "\u6807\u51c6\u5316\u5236\u4f5c\u7684\u9970\u54c1\uff0c\u53ef\u4ee5\u88c5\u5230\u4efb\u610f\u9970\u54c1\u69fd\u3002",
		"flavor_text": "\u8868\u9762\u88ab\u6253\u78e8\u5f97\u53d1\u4eae\u3002",
		"can_drop": true,
		"can_equip": true,
		"can_split": true,
	},
	"healing_herb": {
		"template_id": "healing_herb",
		"display_name": "\u6cbb\u7597\u8349",
		"icon": "",
		"item_type": "material",
		"equip_slot_type": "",
		"rarity": "\u666e\u901a",
		"stackable": true,
		"max_stack": 20,
		"modifier_entries": [],
		"effects": [],
		"special_effects": [],
		"description": "\u53ef\u4ee5\u7528\u6765\u8c03\u5408\u57fa\u7840\u836f\u5242\u7684\u690d\u7269\u3002",
		"flavor_text": "\u4e00\u80a1\u6de1\u6de1\u7684\u8349\u6728\u5473\u3002",
		"can_drop": true,
		"can_equip": false,
		"can_split": true,
	},
	"mana_shard": {
		"template_id": "mana_shard",
		"display_name": "\u9b54\u529b\u788e\u7247",
		"icon": "",
		"item_type": "material",
		"equip_slot_type": "",
		"rarity": "\u7a00\u6709",
		"stackable": true,
		"max_stack": 10,
		"modifier_entries": [],
		"effects": [],
		"special_effects": [],
		"description": "\u5e26\u6709\u5fae\u5f31\u80fd\u91cf\u6ce2\u52a8\u7684\u788e\u7247\u3002",
		"flavor_text": "\u6478\u4e0a\u53bb\u5fae\u5fae\u53d1\u70ed\u3002",
		"can_drop": true,
		"can_equip": false,
		"can_split": true,
	},
}


static func get_item_definition(item_id: String) -> Dictionary:
	var template_id: String = normalize_template_id(item_id)
	if ITEM_DEFINITIONS.has(template_id):
		return normalize_item_definition(ITEM_DEFINITIONS[template_id] as Dictionary)
	return {}


static func make_stack(item_id: String, count: int = 1) -> Dictionary:
	return normalize_item_stack({
		"template_id": item_id,
		"count": count,
	})


static func normalize_template_id(raw_template_id: Variant) -> String:
	return str(raw_template_id).strip_edges()


static func normalize_slot_type(raw_slot_type: String) -> String:
	match raw_slot_type:
		"armor":
			return "top"
		_:
			return raw_slot_type


static func normalize_item_definition(definition: Dictionary) -> Dictionary:
	if definition.is_empty():
		return {}
	var normalized: Dictionary = definition.duplicate(true)
	var template_id: String = normalize_template_id(normalized.get("template_id", normalized.get("id", "")))
	var display_name: String = str(normalized.get("display_name", normalized.get("name", template_id)))
	var max_stack: int = max(int(normalized.get("max_stack", 1)), 1)
	var stackable: bool = bool(normalized.get("stackable", max_stack > 1))
	if not stackable:
		max_stack = 1
	normalized["template_id"] = template_id
	normalized["id"] = template_id
	normalized["display_name"] = display_name
	normalized["name"] = display_name
	normalized["equip_slot_type"] = normalize_slot_type(str(normalized.get("equip_slot_type", "")))
	normalized["stackable"] = stackable
	normalized["max_stack"] = max_stack
	normalized["effects"] = normalized.get("effects", normalized.get("modifier_entries", []))
	return normalized


static func normalize_item_stack(item_stack: Dictionary) -> Dictionary:
	if item_stack.is_empty():
		return {}
	var normalized: Dictionary = item_stack.duplicate(true)
	var template_id: String = normalize_template_id(normalized.get("template_id", normalized.get("id", "")))
	if template_id == "":
		return {}
	normalized["template_id"] = template_id
	normalized["id"] = template_id
	normalized["count"] = max(int(normalized.get("count", 1)), 1)
	return normalized


static func get_stack_template_id(item_stack: Dictionary) -> String:
	return str(normalize_item_stack(item_stack).get("template_id", ""))


static func is_stackable_definition(definition: Dictionary) -> bool:
	var normalized: Dictionary = normalize_item_definition(definition)
	return bool(normalized.get("stackable", false)) and int(normalized.get("max_stack", 1)) > 1


static func get_max_stack_for_definition(definition: Dictionary) -> int:
	var normalized: Dictionary = normalize_item_definition(definition)
	return max(int(normalized.get("max_stack", 1)), 1)


static func is_same_merge_signature(stack_a: Dictionary, stack_b: Dictionary) -> bool:
	var normalized_a: Dictionary = normalize_item_stack(stack_a)
	var normalized_b: Dictionary = normalize_item_stack(stack_b)
	if normalized_a.is_empty() or normalized_b.is_empty():
		return false
	if str(normalized_a.get("template_id", "")) != str(normalized_b.get("template_id", "")):
		return false
	for diff_key in MERGE_DIFF_KEYS:
		if normalized_a.get(diff_key, null) != normalized_b.get(diff_key, null):
			return false
	return true


static func can_merge_stacks(target_stack: Dictionary, incoming_stack: Dictionary) -> bool:
	var normalized_target: Dictionary = normalize_item_stack(target_stack)
	var normalized_incoming: Dictionary = normalize_item_stack(incoming_stack)
	if normalized_target.is_empty() or normalized_incoming.is_empty():
		return false
	if not is_same_merge_signature(normalized_target, normalized_incoming):
		return false
	var definition: Dictionary = get_item_definition(str(normalized_target.get("template_id", "")))
	if not is_stackable_definition(definition):
		return false
	return int(normalized_target.get("count", 1)) < get_max_stack_for_definition(definition)


static func merge_stacks(target_stack: Dictionary, incoming_stack: Dictionary) -> Dictionary:
	var normalized_target: Dictionary = normalize_item_stack(target_stack)
	var normalized_incoming: Dictionary = normalize_item_stack(incoming_stack)
	if not can_merge_stacks(normalized_target, normalized_incoming):
		return {
			"target_stack": normalized_target,
			"source_stack": normalized_incoming,
			"merged_count": 0,
		}
	var definition: Dictionary = get_item_definition(str(normalized_target.get("template_id", "")))
	var max_stack: int = get_max_stack_for_definition(definition)
	var target_count: int = int(normalized_target.get("count", 1))
	var incoming_count: int = int(normalized_incoming.get("count", 1))
	var merge_count: int = mini(max_stack - target_count, incoming_count)
	normalized_target["count"] = target_count + merge_count
	normalized_incoming["count"] = incoming_count - merge_count
	if int(normalized_incoming.get("count", 0)) <= 0:
		normalized_incoming = {}
	return {
		"target_stack": normalized_target,
		"source_stack": normalized_incoming,
		"merged_count": merge_count,
	}


static func get_empty_equipment_state() -> Dictionary:
	var result: Dictionary = {}
	for slot_definition in EQUIP_SLOT_ORDER:
		result[str(slot_definition["slot"])] = {}
	return result


static func get_default_inventory_state() -> Array:
	return [
		make_stack("leather_helmet", 1),
		make_stack("iron_sword", 1),
		make_stack("training_shield", 1),
		make_stack("training_coat", 1),
		make_stack("training_pants", 1),
		make_stack("swift_boots", 1),
		make_stack("bronze_ring", 2),
		make_stack("healing_herb", 8),
		make_stack("mana_shard", 3),
	]


static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"\u7cbe\u826f":
			return Color(0.47, 0.86, 0.98, 1.0)
		"\u7a00\u6709":
			return Color(0.74, 0.66, 1.0, 1.0)
		_:
			return Color(0.88, 0.88, 0.88, 1.0)


static func get_item_type_display(definition: Dictionary) -> String:
	var normalized: Dictionary = normalize_item_definition(definition)
	if str(normalized.get("item_type", "")) == "equipment":
		return "装备 / %s" % get_slot_label(str(normalized.get("equip_slot_type", "")))
	return str(normalized.get("item_type", ""))


static func get_slot_label(slot_type: String) -> String:
	var normalized_slot: String = normalize_slot_type(slot_type)
	for slot_definition in EQUIP_SLOT_ORDER:
		if str(slot_definition["slot"]) == normalized_slot:
			return str(slot_definition["label"])
	if normalized_slot == "accessory":
		return "饰品"
	return normalized_slot


static func get_slot_definition(slot_type: String) -> Dictionary:
	var normalized_slot: String = normalize_slot_type(slot_type)
	for slot_definition in EQUIP_SLOT_ORDER:
		if str(slot_definition.get("slot", "")) == normalized_slot:
			return (slot_definition as Dictionary).duplicate(true)
	return {}


static func get_slot_accept_type(slot_type: String) -> String:
	var slot_definition: Dictionary = get_slot_definition(slot_type)
	if slot_definition.is_empty():
		return normalize_slot_type(slot_type)
	return str(slot_definition.get("accept_slot_type", slot_definition.get("slot", "")))


static func get_slot_group(slot_type: String) -> String:
	var slot_definition: Dictionary = get_slot_definition(slot_type)
	return str(slot_definition.get("group", "main"))


static func get_main_slot_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_definition in EQUIP_SLOT_ORDER:
		if str(slot_definition.get("group", "")) == "main":
			result.append((slot_definition as Dictionary).duplicate(true))
	return result


static func get_accessory_slot_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_definition in EQUIP_SLOT_ORDER:
		if str(slot_definition.get("group", "")) == "accessory":
			result.append((slot_definition as Dictionary).duplicate(true))
	return result


static func find_best_equip_slot(equipped_items: Dictionary, item_stack: Dictionary) -> String:
	var definition: Dictionary = get_item_definition(get_stack_template_id(item_stack))
	if definition.is_empty() or not bool(definition.get("can_equip", false)):
		return ""

	var equip_slot_type: String = str(definition.get("equip_slot_type", ""))
	if equip_slot_type == "accessory":
		for slot_definition in get_accessory_slot_definitions():
			var slot_key := str(slot_definition.get("slot", ""))
			var equipped_stack: Dictionary = normalize_item_stack(equipped_items.get(slot_key, {}))
			if equipped_stack.is_empty():
				return slot_key
		return ""

	for slot_definition in get_main_slot_definitions():
		if str(slot_definition.get("accept_slot_type", "")) == equip_slot_type:
			return str(slot_definition.get("slot", ""))
	return ""


static func get_modifier_entries(definition: Dictionary) -> Array[Dictionary]:
	var normalized: Dictionary = normalize_item_definition(definition)
	var entries: Array[Dictionary] = []
	if normalized.has("modifier_entries"):
		for raw_entry in normalized.get("modifier_entries", []):
			if typeof(raw_entry) == TYPE_DICTIONARY:
				entries.append((raw_entry as Dictionary).duplicate(true))
		return entries

	var a_bonus: Dictionary = normalized.get("a_bonus", {})
	var b_bonus: Dictionary = normalized.get("b_bonus", {})

	for stat_definition in CharacterStats.A_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		if a_bonus.has(stat_key):
			entries.append({
				"target_key": "a.%s" % stat_key,
				"channel": ModifierSystem.CHANNEL_FLAT,
				"value": float(a_bonus[stat_key]),
			})
	for stat_definition in CharacterStats.B_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		if b_bonus.has(stat_key):
			entries.append({
				"target_key": CharacterStats.get_b_target_key(stat_key),
				"channel": ModifierSystem.CHANNEL_FLAT,
				"value": float(b_bonus[stat_key]),
			})
	return entries


static func build_item_modifier_source(source_id: String, source_name: String, source_type: String, definition: Dictionary) -> Dictionary:
	return ModifierSystem.build_modifier_source(
		source_id,
		source_name,
		source_type,
		get_modifier_entries(definition)
	)


static func build_hover_detail_data(definition: Dictionary, item_stack: Dictionary = {}, is_equipped: bool = false) -> Dictionary:
	var normalized_definition: Dictionary = normalize_item_definition(definition)
	var normalized_stack: Dictionary = normalize_item_stack(item_stack)
	if normalized_definition.is_empty():
		return {}

	var summary_lines: Array[String] = [
		"类型：%s" % get_item_type_display(normalized_definition),
		"稀有度：%s" % str(normalized_definition.get("rarity", "")),
	]
	if not normalized_stack.is_empty():
		summary_lines.append("数量：%d" % int(normalized_stack.get("count", 1)))
	if is_equipped:
		summary_lines.append("状态：已装备")

	var bonus_lines := _build_core_bonus_lines(normalized_definition)
	if not bonus_lines.is_empty():
		summary_lines.append("核心加成：%s" % "；".join(bonus_lines))

	var detail_lines: Array[String] = []
	for line_text in _build_full_bonus_lines(normalized_definition):
		detail_lines.append(line_text)

	var special_effects: Array = normalized_definition.get("special_effects", [])
	if special_effects.is_empty():
		detail_lines.append("特殊效果：无")
	else:
		detail_lines.append("特殊效果：")
		for effect_text in special_effects:
			detail_lines.append(" - %s" % str(effect_text))

	var description := str(normalized_definition.get("description", ""))
	if description != "":
		detail_lines.append("描述：%s" % description)

	var flavor_text := str(normalized_definition.get("flavor_text", ""))
	if flavor_text != "":
		detail_lines.append("补充说明：%s" % flavor_text)

	return {
		"title": str(normalized_definition.get("display_name", normalized_definition.get("name", ""))),
		"summary_lines": summary_lines,
		"detail_lines": detail_lines,
		"supports_shift": not detail_lines.is_empty(),
		"source_type": "item",
	}


static func _build_core_bonus_lines(definition: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for entry in get_modifier_entries(definition):
		lines.append(_format_modifier_entry_line(entry))
	return lines


static func _build_full_bonus_lines(definition: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var modifier_entries := get_modifier_entries(definition)
	if modifier_entries.is_empty():
		lines.append("属性加成：无")
	else:
		for entry in modifier_entries:
			lines.append(_format_modifier_entry_line(entry))

	return lines


static func _format_modifier_entry_line(entry: Dictionary) -> String:
	var target_key := str(entry.get("target_key", ""))
	var channel := str(entry.get("channel", ""))
	var target_label := ModifierSystem.get_target_label(target_key)
	var value := float(entry.get("value", 0.0))

	match channel:
		ModifierSystem.CHANNEL_FLAT:
			return "%s %s" % [target_label, ModifierSystem.format_target_value(target_key, value, true)]
		ModifierSystem.CHANNEL_ADD:
			return "%s %s %s" % [target_label, ModifierSystem.get_channel_label(channel), ModifierSystem.format_channel_total(target_key, channel, value)]
		ModifierSystem.CHANNEL_MULT:
			return "%s %s %s" % [target_label, ModifierSystem.get_channel_label(channel), ModifierSystem.format_channel_total(target_key, channel, 1.0 + value)]
		_:
			return "%s %s" % [target_label, str(value)]
