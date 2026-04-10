extends RefCounted
class_name SkillExecutor

const SkillRuntime = preload("res://game/skills/skill_runtime.gd")


static func can_execute(runtime: Dictionary, skill_id: String, require_equipped: bool = true) -> bool:
	return SkillRuntime.can_trigger_skill(runtime, skill_id, require_equipped)


static func request_execute(owner: Node, runtime: Dictionary, skill_id: String, request_context: Dictionary = {}) -> bool:
	if owner == null or runtime.is_empty() or skill_id.is_empty():
		return false
	if not can_execute(runtime, skill_id, bool(request_context.get("require_equipped", true))):
		return false

	var definition := SkillRuntime.get_definition(runtime, skill_id)
	if definition.is_empty():
		return false

	var result: Dictionary = {}
	if owner.has_method("execute_skill_definition"):
		result = owner.execute_skill_definition(skill_id, definition, request_context)
	else:
		var execution_key := str(definition.get("execution_key", ""))
		match execution_key:
			"player_slash":
				if owner.has_method("execute_player_skill_slash"):
					result = owner.execute_player_skill_slash(skill_id, definition, request_context)
			"enemy_sector_attack":
				if owner.has_method("execute_enemy_sector_skill"):
					result = owner.execute_enemy_sector_skill(skill_id, definition, request_context)
			"enemy_projectile_attack":
				if owner.has_method("execute_enemy_projectile_skill"):
					result = owner.execute_enemy_projectile_skill(skill_id, definition, request_context)
			_:
				return false

	if not bool(result.get("success", false)):
		return false

	SkillRuntime.set_cooldown(runtime, skill_id, float(result.get("cooldown_duration", 0.0)))
	return true
