extends RefCounted
class_name AIRegistry

const AIPresetScript = preload("res://game/ai/ai_preset.gd")

const PRESET_PATHS := {
	"enemy_melee_grunt_001": "res://game/ai/presets/enemy_melee_grunt_001.tres",
	"enemy_archer_001": "res://game/ai/presets/enemy_archer_001.tres",
	"boss_guardian_phase1": "res://game/ai/presets/boss_guardian_phase1.tres",
	"boss_guardian_phase2": "res://game/ai/presets/boss_guardian_phase2.tres",
	"frost_white_wolf_hunter_001": "res://game/ai/presets/frost_white_wolf_hunter_001.tres",
	"npc_guard_friendly_idle": "res://game/ai/presets/npc_guard_friendly_idle.tres",
	"npc_guard_enemy_combat": "res://game/ai/presets/npc_guard_enemy_combat.tres",
}

static var _preset_cache: Dictionary = {}


static func get_preset(ai_id: String):
	if ai_id.is_empty():
		push_error("AIRegistry.get_preset received an empty ai_id.")
		return null

	if _preset_cache.has(ai_id):
		return _preset_cache[ai_id]

	if not PRESET_PATHS.has(ai_id):
		push_error("AI preset is not registered for ai_id: %s" % ai_id)
		return null

	var preset = load(str(PRESET_PATHS[ai_id]))
	if preset == null:
		push_error("Failed to load AI preset for ai_id: %s" % ai_id)
		return null

	_preset_cache[ai_id] = preset
	return preset


static func has_preset(ai_id: String) -> bool:
	return PRESET_PATHS.has(ai_id)


static func get_registered_ai_ids() -> PackedStringArray:
	return PackedStringArray(PRESET_PATHS.keys())
