extends RefCounted
class_name SkillRuntime

const STATE_KEYS := [
	"owner_id",
	"skill_id",
	"is_owned",
	"is_equipped",
	"slot_index",
	"is_enabled",
	"cooldown_state",
	"skill_level",
	"charges",
	"stacks",
]


static func normalize_skill_definition(definition: Dictionary) -> Dictionary:
	var skill_id := str(definition.get("skill_id", definition.get("id", "")))
	var normalized: Dictionary = {
		"skill_id": skill_id,
		"display_name": str(definition.get("display_name", definition.get("name", skill_id))),
		"skill_type": str(definition.get("skill_type", "active")),
		"tags": _normalize_string_array(definition.get("tags", [])),
		"description_key": str(definition.get("description_key", "")),
		"summary": str(definition.get("summary", definition.get("description", ""))),
		"execution_key": str(definition.get("execution_key", definition.get("logic_key", ""))),
		"parameters": (definition.get("parameters", {}) as Dictionary).duplicate(true),
	}
	return normalized


static func build_owner_runtime(
	owner_id: String,
	owner_kind: String,
	slot_count: int,
	skill_definitions: Array,
	owned_skill_ids: Array[String],
	equipped_skill_ids: Array[String],
	persisted_state_overrides: Dictionary = {}
) -> Dictionary:
	var runtime := {
		"owner_id": owner_id,
		"owner_kind": owner_kind,
		"slot_count": max(slot_count, 0),
		"definition_order": [],
		"definitions": {},
		"states": {},
		"equipped_slots": [],
	}

	for _slot_index in range(int(runtime["slot_count"])):
		(runtime["equipped_slots"] as Array).append("")

	for entry in skill_definitions:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		register_definition(runtime, entry as Dictionary)

	for skill_id in runtime["definition_order"]:
		var normalized_skill_id := str(skill_id)
		var overrides := (persisted_state_overrides.get(normalized_skill_id, {}) as Dictionary).duplicate(true)
		var state := _make_default_state(owner_id, normalized_skill_id)
		if not overrides.is_empty():
			state = _merge_state_overrides(state, overrides)
		state["is_owned"] = owned_skill_ids.has(normalized_skill_id)
		runtime["states"][normalized_skill_id] = state

	for slot_index in range(min(equipped_skill_ids.size(), int(runtime["slot_count"]))):
		equip_skill_to_slot(runtime, str(equipped_skill_ids[slot_index]), slot_index)

	return runtime


static func register_definition(runtime: Dictionary, definition: Dictionary) -> void:
	var normalized := normalize_skill_definition(definition)
	var skill_id := str(normalized.get("skill_id", ""))
	if skill_id.is_empty():
		return
	var definitions: Dictionary = runtime.get("definitions", {})
	definitions[skill_id] = normalized
	runtime["definitions"] = definitions
	var definition_order: Array = runtime.get("definition_order", [])
	if not definition_order.has(skill_id):
		definition_order.append(skill_id)
	runtime["definition_order"] = definition_order
	if not (runtime.get("states", {}) as Dictionary).has(skill_id):
		var states: Dictionary = runtime.get("states", {})
		states[skill_id] = _make_default_state(str(runtime.get("owner_id", "")), skill_id)
		runtime["states"] = states


static func get_definition(runtime: Dictionary, skill_id: String) -> Dictionary:
	return ((runtime.get("definitions", {}) as Dictionary).get(skill_id, {}) as Dictionary).duplicate(true)


static func get_state(runtime: Dictionary, skill_id: String) -> Dictionary:
	return ((runtime.get("states", {}) as Dictionary).get(skill_id, {}) as Dictionary).duplicate(true)


static func get_state_ref(runtime: Dictionary, skill_id: String) -> Dictionary:
	return (runtime.get("states", {}) as Dictionary).get(skill_id, {}) as Dictionary


static func get_slot_count(runtime: Dictionary) -> int:
	return int(runtime.get("slot_count", 0))


static func get_definition_order(runtime: Dictionary) -> Array[String]:
	var results: Array[String] = []
	for entry in runtime.get("definition_order", []):
		results.append(str(entry))
	return results


static func get_owned_skill_ids(runtime: Dictionary) -> Array[String]:
	var owned_skill_ids: Array[String] = []
	for skill_id in get_definition_order(runtime):
		var state := get_state(runtime, skill_id)
		if bool(state.get("is_owned", false)):
			owned_skill_ids.append(skill_id)
	return owned_skill_ids


static func get_equipped_skill_ids(runtime: Dictionary) -> Array[String]:
	var results: Array[String] = []
	for entry in runtime.get("equipped_slots", []):
		results.append(str(entry))
	return results


static func get_equipped_skill_id_at_slot(runtime: Dictionary, slot_index: int) -> String:
	var slots: Array = runtime.get("equipped_slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		return ""
	return str(slots[slot_index])


static func owns_skill(runtime: Dictionary, skill_id: String) -> bool:
	return bool(get_state(runtime, skill_id).get("is_owned", false))


static func is_skill_equipped(runtime: Dictionary, skill_id: String) -> bool:
	return bool(get_state(runtime, skill_id).get("is_equipped", false))


static func is_skill_enabled(runtime: Dictionary, skill_id: String) -> bool:
	return bool(get_state(runtime, skill_id).get("is_enabled", false))


static func is_skill_ready(runtime: Dictionary, skill_id: String) -> bool:
	var cooldown_state: Dictionary = get_state(runtime, skill_id).get("cooldown_state", {})
	return float(cooldown_state.get("remaining", 0.0)) <= 0.0


static func can_trigger_skill(runtime: Dictionary, skill_id: String, require_equipped: bool = true) -> bool:
	var state := get_state(runtime, skill_id)
	if state.is_empty():
		return false
	if not bool(state.get("is_owned", false)):
		return false
	if require_equipped and not bool(state.get("is_equipped", false)):
		return false
	if not bool(state.get("is_enabled", false)):
		return false
	return float((state.get("cooldown_state", {}) as Dictionary).get("remaining", 0.0)) <= 0.0


static func equip_skill_to_first_empty_slot(runtime: Dictionary, skill_id: String) -> bool:
	var slots: Array = runtime.get("equipped_slots", [])
	for slot_index in range(slots.size()):
		if str(slots[slot_index]).is_empty():
			return equip_skill_to_slot(runtime, skill_id, slot_index)
	return false


static func equip_skill_to_slot(runtime: Dictionary, skill_id: String, slot_index: int) -> bool:
	if skill_id.is_empty():
		return false
	if slot_index < 0 or slot_index >= get_slot_count(runtime):
		return false
	if not owns_skill(runtime, skill_id):
		return false

	var previous_skill_id := get_equipped_skill_id_at_slot(runtime, slot_index)
	if previous_skill_id == skill_id:
		return true

	if not previous_skill_id.is_empty():
		unequip_skill(runtime, previous_skill_id)

	if is_skill_equipped(runtime, skill_id):
		unequip_skill(runtime, skill_id)

	var slots: Array = runtime.get("equipped_slots", [])
	slots[slot_index] = skill_id
	runtime["equipped_slots"] = slots

	var state_ref := get_state_ref(runtime, skill_id)
	if state_ref.is_empty():
		return false
	state_ref["is_equipped"] = true
	state_ref["slot_index"] = slot_index
	return true


static func unequip_skill(runtime: Dictionary, skill_id: String) -> bool:
	if skill_id.is_empty():
		return false
	if not is_skill_equipped(runtime, skill_id):
		return false
	var slots: Array = runtime.get("equipped_slots", [])
	for slot_index in range(slots.size()):
		if str(slots[slot_index]) == skill_id:
			slots[slot_index] = ""
	runtime["equipped_slots"] = slots

	var state_ref := get_state_ref(runtime, skill_id)
	if not state_ref.is_empty():
		state_ref["is_equipped"] = false
		state_ref["slot_index"] = -1
	return true


static func unequip_skill_at_slot(runtime: Dictionary, slot_index: int) -> bool:
	var skill_id := get_equipped_skill_id_at_slot(runtime, slot_index)
	if skill_id.is_empty():
		return false
	return unequip_skill(runtime, skill_id)


static func set_skill_enabled(runtime: Dictionary, skill_id: String, enabled: bool) -> void:
	var state_ref := get_state_ref(runtime, skill_id)
	if state_ref.is_empty():
		return
	state_ref["is_enabled"] = enabled


static func set_cooldown(runtime: Dictionary, skill_id: String, duration: float) -> void:
	var state_ref := get_state_ref(runtime, skill_id)
	if state_ref.is_empty():
		return
	var final_duration := maxf(duration, 0.0)
	state_ref["cooldown_state"] = {
		"remaining": final_duration,
		"duration": final_duration,
	}


static func clear_cooldown(runtime: Dictionary, skill_id: String) -> void:
	set_cooldown(runtime, skill_id, 0.0)


static func get_cooldown_remaining(runtime: Dictionary, skill_id: String) -> float:
	return float((get_state(runtime, skill_id).get("cooldown_state", {}) as Dictionary).get("remaining", 0.0))


static func get_cooldown_duration(runtime: Dictionary, skill_id: String) -> float:
	return float((get_state(runtime, skill_id).get("cooldown_state", {}) as Dictionary).get("duration", 0.0))


static func tick_cooldowns(runtime: Dictionary, delta: float) -> void:
	var states: Dictionary = runtime.get("states", {})
	for skill_id in states.keys():
		var state_ref := states.get(skill_id, {}) as Dictionary
		if state_ref.is_empty():
			continue
		var cooldown_state := (state_ref.get("cooldown_state", {}) as Dictionary).duplicate(true)
		var remaining := maxf(float(cooldown_state.get("remaining", 0.0)) - delta, 0.0)
		cooldown_state["remaining"] = remaining
		if remaining <= 0.0 and float(cooldown_state.get("duration", 0.0)) < 0.0:
			cooldown_state["duration"] = 0.0
		state_ref["cooldown_state"] = cooldown_state


static func copy_cooldowns_from(runtime: Dictionary, source_runtime: Dictionary) -> void:
	if source_runtime.is_empty():
		return
	for skill_id in get_definition_order(runtime):
		if not (source_runtime.get("states", {}) as Dictionary).has(skill_id):
			continue
		var source_state := get_state(source_runtime, skill_id)
		var source_cooldown := (source_state.get("cooldown_state", {}) as Dictionary).duplicate(true)
		var target_state := get_state_ref(runtime, skill_id)
		if target_state.is_empty():
			continue
		target_state["cooldown_state"] = source_cooldown


static func export_state_overrides(runtime: Dictionary) -> Dictionary:
	var exported: Dictionary = {}
	for skill_id in get_definition_order(runtime):
		var state := get_state(runtime, skill_id)
		exported[skill_id] = {
			"is_enabled": bool(state.get("is_enabled", true)),
		}
	return exported


static func _make_default_state(owner_id: String, skill_id: String) -> Dictionary:
	return {
		"owner_id": owner_id,
		"skill_id": skill_id,
		"is_owned": false,
		"is_equipped": false,
		"slot_index": -1,
		"is_enabled": true,
		"cooldown_state": {
			"remaining": 0.0,
			"duration": 0.0,
		},
		"skill_level": 1,
		"charges": 0,
		"stacks": 0,
	}


static func _merge_state_overrides(base_state: Dictionary, overrides: Dictionary) -> Dictionary:
	var merged := base_state.duplicate(true)
	for key in overrides.keys():
		if key == "cooldown_state":
			continue
		if STATE_KEYS.has(str(key)):
			merged[str(key)] = overrides[key]
	return merged


static func _normalize_string_array(values: Variant) -> Array[String]:
	var results: Array[String] = []
	if typeof(values) != TYPE_ARRAY:
		return results
	for entry in values:
		results.append(str(entry))
	return results
