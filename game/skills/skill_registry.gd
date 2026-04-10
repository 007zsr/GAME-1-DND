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

	var definitions: Array = []
	var bindings: Dictionary = {}
	var role_id := str(actor_config.get("role", "actor"))
	var owner_slug := str(actor_config.get("skill_owner_slug", ""))
	if owner_slug.is_empty():
		owner_slug = fallback_owner_name.to_lower().replace(" ", "_")
	if owner_slug.is_empty():
		owner_slug = role_id

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
