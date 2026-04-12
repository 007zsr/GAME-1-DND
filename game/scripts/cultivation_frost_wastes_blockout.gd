extends RefCounted
class_name CultivationFrostWastesBlockout

const REGION_ID := "corner_northwest"
const REGION_DISPLAY_NAME := "\u5bd2\u971c\u8352\u539f"
const PREVIEW_ENTRY_ID := "cultivation_frost_wastes_preview"
const PREVIEW_ENTRY_DISPLAY_NAME := "\u4fee\u4ed9\u4e16\u754c\uff1a\u5bd2\u971c\u8352\u539f\u76f4\u8fbe\uff08\u6d4b\u8bd5\uff09"
const BLOCKOUT_SCALE := 10.0
const WORLD_BOUNDS_PADDING_METERS := 2.0 * BLOCKOUT_SCALE
const SPAWN_POINT_METERS := Vector2(24.2, 22.6)

const OUTER_BOUNDARY_POINTS := [
	Vector2(10.0, 11.0),
	Vector2(17.5, 9.2),
	Vector2(28.8, 8.5),
	Vector2(40.0, 8.2),
	Vector2(53.2, 9.0),
	Vector2(66.8, 11.0),
	Vector2(79.0, 16.5),
	Vector2(81.0, 24.0),
	Vector2(81.2, 34.5),
	Vector2(77.2, 43.0),
	Vector2(70.5, 49.0),
	Vector2(58.4, 51.2),
	Vector2(44.0, 52.0),
	Vector2(28.8, 52.0),
	Vector2(17.2, 49.8),
	Vector2(10.6, 43.2),
	Vector2(9.3, 33.0),
	Vector2(9.5, 22.0),
]

const AREA_ORDER := [
	"watchtower",
	"hunters_ruin",
	"embers_camp",
	"burial_slope",
	"battlefield_edge",
	"frozen_river_breach",
	"oath_ruins",
	"exit_north_border",
	"exit_west_mountain",
]

const AREA_DEFINITIONS := {
	"watchtower": {
		"area_id": "watchtower",
		"display_name": "[1] \u65ad\u89d2\u77ad\u671b\u53f0",
		"polygon_points": [
			Vector2(30.0, 10.6),
			Vector2(38.8, 10.4),
			Vector2(41.4, 12.0),
			Vector2(40.2, 16.2),
			Vector2(34.6, 16.1),
			Vector2(32.2, 14.4),
			Vector2(29.2, 15.0),
			Vector2(27.8, 12.5),
		],
		"label_anchor": Vector2(33.8, 12.2),
		"label_size": Vector2(8.8, 2.2),
		"links": ["hunters_ruin"],
		"is_exit": false,
		"exit_target_display": "",
	},
	"hunters_ruin": {
		"area_id": "hunters_ruin",
		"display_name": "[2] \u8352\u730e\u4eba\u6b8b\u5c4b",
		"polygon_points": [
			Vector2(18.0, 18.7),
			Vector2(24.8, 18.0),
			Vector2(28.0, 19.2),
			Vector2(31.8, 18.4),
			Vector2(36.0, 20.0),
			Vector2(35.4, 23.6),
			Vector2(31.8, 25.0),
			Vector2(27.0, 24.1),
			Vector2(22.8, 25.2),
			Vector2(18.4, 23.7),
			Vector2(17.6, 21.0),
		],
		"label_anchor": Vector2(20.6, 20.0),
		"label_size": Vector2(10.0, 2.2),
		"links": ["watchtower", "embers_camp", "burial_slope"],
		"is_exit": false,
		"exit_target_display": "",
	},
	"embers_camp": {
		"area_id": "embers_camp",
		"display_name": "[3] \u6b8b\u706b\u8425\u5730",
		"polygon_points": [
			Vector2(44.0, 18.8),
			Vector2(53.6, 18.5),
			Vector2(57.1, 20.8),
			Vector2(56.4, 24.5),
			Vector2(49.8, 25.4),
			Vector2(46.0, 24.2),
			Vector2(42.8, 22.2),
		],
		"label_anchor": Vector2(46.2, 20.2),
		"label_size": Vector2(8.6, 2.0),
		"links": ["hunters_ruin", "battlefield_edge"],
		"is_exit": false,
		"exit_target_display": "",
	},
	"burial_slope": {
		"area_id": "burial_slope",
		"display_name": "[4] \u57cb\u9aa8\u96ea\u5761",
		"polygon_points": [
			Vector2(24.0, 27.8),
			Vector2(31.4, 28.0),
			Vector2(35.8, 29.6),
			Vector2(38.3, 32.8),
			Vector2(35.8, 36.6),
			Vector2(30.6, 37.4),
			Vector2(25.0, 36.4),
			Vector2(21.8, 33.4),
		],
		"label_anchor": Vector2(24.0, 29.6),
		"label_size": Vector2(8.4, 2.0),
		"links": ["hunters_ruin", "battlefield_edge", "frozen_river_breach"],
		"is_exit": false,
		"exit_target_display": "",
	},
	"battlefield_edge": {
		"area_id": "battlefield_edge",
		"display_name": "[5] \u51b0\u5c01\u53e4\u6218\u573a\u8fb9\u7f18",
		"polygon_points": [
			Vector2(46.0, 27.3),
			Vector2(55.4, 27.0),
			Vector2(63.8, 29.4),
			Vector2(64.5, 34.0),
			Vector2(61.8, 36.8),
			Vector2(54.8, 37.6),
			Vector2(47.4, 36.6),
			Vector2(44.2, 33.2),
		],
		"label_anchor": Vector2(47.2, 29.2),
		"label_size": Vector2(11.2, 2.0),
		"links": ["embers_camp", "burial_slope", "oath_ruins", "exit_north_border"],
		"is_exit": false,
		"exit_target_display": "",
	},
	"frozen_river_breach": {
		"area_id": "frozen_river_breach",
		"display_name": "[6] \u51bb\u6cb3\u88c2\u53e3",
		"polygon_points": [
			Vector2(23.0, 39.4),
			Vector2(28.4, 38.8),
			Vector2(32.2, 40.0),
			Vector2(34.2, 41.4),
			Vector2(38.2, 42.4),
			Vector2(39.0, 44.8),
			Vector2(36.4, 46.6),
			Vector2(31.2, 47.1),
			Vector2(27.6, 46.1),
			Vector2(24.0, 44.5),
			Vector2(22.2, 42.0),
		],
		"label_anchor": Vector2(25.8, 40.2),
		"label_size": Vector2(8.8, 2.0),
		"links": ["burial_slope", "oath_ruins", "exit_west_mountain"],
		"is_exit": false,
		"exit_target_display": "",
	},
	"oath_ruins": {
		"area_id": "oath_ruins",
		"display_name": "[7] \u5b88\u8a93\u53f0\u9057\u5740",
		"polygon_points": [
			Vector2(49.0, 40.0),
			Vector2(55.0, 39.0),
			Vector2(60.5, 40.8),
			Vector2(62.0, 43.8),
			Vector2(58.8, 46.1),
			Vector2(53.2, 46.6),
			Vector2(48.2, 44.4),
		],
		"label_anchor": Vector2(50.6, 40.7),
		"label_size": Vector2(8.6, 2.0),
		"links": ["battlefield_edge", "frozen_river_breach"],
		"is_exit": false,
		"exit_target_display": "",
	},
	"exit_north_border": {
		"area_id": "exit_north_border",
		"display_name": "[\u51fa\u53e3A] \u65ad\u57ce\u5173 -> \u5317\u7586",
		"polygon_points": [
			Vector2(66.0, 29.0),
			Vector2(71.0, 27.8),
			Vector2(76.5, 28.4),
			Vector2(79.0, 30.4),
			Vector2(78.4, 32.8),
			Vector2(74.8, 33.6),
			Vector2(69.0, 33.0),
			Vector2(66.4, 31.4),
		],
		"label_anchor": Vector2(69.6, 27.7),
		"label_size": Vector2(10.4, 1.8),
		"links": ["battlefield_edge"],
		"is_exit": true,
		"exit_target_display": "\u5317\u7586",
	},
	"exit_west_mountain": {
		"area_id": "exit_west_mountain",
		"display_name": "[\u51fa\u53e3B] \u88c2\u5ca9\u65e7\u9053 -> \u897f\u8fb9\u5927\u5c71",
		"polygon_points": [
			Vector2(22.0, 48.0),
			Vector2(29.0, 47.4),
			Vector2(36.2, 47.6),
			Vector2(40.8, 49.0),
			Vector2(39.0, 50.6),
			Vector2(31.8, 51.0),
			Vector2(24.6, 50.7),
			Vector2(21.6, 49.2),
		],
		"label_anchor": Vector2(24.4, 47.1),
		"label_size": Vector2(12.8, 1.8),
		"links": ["frozen_river_breach"],
		"is_exit": true,
		"exit_target_display": "\u897f\u8fb9\u5927\u5c71",
	},
}

const ROUTE_ORDER := [
	"watchtower->hunters_ruin",
	"hunters_ruin->embers_camp",
	"hunters_ruin->burial_slope",
	"embers_camp->battlefield_edge",
	"burial_slope->battlefield_edge",
	"burial_slope->frozen_river_breach",
	"battlefield_edge->oath_ruins",
	"battlefield_edge->exit_north_border",
	"frozen_river_breach->oath_ruins",
	"frozen_river_breach->exit_west_mountain",
]

const ROUTE_DEFINITIONS := {
	"watchtower->hunters_ruin": {
		"from_area_id": "watchtower",
		"to_area_id": "hunters_ruin",
		"route_kind": "main",
		"polygon_points": [
			Vector2(30.8, 15.2),
			Vector2(33.8, 15.0),
			Vector2(34.4, 16.6),
			Vector2(34.0, 18.6),
			Vector2(32.6, 20.0),
			Vector2(30.2, 20.2),
			Vector2(29.2, 18.0),
			Vector2(29.8, 16.2),
		],
	},
	"hunters_ruin->embers_camp": {
		"from_area_id": "hunters_ruin",
		"to_area_id": "embers_camp",
		"route_kind": "branch",
		"polygon_points": [
			Vector2(35.0, 20.2),
			Vector2(39.0, 19.8),
			Vector2(43.0, 20.2),
			Vector2(44.4, 21.8),
			Vector2(43.4, 23.6),
			Vector2(39.8, 23.8),
			Vector2(36.0, 23.2),
			Vector2(34.8, 21.8),
		],
	},
	"hunters_ruin->burial_slope": {
		"from_area_id": "hunters_ruin",
		"to_area_id": "burial_slope",
		"route_kind": "main",
		"polygon_points": [
			Vector2(24.2, 24.0),
			Vector2(29.5, 23.6),
			Vector2(31.6, 24.8),
			Vector2(32.2, 27.4),
			Vector2(31.0, 30.2),
			Vector2(28.6, 31.2),
			Vector2(25.8, 30.0),
			Vector2(23.8, 27.4),
		],
	},
	"embers_camp->battlefield_edge": {
		"from_area_id": "embers_camp",
		"to_area_id": "battlefield_edge",
		"route_kind": "branch",
		"polygon_points": [
			Vector2(50.8, 24.8),
			Vector2(53.4, 24.5),
			Vector2(55.8, 25.8),
			Vector2(56.4, 28.4),
			Vector2(55.2, 30.0),
			Vector2(52.6, 30.0),
			Vector2(50.6, 28.6),
			Vector2(49.8, 26.4),
		],
	},
	"burial_slope->battlefield_edge": {
		"from_area_id": "burial_slope",
		"to_area_id": "battlefield_edge",
		"route_kind": "main",
		"polygon_points": [
			Vector2(37.0, 30.8),
			Vector2(42.5, 30.6),
			Vector2(46.8, 31.2),
			Vector2(47.6, 33.6),
			Vector2(46.2, 35.0),
			Vector2(41.0, 35.2),
			Vector2(37.4, 34.4),
			Vector2(36.6, 32.6),
		],
	},
	"burial_slope->frozen_river_breach": {
		"from_area_id": "burial_slope",
		"to_area_id": "frozen_river_breach",
		"route_kind": "main",
		"polygon_points": [
			Vector2(27.2, 35.6),
			Vector2(31.5, 35.2),
			Vector2(33.6, 36.5),
			Vector2(34.0, 39.6),
			Vector2(32.8, 41.4),
			Vector2(29.4, 41.8),
			Vector2(27.0, 40.6),
			Vector2(26.4, 38.0),
		],
	},
	"battlefield_edge->oath_ruins": {
		"from_area_id": "battlefield_edge",
		"to_area_id": "oath_ruins",
		"route_kind": "branch",
		"polygon_points": [
			Vector2(54.4, 36.2),
			Vector2(57.8, 35.8),
			Vector2(60.2, 37.0),
			Vector2(60.8, 39.4),
			Vector2(59.8, 41.2),
			Vector2(56.8, 41.8),
			Vector2(54.4, 40.4),
			Vector2(53.8, 38.0),
		],
	},
	"battlefield_edge->exit_north_border": {
		"from_area_id": "battlefield_edge",
		"to_area_id": "exit_north_border",
		"route_kind": "exit",
		"polygon_points": [
			Vector2(62.8, 29.0),
			Vector2(65.0, 28.8),
			Vector2(66.8, 29.8),
			Vector2(67.0, 31.6),
			Vector2(65.8, 32.8),
			Vector2(63.4, 32.8),
			Vector2(62.2, 31.2),
		],
	},
	"frozen_river_breach->oath_ruins": {
		"from_area_id": "frozen_river_breach",
		"to_area_id": "oath_ruins",
		"route_kind": "narrow",
		"polygon_points": [
			Vector2(39.0, 42.4),
			Vector2(43.5, 42.0),
			Vector2(48.5, 42.2),
			Vector2(49.6, 43.8),
			Vector2(48.8, 45.4),
			Vector2(43.8, 45.8),
			Vector2(39.5, 45.2),
			Vector2(38.6, 43.8),
		],
	},
	"frozen_river_breach->exit_west_mountain": {
		"from_area_id": "frozen_river_breach",
		"to_area_id": "exit_west_mountain",
		"route_kind": "exit",
		"polygon_points": [
			Vector2(28.2, 46.2),
			Vector2(32.6, 46.0),
			Vector2(35.6, 46.6),
			Vector2(36.0, 48.2),
			Vector2(34.8, 49.2),
			Vector2(30.8, 49.3),
			Vector2(27.8, 48.4),
			Vector2(27.2, 47.0),
		],
	},
}

const PRIMARY_LINK_KEYS := [
	"watchtower->hunters_ruin",
	"hunters_ruin->burial_slope",
	"burial_slope->battlefield_edge",
	"burial_slope->frozen_river_breach",
]

const EXIT_GATE_REGION_IDS := {
	"exit_north_border": "edge_north",
	"exit_west_mountain": "edge_west",
}


static func get_region_id() -> String:
	return REGION_ID


static func get_region_display_name() -> String:
	return REGION_DISPLAY_NAME


static func get_preview_entry_id() -> String:
	return PREVIEW_ENTRY_ID


static func get_preview_entry_display_name() -> String:
	return PREVIEW_ENTRY_DISPLAY_NAME


static func get_map_scale() -> float:
	return BLOCKOUT_SCALE


static func get_spawn_point_meters() -> Vector2:
	return _scale_point(SPAWN_POINT_METERS)


static func get_outer_boundary_polygon() -> PackedVector2Array:
	return _scale_packed_points(PackedVector2Array(OUTER_BOUNDARY_POINTS))


static func get_world_bounds_meters() -> Rect2:
	return _compute_polygon_bounds(get_outer_boundary_polygon()).grow(WORLD_BOUNDS_PADDING_METERS)


static func get_area_ids() -> Array[String]:
	var results: Array[String] = []
	for area_id in AREA_ORDER:
		results.append(area_id)
	return results


static func get_area_definition(area_id: String) -> Dictionary:
	if not AREA_DEFINITIONS.has(area_id):
		return {}
	return _with_bounds(_scale_area_definition((AREA_DEFINITIONS[area_id] as Dictionary).duplicate(true)))


static func get_area_definitions() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for area_id in AREA_ORDER:
		results.append(get_area_definition(area_id))
	return results


static func get_area_polygon_points(area_id: String) -> PackedVector2Array:
	return _get_polygon_points(get_area_definition(area_id))


static func get_area_center(area_id: String) -> Vector2:
	var bounds := get_area_bounds(area_id)
	if bounds.size == Vector2.ZERO:
		return Vector2.ZERO
	return bounds.position + bounds.size * 0.5


static func get_area_bounds(area_id: String) -> Rect2:
	return _compute_polygon_bounds(get_area_polygon_points(area_id))


static func get_exit_definitions() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for area_id in AREA_ORDER:
		var definition := get_area_definition(area_id)
		if bool(definition.get("is_exit", false)):
			results.append(definition)
	return results


static func get_route_definition(link_key: String) -> Dictionary:
	var resolved_key := _resolve_route_key_from_text(link_key)
	if resolved_key.is_empty():
		return {}
	var definition := (ROUTE_DEFINITIONS[resolved_key] as Dictionary).duplicate(true)
	definition["link_key"] = resolved_key
	definition["is_primary"] = PRIMARY_LINK_KEYS.has(resolved_key)
	return _with_bounds(_scale_route_definition(definition))


static func get_route_polygon_points(link_key: String) -> PackedVector2Array:
	return _get_polygon_points(get_route_definition(link_key))


static func get_route_definitions() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for link_key in ROUTE_ORDER:
		results.append(get_route_definition(link_key))
	return results


static func get_link_pairs() -> Array[Dictionary]:
	return get_route_definitions()


static func get_walkable_polygons() -> Array:
	var results: Array = []
	for area_id in AREA_ORDER:
		results.append(get_area_polygon_points(area_id))
	for route in get_route_definitions():
		results.append(_get_polygon_points(route))
	return results


static func get_primary_link_keys() -> Array[String]:
	var results: Array[String] = []
	for link_key in PRIMARY_LINK_KEYS:
		results.append(str(link_key))
	return results


static func is_primary_link(source_area_id: String, target_area_id: String) -> bool:
	var route_key := _resolve_route_key(source_area_id, target_area_id)
	return not route_key.is_empty() and PRIMARY_LINK_KEYS.has(route_key)


static func get_gate_area_id_for_region(region_id: String) -> String:
	for area_id in EXIT_GATE_REGION_IDS.keys():
		if str(EXIT_GATE_REGION_IDS[area_id]) == region_id:
			return str(area_id)
	return ""


static func build_snapshot() -> Dictionary:
	return {
		"region_id": REGION_ID,
		"display_name": REGION_DISPLAY_NAME,
		"preview_entry_id": PREVIEW_ENTRY_ID,
		"spawn_point_meters": get_spawn_point_meters(),
		"outer_boundary_polygon": get_outer_boundary_polygon(),
		"areas": get_area_definitions(),
		"routes": get_route_definitions(),
		"links": get_route_definitions(),
		"primary_link_keys": get_primary_link_keys(),
	}


static func validate_blockout() -> Array[String]:
	var errors: Array[String] = []
	var exit_count := 0
	for area_id in AREA_ORDER:
		var definition := get_area_definition(area_id)
		if definition.is_empty():
			errors.append("missing area definition for %s" % area_id)
			continue
		if str(definition.get("display_name", "")).is_empty():
			errors.append("display_name missing for %s" % area_id)
		if _get_polygon_points(definition).size() < 3:
			errors.append("polygon_points missing for %s" % area_id)
		if Vector2(definition.get("label_size", Vector2.ZERO)) == Vector2.ZERO:
			errors.append("label_size missing for %s" % area_id)
		if bool(definition.get("is_exit", false)):
			exit_count += 1
			if str(definition.get("exit_target_display", "")).is_empty():
				errors.append("exit target display missing for %s" % area_id)
		for linked_area_id in definition.get("links", []):
			if not AREA_DEFINITIONS.has(str(linked_area_id)):
				errors.append("invalid linked area %s -> %s" % [area_id, str(linked_area_id)])
			var route_key := _resolve_route_key(area_id, str(linked_area_id))
			if route_key.is_empty():
				errors.append("missing route definition for %s -> %s" % [area_id, str(linked_area_id)])
	if exit_count != 2:
		errors.append("exit count should be 2, got %d" % exit_count)
	if get_outer_boundary_polygon().size() < 3:
		errors.append("outer boundary polygon missing")
	if not _is_point_in_any_polygon(get_spawn_point_meters(), get_walkable_polygons()):
		errors.append("spawn point must be inside walkable terrain")
	for link_key in ROUTE_ORDER:
		var route := get_route_definition(link_key)
		if route.is_empty():
			errors.append("missing route entry %s" % link_key)
			continue
		if _get_polygon_points(route).size() < 3:
			errors.append("route polygon missing for %s" % link_key)
	return errors


static func _with_bounds(definition: Dictionary) -> Dictionary:
	var polygon := _get_polygon_points(definition)
	var bounds := _compute_polygon_bounds(polygon)
	definition["blockout_position"] = bounds.position
	definition["blockout_size"] = bounds.size
	return definition


static func _scale_area_definition(definition: Dictionary) -> Dictionary:
	definition["polygon_points"] = _scale_point_array(definition.get("polygon_points", []))
	definition["label_anchor"] = _scale_point(Vector2(definition.get("label_anchor", Vector2.ZERO)))
	definition["label_size"] = _scale_vector(Vector2(definition.get("label_size", Vector2.ZERO)))
	return definition


static func _scale_route_definition(definition: Dictionary) -> Dictionary:
	definition["polygon_points"] = _scale_point_array(definition.get("polygon_points", []))
	return definition


static func _get_polygon_points(definition: Dictionary) -> PackedVector2Array:
	var packed := PackedVector2Array()
	for point in definition.get("polygon_points", []):
		packed.append(Vector2(point))
	return packed


static func _scale_point_array(points: Array) -> Array:
	var results: Array = []
	for point in points:
		results.append(_scale_point(Vector2(point)))
	return results


static func _scale_packed_points(points: PackedVector2Array) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	for point in points:
		scaled.append(_scale_point(point))
	return scaled


static func _scale_point(point: Vector2) -> Vector2:
	return point * BLOCKOUT_SCALE


static func _scale_vector(value: Vector2) -> Vector2:
	return value * BLOCKOUT_SCALE


static func _compute_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var min_x := polygon[0].x
	var max_x := polygon[0].x
	var min_y := polygon[0].y
	var max_y := polygon[0].y
	for point in polygon:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


static func _is_point_in_any_polygon(point: Vector2, polygons: Array) -> bool:
	for polygon in polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


static func _build_link_key(source_area_id: String, target_area_id: String) -> String:
	return "%s->%s" % [source_area_id, target_area_id]


static func _canonical_link_key(source_area_id: String, target_area_id: String) -> String:
	if source_area_id <= target_area_id:
		return _build_link_key(source_area_id, target_area_id)
	return _build_link_key(target_area_id, source_area_id)


static func _resolve_route_key(source_area_id: String, target_area_id: String) -> String:
	var direct_key := _build_link_key(source_area_id, target_area_id)
	if ROUTE_DEFINITIONS.has(direct_key):
		return direct_key
	var reverse_key := _build_link_key(target_area_id, source_area_id)
	if ROUTE_DEFINITIONS.has(reverse_key):
		return reverse_key
	return ""


static func _resolve_route_key_from_text(link_key: String) -> String:
	var split := link_key.split("->")
	if split.size() != 2:
		return link_key if ROUTE_DEFINITIONS.has(link_key) else ""
	return _resolve_route_key(str(split[0]), str(split[1]))
