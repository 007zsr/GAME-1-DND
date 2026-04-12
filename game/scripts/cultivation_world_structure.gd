extends RefCounted
class_name CultivationWorldStructure

const WORLD_ID := "cultivation_world"

const REGION_TYPE_CORNER_START := "corner_start"
const REGION_TYPE_EDGE_REGION := "edge_region"
const REGION_TYPE_CENTER_CORE := "center_core"

const REGION_ID_CORNER_NORTHWEST := "corner_northwest"
const REGION_ID_CORNER_NORTHEAST := "corner_northeast"
const REGION_ID_CORNER_SOUTHWEST := "corner_southwest"
const REGION_ID_CORNER_SOUTHEAST := "corner_southeast"
const REGION_ID_EDGE_NORTH := "edge_north"
const REGION_ID_EDGE_SOUTH := "edge_south"
const REGION_ID_EDGE_WEST := "edge_west"
const REGION_ID_EDGE_EAST := "edge_east_luanxinghai"
const REGION_ID_CENTER := "center_zhongzhou"

const REGION_ORDER := [
	REGION_ID_CORNER_NORTHWEST,
	REGION_ID_CORNER_NORTHEAST,
	REGION_ID_CORNER_SOUTHWEST,
	REGION_ID_CORNER_SOUTHEAST,
	REGION_ID_EDGE_NORTH,
	REGION_ID_EDGE_SOUTH,
	REGION_ID_EDGE_WEST,
	REGION_ID_EDGE_EAST,
	REGION_ID_CENTER,
]

const REGION_DEFINITIONS := {
	REGION_ID_CORNER_NORTHWEST: {
		"region_id": REGION_ID_CORNER_NORTHWEST,
		"display_name": "\u5bd2\u971c\u8352\u539f",
		"region_type": REGION_TYPE_CORNER_START,
		"scene_path": "res://game/scenes/cultivation_region_corner_northwest.tscn",
		"connected_region_ids": [REGION_ID_EDGE_NORTH, REGION_ID_EDGE_WEST],
	},
	REGION_ID_CORNER_NORTHEAST: {
		"region_id": REGION_ID_CORNER_NORTHEAST,
		"display_name": "\u53f3\u4e0a\u89d2\u8d77\u59cb\u533a\u57df",
		"region_type": REGION_TYPE_CORNER_START,
		"scene_path": "res://game/scenes/cultivation_region_corner_northeast.tscn",
		"connected_region_ids": [REGION_ID_EDGE_NORTH, REGION_ID_EDGE_EAST],
	},
	REGION_ID_CORNER_SOUTHWEST: {
		"region_id": REGION_ID_CORNER_SOUTHWEST,
		"display_name": "\u5de6\u4e0b\u89d2\u8d77\u59cb\u533a\u57df",
		"region_type": REGION_TYPE_CORNER_START,
		"scene_path": "res://game/scenes/cultivation_region_corner_southwest.tscn",
		"connected_region_ids": [REGION_ID_EDGE_SOUTH, REGION_ID_EDGE_WEST],
	},
	REGION_ID_CORNER_SOUTHEAST: {
		"region_id": REGION_ID_CORNER_SOUTHEAST,
		"display_name": "\u53f3\u4e0b\u89d2\u8d77\u59cb\u533a\u57df",
		"region_type": REGION_TYPE_CORNER_START,
		"scene_path": "res://game/scenes/cultivation_region_corner_southeast.tscn",
		"connected_region_ids": [REGION_ID_EDGE_SOUTH, REGION_ID_EDGE_EAST],
	},
	REGION_ID_EDGE_NORTH: {
		"region_id": REGION_ID_EDGE_NORTH,
		"display_name": "\u5317\u5883",
		"region_type": REGION_TYPE_EDGE_REGION,
		"scene_path": "res://game/scenes/cultivation_region_edge_north.tscn",
		"connected_region_ids": [REGION_ID_CENTER],
	},
	REGION_ID_EDGE_SOUTH: {
		"region_id": REGION_ID_EDGE_SOUTH,
		"display_name": "\u5357\u86ee",
		"region_type": REGION_TYPE_EDGE_REGION,
		"scene_path": "res://game/scenes/cultivation_region_edge_south.tscn",
		"connected_region_ids": [REGION_ID_CENTER],
	},
	REGION_ID_EDGE_WEST: {
		"region_id": REGION_ID_EDGE_WEST,
		"display_name": "\u897f\u8fb9\u5927\u5c71",
		"region_type": REGION_TYPE_EDGE_REGION,
		"scene_path": "res://game/scenes/cultivation_region_edge_west.tscn",
		"connected_region_ids": [REGION_ID_CENTER],
	},
	REGION_ID_EDGE_EAST: {
		"region_id": REGION_ID_EDGE_EAST,
		"display_name": "\u4e71\u661f\u6d77",
		"region_type": REGION_TYPE_EDGE_REGION,
		"scene_path": "res://game/scenes/cultivation_region_edge_east_luanxinghai.tscn",
		"connected_region_ids": [REGION_ID_CENTER],
	},
	REGION_ID_CENTER: {
		"region_id": REGION_ID_CENTER,
		"display_name": "\u4e2d\u5dde",
		"region_type": REGION_TYPE_CENTER_CORE,
		"scene_path": "res://game/scenes/cultivation_region_core_zhongzhou.tscn",
		"connected_region_ids": [],
	},
}


static func get_world_id() -> String:
	return WORLD_ID


static func get_region_ids() -> Array[String]:
	var results: Array[String] = []
	for region_id in REGION_ORDER:
		results.append(region_id)
	return results


static func get_region_definition(region_id: String) -> Dictionary:
	if not REGION_DEFINITIONS.has(region_id):
		return {}
	return (REGION_DEFINITIONS[region_id] as Dictionary).duplicate(true)


static func get_region_definition_by_scene_path(scene_path: String) -> Dictionary:
	for region_id in REGION_ORDER:
		var definition := get_region_definition(region_id)
		if str(definition.get("scene_path", "")) == scene_path:
			return definition
	return {}


static func get_region_id_by_scene_path(scene_path: String) -> String:
	var definition := get_region_definition_by_scene_path(scene_path)
	return str(definition.get("region_id", ""))


static func get_region_scene_path(region_id: String) -> String:
	var definition := get_region_definition(region_id)
	return str(definition.get("scene_path", ""))


static func get_region_display_name(region_id: String) -> String:
	var definition := get_region_definition(region_id)
	return str(definition.get("display_name", ""))


static func get_region_type(region_id: String) -> String:
	var definition := get_region_definition(region_id)
	return str(definition.get("region_type", ""))


static func get_connected_region_ids(region_id: String) -> Array[String]:
	var definition := get_region_definition(region_id)
	var results: Array[String] = []
	for entry in definition.get("connected_region_ids", []):
		results.append(str(entry))
	return results


static func get_start_region_ids() -> Array[String]:
	return [
		REGION_ID_CORNER_NORTHWEST,
		REGION_ID_CORNER_NORTHEAST,
		REGION_ID_CORNER_SOUTHWEST,
		REGION_ID_CORNER_SOUTHEAST,
	]


static func get_edge_region_ids() -> Array[String]:
	return [
		REGION_ID_EDGE_NORTH,
		REGION_ID_EDGE_SOUTH,
		REGION_ID_EDGE_WEST,
		REGION_ID_EDGE_EAST,
	]


static func get_center_region_id() -> String:
	return REGION_ID_CENTER


static func get_default_start_region_id() -> String:
	return REGION_ID_CORNER_NORTHWEST


static func is_region_id_valid(region_id: String) -> bool:
	return REGION_DEFINITIONS.has(region_id)


static func is_start_region(region_id: String) -> bool:
	return get_start_region_ids().has(region_id)


static func is_edge_region(region_id: String) -> bool:
	return get_edge_region_ids().has(region_id)


static func is_center_region(region_id: String) -> bool:
	return region_id == REGION_ID_CENTER


static func get_structure_snapshot() -> Dictionary:
	var regions: Array[Dictionary] = []
	for region_id in REGION_ORDER:
		regions.append(get_region_definition(region_id))
	return {
		"world_id": WORLD_ID,
		"region_count": REGION_ORDER.size(),
		"start_region_ids": get_start_region_ids(),
		"edge_region_ids": get_edge_region_ids(),
		"center_region_id": get_center_region_id(),
		"regions": regions,
	}


static func validate_structure() -> Array[String]:
	var errors: Array[String] = []
	if REGION_ORDER.size() != 9:
		errors.append("region count should be 9, got %d" % REGION_ORDER.size())
	if get_start_region_ids().size() != 4:
		errors.append("start region count should be 4")
	if get_edge_region_ids().size() != 4:
		errors.append("edge region count should be 4")
	if get_center_region_id().is_empty():
		errors.append("center region id missing")

	var seen_scene_paths: Array[String] = []
	for region_id in REGION_ORDER:
		var definition := get_region_definition(region_id)
		if definition.is_empty():
			errors.append("missing definition for %s" % region_id)
			continue
		var display_name := str(definition.get("display_name", ""))
		if display_name.is_empty():
			errors.append("display name missing for %s" % region_id)
		var region_type := str(definition.get("region_type", ""))
		if region_type.is_empty():
			errors.append("region type missing for %s" % region_id)
		var scene_path := str(definition.get("scene_path", ""))
		if scene_path.is_empty():
			errors.append("scene path missing for %s" % region_id)
		elif seen_scene_paths.has(scene_path):
			errors.append("scene path duplicated: %s" % scene_path)
		else:
			seen_scene_paths.append(scene_path)
		for target_region_id in get_connected_region_ids(region_id):
			if not is_region_id_valid(target_region_id):
				errors.append("invalid connection %s -> %s" % [region_id, target_region_id])

	if get_region_display_name(REGION_ID_EDGE_EAST) != "\u4e71\u661f\u6d77":
		errors.append("east edge region display name mismatch")
	if get_region_display_name(REGION_ID_CENTER) != "\u4e2d\u5dde":
		errors.append("center region display name mismatch")
	if get_region_display_name(REGION_ID_CORNER_NORTHWEST) != "\u5bd2\u971c\u8352\u539f":
		errors.append("northwest corner display name mismatch")
	if get_connected_region_ids(REGION_ID_CORNER_NORTHWEST) != [REGION_ID_EDGE_NORTH, REGION_ID_EDGE_WEST]:
		errors.append("northwest corner connections mismatch")
	if get_connected_region_ids(REGION_ID_CORNER_NORTHEAST) != [REGION_ID_EDGE_NORTH, REGION_ID_EDGE_EAST]:
		errors.append("northeast corner connections mismatch")
	if get_connected_region_ids(REGION_ID_CORNER_SOUTHWEST) != [REGION_ID_EDGE_SOUTH, REGION_ID_EDGE_WEST]:
		errors.append("southwest corner connections mismatch")
	if get_connected_region_ids(REGION_ID_CORNER_SOUTHEAST) != [REGION_ID_EDGE_SOUTH, REGION_ID_EDGE_EAST]:
		errors.append("southeast corner connections mismatch")
	for edge_region_id in get_edge_region_ids():
		if get_connected_region_ids(edge_region_id) != [REGION_ID_CENTER]:
			errors.append("edge region %s must only connect to center" % edge_region_id)
	if not get_connected_region_ids(REGION_ID_CENTER).is_empty():
		errors.append("center region should not expose outgoing progression nodes at this stage")
	return errors
