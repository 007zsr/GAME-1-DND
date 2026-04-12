extends Node

const SkillRegistry = preload("res://game/skills/skill_registry.gd")
const CultivationWorldStructure = preload("res://game/scripts/cultivation_world_structure.gd")
const CultivationFrostWastesBlockout = preload("res://game/scripts/cultivation_frost_wastes_blockout.gd")
const GOD_SPACE_SCENE_PATH := "res://game/scenes/god_space_hub.tscn"
const CULTIVATION_WORLD_DEFAULT_SCENE_PATH := "res://game/scenes/cultivation_region_corner_northwest.tscn"

const WORLD_ORDER := [
	"cultivation_world",
	"esper_world",
	"future_world",
	"ancient_world",
]

const WORLD_DEFINITIONS := {
	"cultivation_world": {
		"world_id": "cultivation_world",
		"display_name": "修仙世界",
		"scene_path": CULTIVATION_WORLD_DEFAULT_SCENE_PATH,
		"world_kind": "structured_regions",
	},
	"esper_world": {
		"world_id": "esper_world",
		"display_name": "异能世界",
		"scene_path": "",
	},
	"future_world": {
		"world_id": "future_world",
		"display_name": "未来世界",
		"scene_path": "",
	},
	"ancient_world": {
		"world_id": "ancient_world",
		"display_name": "古代世界",
		"scene_path": "",
	},
}

var current_character: Dictionary = {}
var created_characters: Array[Dictionary] = []
var active_scene_entry_context: Dictionary = {}


func set_current_character(character_data: Dictionary) -> void:
	current_character = character_data.duplicate(true)
	_ensure_runtime_state_defaults()
	created_characters.append(current_character.duplicate(true))


func get_current_character() -> Dictionary:
	return current_character.duplicate(true)


func get_granted_triggers() -> Array[String]:
	var results: Array[String] = []
	for entry in current_character.get("granted_triggers", []):
		results.append(str(entry))
	return results


func has_granted_trigger(trigger_id: String) -> bool:
	if trigger_id == "":
		return false
	for entry in get_granted_triggers():
		if entry == trigger_id:
			return true
	return false


func grant_trigger(trigger_id: String) -> void:
	if trigger_id == "":
		return
	_ensure_runtime_state_defaults()
	if has_granted_trigger(trigger_id):
		return
	var granted_triggers: Array = current_character.get("granted_triggers", [])
	granted_triggers.append(trigger_id)
	current_character["granted_triggers"] = granted_triggers


func revoke_trigger(trigger_id: String) -> void:
	if trigger_id == "":
		return
	_ensure_runtime_state_defaults()
	var granted_triggers: Array = []
	for entry in current_character.get("granted_triggers", []):
		if str(entry) != trigger_id:
			granted_triggers.append(str(entry))
	current_character["granted_triggers"] = granted_triggers


func get_event_flags() -> Dictionary:
	_ensure_runtime_state_defaults()
	return (current_character.get("event_flags", {}) as Dictionary).duplicate(true)


func get_event_flag(flag_id: String, default_value: bool = false) -> bool:
	if flag_id == "":
		return default_value
	return bool(get_event_flags().get(flag_id, default_value))


func set_event_flag(flag_id: String, value: bool = true) -> void:
	if flag_id == "":
		return
	_ensure_runtime_state_defaults()
	var event_flags: Dictionary = current_character.get("event_flags", {})
	event_flags[flag_id] = value
	current_character["event_flags"] = event_flags


func get_progress_state() -> Dictionary:
	_ensure_runtime_state_defaults()
	return _get_progress_state_ref().duplicate(true)


func get_progress_flag(flag_id: String, default_value: bool = false) -> bool:
	if flag_id == "":
		return default_value
	return bool(_get_progress_state_ref().get(flag_id, default_value))


func set_progress_flag(flag_id: String, value: bool = true) -> void:
	if flag_id == "":
		return
	var progress_state := _get_progress_state_ref()
	progress_state[flag_id] = value
	current_character["progress_state"] = progress_state


func mark_tutorial_completed() -> void:
	set_progress_flag("tutorial_completed", true)


func has_completed_tutorial() -> bool:
	return get_progress_flag("tutorial_completed", false)


func mark_entered_god_space() -> void:
	clear_active_scene_entry_context()
	set_progress_flag("entered_god_space", true)
	set_current_world_id("")


func has_entered_god_space() -> bool:
	return get_progress_flag("entered_god_space", false)


func get_current_world_id() -> String:
	return str(_get_progress_state_ref().get("current_world_id", ""))


func set_current_world_id(world_id: String) -> void:
	var progress_state := _get_progress_state_ref()
	if world_id != "" and not WORLD_DEFINITIONS.has(world_id):
		return
	progress_state["current_world_id"] = world_id
	current_character["progress_state"] = progress_state


func get_current_test_world_id() -> String:
	var configured_world_id := str(_get_progress_state_ref().get("current_test_world_id", "cultivation_world"))
	if WORLD_DEFINITIONS.has(configured_world_id):
		return configured_world_id
	return "cultivation_world"


func set_current_test_world_id(world_id: String) -> void:
	if not WORLD_DEFINITIONS.has(world_id):
		return
	var progress_state := _get_progress_state_ref()
	progress_state["current_test_world_id"] = world_id
	current_character["progress_state"] = progress_state
	unlock_world(world_id)


func get_unlocked_world_ids() -> Array[String]:
	_ensure_runtime_state_defaults()
	var results: Array[String] = []
	for entry in _get_progress_state_ref().get("unlocked_world_ids", []):
		var world_id := str(entry)
		if world_id != "" and WORLD_DEFINITIONS.has(world_id) and not results.has(world_id):
			results.append(world_id)
	return results


func unlock_world(world_id: String) -> void:
	if not WORLD_DEFINITIONS.has(world_id):
		return
	var progress_state := _get_progress_state_ref()
	var unlocked_world_ids: Array = progress_state.get("unlocked_world_ids", [])
	if not unlocked_world_ids.has(world_id):
		unlocked_world_ids.append(world_id)
	progress_state["unlocked_world_ids"] = unlocked_world_ids
	current_character["progress_state"] = progress_state


func is_world_unlocked(world_id: String) -> bool:
	if not WORLD_DEFINITIONS.has(world_id):
		return false
	return get_unlocked_world_ids().has(world_id)


func get_world_definition(world_id: String) -> Dictionary:
	if not WORLD_DEFINITIONS.has(world_id):
		return {}
	return (WORLD_DEFINITIONS[world_id] as Dictionary).duplicate(true)


func get_world_display_name(world_id: String) -> String:
	var definition := get_world_definition(world_id)
	if definition.is_empty():
		return ""
	return str(definition.get("display_name", world_id))


func get_world_scene_path(world_id: String) -> String:
	if world_id == CultivationWorldStructure.get_world_id():
		return get_cultivation_world_scene_path()
	var definition := get_world_definition(world_id)
	if definition.is_empty():
		return ""
	return str(definition.get("scene_path", ""))


func can_enter_world(world_id: String) -> bool:
	if not is_world_unlocked(world_id):
		return false
	if world_id == CultivationWorldStructure.get_world_id():
		return get_cultivation_world_structure_errors().is_empty()
	return not get_world_scene_path(world_id).is_empty()


func get_cultivation_world_scene_path() -> String:
	var active_region_id := get_current_world_region_id()
	if get_current_world_id() == CultivationWorldStructure.get_world_id() and not active_region_id.is_empty():
		return CultivationWorldStructure.get_region_scene_path(active_region_id)
	return CULTIVATION_WORLD_DEFAULT_SCENE_PATH


func begin_world_exploration(world_id: String) -> String:
	if not can_enter_world(world_id):
		return ""
	clear_active_scene_entry_context()
	if world_id == CultivationWorldStructure.get_world_id():
		return _begin_random_cultivation_world_exploration()
	set_current_world_id(world_id)
	return get_world_scene_path(world_id)


func can_enter_world_selection_entry(entry_id: String) -> bool:
	if entry_id == CultivationFrostWastesBlockout.get_preview_entry_id():
		return can_enter_world(CultivationWorldStructure.get_world_id())
	return can_enter_world(entry_id)


func begin_world_selection_entry(entry_id: String) -> String:
	if not can_enter_world_selection_entry(entry_id):
		return ""
	if entry_id == CultivationFrostWastesBlockout.get_preview_entry_id():
		return begin_cultivation_region_preview(CultivationFrostWastesBlockout.get_region_id())
	return begin_world_exploration(entry_id)


func begin_cultivation_region_preview(region_id: String) -> String:
	if not CultivationWorldStructure.is_region_id_valid(region_id):
		return ""
	clear_active_scene_entry_context()
	active_scene_entry_context = {
		"entry_id": CultivationFrostWastesBlockout.get_preview_entry_id(),
		"entry_kind": "cultivation_region_preview",
		"world_id": CultivationWorldStructure.get_world_id(),
		"region_id": region_id,
	}
	return CultivationWorldStructure.get_region_scene_path(region_id)


func begin_cultivation_world_exploration_from_region(start_region_id: String) -> String:
	if not CultivationWorldStructure.is_start_region(start_region_id):
		return ""
	var scene_path := CultivationWorldStructure.get_region_scene_path(start_region_id)
	if scene_path.is_empty():
		return ""
	clear_active_scene_entry_context()
	var exploration_state := _build_default_world_exploration_state()
	exploration_state["active_world_id"] = CultivationWorldStructure.get_world_id()
	exploration_state["start_region_id"] = start_region_id
	exploration_state["current_region_id"] = start_region_id
	_set_world_exploration_state(exploration_state)
	set_current_world_id(CultivationWorldStructure.get_world_id())
	return scene_path


func travel_in_cultivation_world(target_region_id: String) -> String:
	if get_current_world_id() != CultivationWorldStructure.get_world_id():
		return ""
	if not CultivationWorldStructure.is_region_id_valid(target_region_id):
		return ""

	var exploration_state := _get_world_exploration_state_ref().duplicate(true)
	var current_region_id := str(exploration_state.get("current_region_id", ""))
	if current_region_id.is_empty():
		return ""
	if not CultivationWorldStructure.get_connected_region_ids(current_region_id).has(target_region_id):
		return ""
	if not _can_travel_in_cultivation_world(current_region_id, target_region_id, exploration_state):
		return ""

	exploration_state["active_world_id"] = CultivationWorldStructure.get_world_id()
	exploration_state["current_region_id"] = target_region_id
	if CultivationWorldStructure.is_edge_region(target_region_id):
		exploration_state["entered_edge"] = true
	if CultivationWorldStructure.is_center_region(target_region_id):
		exploration_state["entered_edge"] = true
		exploration_state["entered_core"] = true
	exploration_state["interrupted_by_death"] = false
	exploration_state["last_exit_reason"] = ""
	_set_world_exploration_state(exploration_state)
	set_current_world_id(CultivationWorldStructure.get_world_id())
	return CultivationWorldStructure.get_region_scene_path(target_region_id)


func sync_cultivation_world_region_context(region_id: String) -> void:
	if not CultivationWorldStructure.is_region_id_valid(region_id):
		return
	var exploration_state := _get_world_exploration_state_ref().duplicate(true)
	exploration_state["active_world_id"] = CultivationWorldStructure.get_world_id()
	if str(exploration_state.get("start_region_id", "")).is_empty():
		if CultivationWorldStructure.is_start_region(region_id):
			exploration_state["start_region_id"] = region_id
		else:
			exploration_state["start_region_id"] = CultivationWorldStructure.get_default_start_region_id()
	exploration_state["current_region_id"] = region_id
	exploration_state["entered_edge"] = bool(exploration_state.get("entered_edge", false)) or CultivationWorldStructure.is_edge_region(region_id) or CultivationWorldStructure.is_center_region(region_id)
	exploration_state["entered_core"] = bool(exploration_state.get("entered_core", false)) or CultivationWorldStructure.is_center_region(region_id)
	exploration_state["interrupted_by_death"] = false
	exploration_state["last_exit_reason"] = ""
	_set_world_exploration_state(exploration_state)
	set_current_world_id(CultivationWorldStructure.get_world_id())


func abort_world_exploration(reason: String = "") -> void:
	clear_active_scene_entry_context()
	var exploration_state := _build_default_world_exploration_state()
	exploration_state["last_exit_reason"] = reason
	exploration_state["interrupted_by_death"] = reason == "death"
	_set_world_exploration_state(exploration_state)
	set_current_world_id("")


func get_world_exploration_state() -> Dictionary:
	_ensure_runtime_state_defaults()
	return _get_world_exploration_state_ref().duplicate(true)


func get_current_world_region_id() -> String:
	if get_current_world_id() != CultivationWorldStructure.get_world_id():
		return ""
	var exploration_state := _get_world_exploration_state_ref()
	if str(exploration_state.get("active_world_id", "")) != CultivationWorldStructure.get_world_id():
		return ""
	return str(exploration_state.get("current_region_id", ""))


func get_available_cultivation_region_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if get_current_world_id() != CultivationWorldStructure.get_world_id():
		return entries
	var exploration_state := _get_world_exploration_state_ref()
	var current_region_id := str(exploration_state.get("current_region_id", ""))
	if current_region_id.is_empty():
		return entries
	for target_region_id in CultivationWorldStructure.get_connected_region_ids(current_region_id):
		if not _can_travel_in_cultivation_world(current_region_id, target_region_id, exploration_state):
			continue
		entries.append(CultivationWorldStructure.get_region_definition(target_region_id))
	return entries


func get_cultivation_world_structure_snapshot() -> Dictionary:
	return CultivationWorldStructure.get_structure_snapshot()


func get_cultivation_world_structure_errors() -> Array[String]:
	return CultivationWorldStructure.validate_structure()


func get_world_selection_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var current_world_id := get_current_world_id()
	for world_id in WORLD_ORDER:
		var entry := get_world_definition(world_id)
		if entry.is_empty():
			continue
		entry["entry_id"] = world_id
		entry["entry_kind"] = "world"
		entry["launch_mode"] = "structured_world_random_start" if world_id == CultivationWorldStructure.get_world_id() else "world_scene"
		entry["target_descriptor"] = "world:%s" % world_id
		entry["is_unlocked"] = is_world_unlocked(world_id)
		entry["is_available"] = can_enter_world(world_id)
		entry["is_test_world"] = false
		entry["is_test_entry"] = false
		entry["is_current_world"] = world_id == current_world_id
		entry["badge_text"] = "\u6b63\u5f0f\u5165\u53e3" if bool(entry.get("is_available", false)) else "\u6682\u672a\u5f00\u653e"
		if world_id == CultivationWorldStructure.get_world_id():
			entry["detail_text"] = "\u6b63\u5f0f\u5165\u53e3\uff1a\u8fdb\u5165\u4fee\u4ed9\u4e16\u754c\u540e\u4ecd\u6309\u56db\u89d2\u968f\u673a\u8d77\u59cb\u89c4\u5219\u5206\u53d1\u3002"
		else:
			entry["detail_text"] = "\u5f53\u524d\u8f6e\u6b21\u4fdd\u7559\u7ed3\u6784\u5360\u4f4d\uff0c\u6682\u4e0d\u5f00\u653e\u6b63\u5f0f\u8fdb\u5165\u3002"
		entries.append(entry)
	if can_enter_world(CultivationWorldStructure.get_world_id()):
		entries.append(_build_frost_wastes_preview_selection_entry())
	return entries


func get_active_scene_entry_context() -> Dictionary:
	return active_scene_entry_context.duplicate(true)


func clear_active_scene_entry_context() -> void:
	active_scene_entry_context.clear()


func is_cultivation_region_preview_active(region_id: String = "") -> bool:
	if str(active_scene_entry_context.get("entry_kind", "")) != "cultivation_region_preview":
		return false
	if region_id.is_empty():
		return true
	return str(active_scene_entry_context.get("region_id", "")) == region_id


func _build_frost_wastes_preview_selection_entry() -> Dictionary:
	return {
		"entry_id": CultivationFrostWastesBlockout.get_preview_entry_id(),
		"world_id": CultivationWorldStructure.get_world_id(),
		"display_name": CultivationFrostWastesBlockout.get_preview_entry_display_name(),
		"scene_path": CultivationWorldStructure.get_region_scene_path(CultivationFrostWastesBlockout.get_region_id()),
		"entry_kind": "cultivation_region_preview",
		"launch_mode": "region_preview",
		"target_descriptor": "region_preview:%s" % CultivationFrostWastesBlockout.get_region_id(),
		"preview_region_id": CultivationFrostWastesBlockout.get_region_id(),
		"is_unlocked": true,
		"is_available": true,
		"is_test_world": true,
		"is_test_entry": true,
		"is_current_world": false,
		"badge_text": "\u6d4b\u8bd5\u76f4\u8fbe",
		"detail_text": "\u5f00\u53d1\u89c2\u5bdf\u5165\u53e3\uff1a\u76f4\u63a5\u8fdb\u5165\u5bd2\u971c\u8352\u539f\u8349\u6a21\uff0c\u4e0d\u8986\u76d6\u6b63\u5f0f\u968f\u673a\u56db\u89d2\u8fdb\u5165\uff0c\u4e5f\u4e0d\u5199\u6b63\u5f0f\u63a2\u7d22\u63a8\u8fdb\u3002",
	}


func get_god_space_scene_path() -> String:
	return GOD_SPACE_SCENE_PATH


func get_tutorial_scene_path() -> String:
	return "res://game/scenes/newbie_village.tscn"


func _ensure_runtime_state_defaults() -> void:
	if not current_character.has("past_life_id"):
		current_character["past_life_id"] = str(current_character.get("background_id", ""))
	if not current_character.has("past_life_name"):
		current_character["past_life_name"] = str(current_character.get("background_name", ""))
	if not current_character.has("background_id"):
		current_character["background_id"] = str(current_character.get("past_life_id", ""))
	if not current_character.has("background_name"):
		current_character["background_name"] = str(current_character.get("past_life_name", ""))
	if not current_character.has("reborn_job_id"):
		current_character["reborn_job_id"] = str(current_character.get("class_id", ""))
	if not current_character.has("reborn_job_name"):
		current_character["reborn_job_name"] = str(current_character.get("class_name", ""))
	if not current_character.has("class_id"):
		current_character["class_id"] = str(current_character.get("reborn_job_id", ""))
	if not current_character.has("class_name"):
		current_character["class_name"] = str(current_character.get("reborn_job_name", ""))
	if not current_character.has("trait_ids"):
		current_character["trait_ids"] = []
	if not current_character.has("trait_names"):
		current_character["trait_names"] = []
	if not current_character.has("strength_id"):
		current_character["strength_id"] = ""
	if not current_character.has("strength_name"):
		current_character["strength_name"] = ""
	if not current_character.has("weakness_id"):
		current_character["weakness_id"] = ""
	if not current_character.has("weakness_name"):
		current_character["weakness_name"] = ""
	if not current_character.has("personality_id"):
		current_character["personality_id"] = ""
	if not current_character.has("personality_name"):
		current_character["personality_name"] = ""
	if not current_character.has("profile_tags"):
		current_character["profile_tags"] = []
	if not current_character.has("granted_triggers"):
		current_character["granted_triggers"] = []
	if not current_character.has("event_flags"):
		current_character["event_flags"] = {}
	if not current_character.has("progress_state"):
		current_character["progress_state"] = _build_default_progress_state()
	else:
		current_character["progress_state"] = _merge_progress_state_defaults(current_character.get("progress_state", {}))
	var skill_persistence: Dictionary = SkillRegistry.export_player_skill_persistence(
		SkillRegistry.build_player_skill_runtime(current_character)
	)
	if not current_character.has("owned_skill_ids"):
		current_character["owned_skill_ids"] = skill_persistence.get("owned_skill_ids", [])
	if not current_character.has("equipped_skill_ids"):
		current_character["equipped_skill_ids"] = skill_persistence.get("equipped_skill_ids", [])
	if not current_character.has("skill_state_overrides"):
		current_character["skill_state_overrides"] = {}
	if not current_character.has("skill_slot_count"):
		current_character["skill_slot_count"] = SkillRegistry.get_default_player_skill_slot_count()


func _get_progress_state_ref() -> Dictionary:
	_ensure_runtime_state_defaults()
	return current_character.get("progress_state", {})


func _build_default_progress_state() -> Dictionary:
	return {
		"tutorial_completed": false,
		"entered_god_space": false,
		"seen_god_space_intro": false,
		"current_world_id": "",
		"current_test_world_id": "cultivation_world",
		"unlocked_world_ids": ["cultivation_world"],
		"world_exploration_state": _build_default_world_exploration_state(),
	}


func _merge_progress_state_defaults(progress_state: Dictionary) -> Dictionary:
	var merged := _build_default_progress_state()
	for key in progress_state.keys():
		merged[key] = progress_state[key]
	var current_test_world_id := str(merged.get("current_test_world_id", "cultivation_world"))
	if not WORLD_DEFINITIONS.has(current_test_world_id):
		current_test_world_id = "cultivation_world"
	merged["current_test_world_id"] = current_test_world_id
	var normalized_world_ids: Array[String] = []
	for entry in merged.get("unlocked_world_ids", []):
		var world_id := str(entry)
		if world_id != "" and WORLD_DEFINITIONS.has(world_id) and not normalized_world_ids.has(world_id):
			normalized_world_ids.append(world_id)
	if normalized_world_ids.is_empty():
		normalized_world_ids.append(current_test_world_id)
	elif not normalized_world_ids.has(current_test_world_id):
		normalized_world_ids.append(current_test_world_id)
	merged["unlocked_world_ids"] = normalized_world_ids
	merged["world_exploration_state"] = _merge_world_exploration_state_defaults(merged.get("world_exploration_state", {}))
	var current_world_id := str(merged.get("current_world_id", ""))
	if current_world_id != "" and not WORLD_DEFINITIONS.has(current_world_id):
		merged["current_world_id"] = ""
	return merged


func _begin_random_cultivation_world_exploration() -> String:
	var start_region_ids := CultivationWorldStructure.get_start_region_ids()
	if start_region_ids.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var start_region_id := start_region_ids[rng.randi_range(0, start_region_ids.size() - 1)]
	return begin_cultivation_world_exploration_from_region(start_region_id)


func _can_travel_in_cultivation_world(current_region_id: String, target_region_id: String, exploration_state: Dictionary) -> bool:
	if not CultivationWorldStructure.get_connected_region_ids(current_region_id).has(target_region_id):
		return false
	if CultivationWorldStructure.is_edge_region(target_region_id):
		return CultivationWorldStructure.is_start_region(current_region_id)
	if CultivationWorldStructure.is_center_region(target_region_id):
		return CultivationWorldStructure.is_edge_region(current_region_id) and bool(exploration_state.get("entered_edge", false))
	return false


func _get_world_exploration_state_ref() -> Dictionary:
	_ensure_runtime_state_defaults()
	return _get_progress_state_ref().get("world_exploration_state", {})


func _set_world_exploration_state(exploration_state: Dictionary) -> void:
	var progress_state := _get_progress_state_ref()
	progress_state["world_exploration_state"] = _merge_world_exploration_state_defaults(exploration_state)
	current_character["progress_state"] = progress_state


func _build_default_world_exploration_state() -> Dictionary:
	return {
		"active_world_id": "",
		"start_region_id": "",
		"current_region_id": "",
		"entered_edge": false,
		"entered_core": false,
		"interrupted_by_death": false,
		"last_exit_reason": "",
	}


func _merge_world_exploration_state_defaults(exploration_state: Dictionary) -> Dictionary:
	var merged := _build_default_world_exploration_state()
	for key in exploration_state.keys():
		merged[key] = exploration_state[key]

	var active_world_id := str(merged.get("active_world_id", ""))
	if active_world_id != "" and not WORLD_DEFINITIONS.has(active_world_id):
		active_world_id = ""
	merged["active_world_id"] = active_world_id

	var start_region_id := str(merged.get("start_region_id", ""))
	if not start_region_id.is_empty() and not CultivationWorldStructure.is_start_region(start_region_id):
		start_region_id = ""
	merged["start_region_id"] = start_region_id

	var current_region_id := str(merged.get("current_region_id", ""))
	if not current_region_id.is_empty() and not CultivationWorldStructure.is_region_id_valid(current_region_id):
		current_region_id = ""
	merged["current_region_id"] = current_region_id

	if active_world_id != CultivationWorldStructure.get_world_id():
		merged["start_region_id"] = ""
		merged["current_region_id"] = ""
		merged["entered_edge"] = false
		merged["entered_core"] = false
	elif current_region_id.is_empty():
		merged["entered_edge"] = false
		merged["entered_core"] = false
	elif CultivationWorldStructure.is_center_region(current_region_id):
		merged["entered_edge"] = true
		merged["entered_core"] = true
	elif CultivationWorldStructure.is_edge_region(current_region_id):
		merged["entered_edge"] = true

	return merged
