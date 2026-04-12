extends RefCounted
class_name SkillRegistry

const CharacterCreationRegistry = preload("res://character_creation/scripts/character_creation_registry.gd")
const SkillRuntime = preload("res://game/skills/skill_runtime.gd")

const DEFAULT_PLAYER_SKILL_SLOT_COUNT := 1

const SKILL_DEFINITIONS := {
	"slash_skill": {
		"skill_id": "slash_skill",
		"display_name": "斩击",
		"skill_type": "passive",
		"tags": ["melee", "auto", "starter"],
		"summary": "范围内有敌人时自动触发，造成近身斩击伤害。",
		"description_key": "slash_skill",
		"execution_key": "player_slash",
		"parameters": {
			"trigger_text": "范围内有敌人且冷却结束时立即触发",
			"base_range_meters": 0.5,
			"flash_duration": 0.2,
		},
		"visual": {
			"effect_root": "res://game/assets/textures/effects/skills/",
			"effect_profile": "player_slash",
			"fallback_body_animation": "move",
		},
	},
	"frost_white_wolf_rear_dash": {
		"skill_id": "frost_white_wolf_rear_dash",
		"display_name": "快速绕后突进",
		"skill_type": "active",
		"tags": ["enemy", "wolf", "dash", "primary"],
		"summary": "施放瞬间锁定玩家背后固定落点后高速突进。",
		"description_key": "frost_white_wolf_rear_dash",
		"execution_key": "enemy_fixed_dash_attack",
		"parameters": {
			"name": "快速绕后突进",
			"range_meters": 8.0,
			"behind_offset_meters": 1.1,
			"landing_search_radius_meters": 1.8,
			"dash_speed_multiplier": 3.0,
			"arrival_threshold_meters": 0.24,
			"failure_recovery": 0.28,
			"failure_cooldown": 6.0,
			"flash_duration": 0.14,
			"effect_color": Color(0.84, 0.92, 1.0, 0.78),
		},
		"visual": {
			"effect_root": "res://game/assets/textures/effects/skills/",
			"effect_profile": "wolf_rear_dash",
			"fallback_body_animation": "move",
		},
	},
	"frost_white_wolf_triple_bite": {
		"skill_id": "frost_white_wolf_triple_bite",
		"display_name": "三段连续啃咬",
		"skill_type": "active",
		"tags": ["enemy", "wolf", "bite", "fallback"],
		"summary": "一次施法连续打出三段近身啃咬。",
		"description_key": "frost_white_wolf_triple_bite",
		"execution_key": "enemy_multi_bite_attack",
		"parameters": {
			"name": "三段连续啃咬",
			"range_meters": 1.1,
			"arc_degrees": 115.0,
			"damage": 12,
			"bite_count": 3,
			"bite_interval": 0.18,
			"combo_tail": 0.08,
			"flash_duration": 0.09,
			"effect_color": Color(0.92, 0.96, 1.0, 0.84),
		},
		"visual": {
			"effect_root": "res://game/assets/textures/effects/skills/",
			"effect_profile": "wolf_triple_bite",
			"fallback_body_animation": "attack",
		},
	},
	"melee_grunt_slash": {
		"skill_id": "melee_grunt_slash",
		"display_name": "小兵斩击",
		"skill_type": "active",
		"tags": ["enemy", "grunt", "melee", "primary"],
		"summary": "近战小兵的标准前方扇形斩击。",
		"description_key": "melee_grunt_slash",
		"execution_key": "enemy_sector_attack",
		"parameters": {
			"name": "小兵斩击",
			"range_meters": 0.95,
			"arc_degrees": 110.0,
			"damage": 14,
			"flash_duration": 0.18,
			"effect_color": Color(1.0, 0.76, 0.42, 0.72),
		},
		"visual": {
			"effect_root": "res://game/assets/textures/effects/skills/",
			"effect_profile": "melee_grunt_slash",
			"fallback_body_animation": "attack",
		},
	},
	"ranged_grunt_energy_shot": {
		"skill_id": "ranged_grunt_energy_shot",
		"display_name": "能量弹",
		"skill_type": "active",
		"tags": ["enemy", "grunt", "ranged", "projectile", "primary"],
		"summary": "远程小兵发射沿现役投射物链运行的能量弹。",
		"description_key": "ranged_grunt_energy_shot",
		"execution_key": "enemy_projectile_attack",
		"parameters": {
			"type": "projectile",
			"name": "能量弹",
			"range_meters": 6.0,
			"arc_degrees": 60.0,
			"damage": 11,
			"flash_duration": 0.14,
			"effect_color": Color(0.72, 0.88, 1.0, 0.92),
			"projectile_speed_mps": 5.0,
			"projectile_range_meters": 8.0,
			"projectile_size_meters": Vector2(0.2, 0.2),
		},
		"visual": {
			"effect_root": "res://game/assets/textures/effects/skills/",
			"projectile_root": "res://game/assets/textures/effects/projectiles/",
			"effect_profile": "ranged_grunt_energy_shot",
			"fallback_body_animation": "attack",
		},
	},
	"ranged_grunt_close_counter": {
		"skill_id": "ranged_grunt_close_counter",
		"display_name": "近身反击",
		"skill_type": "active",
		"tags": ["enemy", "grunt", "ranged", "fallback"],
		"summary": "远程小兵被贴脸时使用的近身扇形反击。",
		"description_key": "ranged_grunt_close_counter",
		"execution_key": "enemy_sector_attack",
		"parameters": {
			"type": "sector",
			"name": "近身反击",
			"range_meters": 1.5,
			"arc_degrees": 100.0,
			"damage": 6,
			"flash_duration": 0.12,
			"effect_color": Color(1.0, 0.72, 0.56, 0.7),
		},
		"visual": {
			"effect_root": "res://game/assets/textures/effects/skills/",
			"effect_profile": "ranged_grunt_close_counter",
			"fallback_body_animation": "attack",
		},
	},
	"boss_guardian_triple_cleave": {
		"skill_id": "boss_guardian_triple_cleave",
		"display_name": "三段强化斩",
		"skill_type": "active",
		"tags": ["enemy", "boss", "cleave", "primary"],
		"summary": "Boss 起手后锁定朝向，原地完成三段由小到大的半圆斩击。",
		"description_key": "boss_guardian_triple_cleave",
		"execution_key": "enemy_multi_stage_sector_attack",
		"parameters": {
			"name": "三段强化斩",
			"ai_trigger_range_meters": 1.4,
			"combo_tail": 0.12,
			"stages": [
				{
					"time": 0.0,
					"range_meters": 1.4,
					"arc_degrees": 120.0,
					"damage": 18,
					"flash_duration": 0.18,
					"effect_color": Color(1.0, 0.40, 0.40, 0.78),
				},
				{
					"time": 0.22,
					"range_meters": 1.9,
					"arc_degrees": 145.0,
					"damage": 26,
					"flash_duration": 0.20,
					"effect_color": Color(1.0, 0.32, 0.32, 0.82),
				},
				{
					"time": 0.46,
					"range_meters": 2.5,
					"arc_degrees": 165.0,
					"damage": 36,
					"flash_duration": 0.24,
					"effect_color": Color(1.0, 0.24, 0.24, 0.88),
				},
			],
		},
		"visual": {
			"effect_root": "res://game/assets/textures/effects/skills/",
			"effect_profile": "boss_guardian_triple_cleave",
			"fallback_body_animation": "attack",
		},
	},
}


static func get_skill_definition(skill_id: String) -> Dictionary:
	if not SKILL_DEFINITIONS.has(skill_id):
		return {}
	return SkillRuntime.normalize_skill_definition((SKILL_DEFINITIONS.get(skill_id, {}) as Dictionary).duplicate(true))


static func get_skill_definitions(skill_ids: Array[String]) -> Array:
	var definitions: Array = []
	for skill_id in skill_ids:
		var definition := get_skill_definition(skill_id)
		if definition.is_empty():
			continue
		definitions.append(definition)
	return definitions


static func get_registered_skill_ids() -> PackedStringArray:
	return PackedStringArray(SKILL_DEFINITIONS.keys())


static func get_skill_type_label(skill_type: String) -> String:
	if skill_type == "passive":
		return "被动"
	return "主动"


static func build_player_skill_runtime(character_data: Dictionary, previous_runtime: Dictionary = {}) -> Dictionary:
	var owned_skill_ids := _extract_player_owned_skill_ids(character_data)
	var slot_count := int(character_data.get("skill_slot_count", DEFAULT_PLAYER_SKILL_SLOT_COUNT))
	var equipped_skill_ids := _extract_player_equipped_skill_ids(character_data, owned_skill_ids, slot_count)
	var persisted_overrides := (character_data.get("skill_state_overrides", {}) as Dictionary).duplicate(true)
	var runtime := SkillRuntime.build_owner_runtime(
		"player",
		"player",
		slot_count,
		get_skill_definitions(owned_skill_ids),
		owned_skill_ids,
		equipped_skill_ids,
		persisted_overrides
	)
	SkillRuntime.copy_cooldowns_from(runtime, previous_runtime)
	return runtime


static func export_player_skill_persistence(runtime: Dictionary) -> Dictionary:
	return {
		"owned_skill_ids": SkillRuntime.get_owned_skill_ids(runtime),
		"equipped_skill_ids": SkillRuntime.get_equipped_skill_ids(runtime),
		"skill_state_overrides": SkillRuntime.export_state_overrides(runtime),
		"skill_slot_count": SkillRuntime.get_slot_count(runtime),
	}


static func get_default_player_skill_slot_count() -> int:
	return DEFAULT_PLAYER_SKILL_SLOT_COUNT


static func build_actor_skill_payload(actor_config: Dictionary, fallback_owner_name: String = "") -> Dictionary:
	if actor_config.has("skill_definitions"):
		return {
			"definitions": (actor_config.get("skill_definitions", []) as Array).duplicate(true),
			"bindings": (actor_config.get("skill_bindings", {}) as Dictionary).duplicate(true),
		}
	if actor_config.has("skill_bindings"):
		var bindings := (actor_config.get("skill_bindings", {}) as Dictionary).duplicate(true)
		var definitions := _build_skill_definitions_from_ids(actor_config.get("skill_ids", []))
		var seen_skill_ids: Dictionary = {}
		for definition_entry in definitions:
			var definition_skill_id := str((definition_entry as Dictionary).get("skill_id", ""))
			if definition_skill_id.is_empty():
				continue
			seen_skill_ids[definition_skill_id] = true
		for attack_mode in bindings.keys():
			var skill_id := str(bindings.get(attack_mode, ""))
			if skill_id.is_empty() or seen_skill_ids.has(skill_id):
				continue
			seen_skill_ids[skill_id] = true
			var definition := get_skill_definition(skill_id)
			if definition.is_empty():
				continue
			definitions.append(definition)
		return {
			"definitions": definitions,
			"bindings": bindings,
		}
	if actor_config.has("skill_ids"):
		var definitions := _build_skill_definitions_from_ids(actor_config.get("skill_ids", []))
		var bindings := (actor_config.get("skill_bindings", {}) as Dictionary).duplicate(true)
		if bindings.is_empty():
			if definitions.size() > 0:
				bindings["primary"] = str((definitions[0] as Dictionary).get("skill_id", ""))
			if definitions.size() > 1:
				bindings["fallback"] = str((definitions[1] as Dictionary).get("skill_id", ""))
		return {
			"definitions": definitions,
			"bindings": bindings,
		}

	var definitions: Array = []
	var bindings: Dictionary = {}
	var role_id := str(actor_config.get("role", "actor"))
	var owner_slug := str(actor_config.get("skill_owner_slug", ""))
	if owner_slug.is_empty():
		owner_slug = fallback_owner_name.to_lower().replace(" ", "_")
	if owner_slug.is_empty():
		owner_slug = role_id
	var legacy_skill_visuals := _extract_legacy_skill_visuals(actor_config)

	if actor_config.has("skill"):
		var primary_skill := (actor_config.get("skill", {}) as Dictionary).duplicate(true)
		var primary_skill_id := str(actor_config.get("primary_skill_id", "%s_primary_skill" % owner_slug))
		definitions.append({
			"skill_id": primary_skill_id,
			"display_name": str(primary_skill.get("name", "%s Skill" % fallback_owner_name)),
			"skill_type": "active",
			"tags": ["actor", role_id, "primary"],
			"summary": str(primary_skill.get("summary", "")),
			"execution_key": "enemy_projectile_attack" if str(primary_skill.get("type", "sector")) == "projectile" else "enemy_sector_attack",
			"parameters": primary_skill,
			"visual": _build_legacy_skill_visual_definition(legacy_skill_visuals, "primary", str(primary_skill.get("type", "sector"))),
		})
		bindings["primary"] = primary_skill_id

	if role_id == "ranged":
		var primary_damage := float((actor_config.get("skill", {}) as Dictionary).get("damage", 1))
		var fallback_damage_ratio: float = float(actor_config.get("fallback_attack_damage_ratio", 0.5))
		var fallback_skill_id := str(actor_config.get("fallback_skill_id", "%s_fallback_skill" % owner_slug))
		definitions.append({
			"skill_id": fallback_skill_id,
			"display_name": str(actor_config.get("fallback_attack_name", "Fallback Attack")),
			"skill_type": "active",
			"tags": ["actor", role_id, "fallback"],
			"summary": str(actor_config.get("fallback_attack_summary", "")),
			"execution_key": "enemy_sector_attack",
			"parameters": {
				"type": "sector",
				"name": str(actor_config.get("fallback_attack_name", "Fallback Attack")),
				"range_meters": float(actor_config.get("fallback_attack_range", 0.9)),
				"arc_degrees": float(actor_config.get("fallback_attack_arc_degrees", 100.0)),
				"damage": max(1, int(round(primary_damage * fallback_damage_ratio))),
				"flash_duration": float(actor_config.get("fallback_flash_duration", 0.12)),
				"effect_color": actor_config.get("fallback_effect_color", Color(1.0, 0.72, 0.56, 0.7)),
			},
			"visual": _build_legacy_skill_visual_definition(legacy_skill_visuals, "fallback", "sector"),
		})
		bindings["fallback"] = fallback_skill_id

	return {
		"definitions": definitions,
		"bindings": bindings,
	}


static func _extract_player_owned_skill_ids(character_data: Dictionary) -> Array[String]:
	var owned_skill_ids: Array[String] = []
	for entry in character_data.get("owned_skill_ids", []):
		var skill_id := str(entry)
		if skill_id.is_empty() or owned_skill_ids.has(skill_id):
			continue
		owned_skill_ids.append(skill_id)

	if not owned_skill_ids.is_empty():
		return owned_skill_ids

	var reborn_job_id := str(character_data.get("reborn_job_id", character_data.get("class_id", "")))
	for entry in CharacterCreationRegistry.get_reborn_job_starting_skills(reborn_job_id):
		var skill_id := str((entry as Dictionary).get("id", (entry as Dictionary).get("skill_id", "")))
		if skill_id.is_empty() or owned_skill_ids.has(skill_id):
			continue
		owned_skill_ids.append(skill_id)
	return owned_skill_ids


static func _extract_player_equipped_skill_ids(character_data: Dictionary, owned_skill_ids: Array[String], slot_count: int) -> Array[String]:
	var equipped_skill_ids: Array[String] = []
	for entry in character_data.get("equipped_skill_ids", []):
		var skill_id := str(entry)
		if skill_id.is_empty():
			equipped_skill_ids.append("")
		elif owned_skill_ids.has(skill_id):
			equipped_skill_ids.append(skill_id)
		if equipped_skill_ids.size() >= slot_count:
			return equipped_skill_ids

	while equipped_skill_ids.size() < slot_count:
		if equipped_skill_ids.is_empty() and not owned_skill_ids.is_empty():
			equipped_skill_ids.append(owned_skill_ids[0])
		else:
			equipped_skill_ids.append("")
	return equipped_skill_ids


static func _build_skill_definitions_from_ids(skill_ids_source: Variant) -> Array:
	var definitions: Array = []
	var seen_skill_ids: Dictionary = {}
	if not (skill_ids_source is Array):
		return definitions
	for entry in skill_ids_source:
		var skill_id := str(entry)
		if skill_id.is_empty() or seen_skill_ids.has(skill_id):
			continue
		seen_skill_ids[skill_id] = true
		var definition := get_skill_definition(skill_id)
		if definition.is_empty():
			continue
		definitions.append(definition)
	return definitions


static func _extract_legacy_skill_visuals(actor_config: Dictionary) -> Dictionary:
	return (actor_config.get("skill_visuals", {}) as Dictionary).duplicate(true)


static func _build_legacy_skill_visual_definition(legacy_skill_visuals: Dictionary, attack_mode: String, skill_type: String) -> Dictionary:
	if legacy_skill_visuals.is_empty():
		return {}
	var visual: Dictionary = {}
	if legacy_skill_visuals.has("effect_root"):
		visual["effect_root"] = str(legacy_skill_visuals.get("effect_root", ""))
	if skill_type == "projectile" and legacy_skill_visuals.has("projectile_root"):
		visual["projectile_root"] = str(legacy_skill_visuals.get("projectile_root", ""))
	visual["legacy_visual_source"] = "unit_template:%s" % attack_mode
	return visual
