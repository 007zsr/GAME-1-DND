extends SceneTree

const ItemSystem = preload("res://game/scripts/item_system.gd")
const GameplaySceneContract = preload("res://game/scripts/gameplay_scene_contract.gd")
const OverheadDisplay = preload("res://game/scripts/overhead_display.gd")
const CHECK_NAME := "check_overhead_display_system"
const CHECK_TIMEOUT_SEC := 30.0

var _check_started_msec: int = 0


func _init() -> void:
	_check_started_msec = Time.get_ticks_msec()
	_start_watchdog()
	call_deferred("_run_check")


func _run_check() -> void:
	var game_state: Node = root.get_node_or_null("/root/GameState")
	if game_state == null:
		push_error("GameState autoload missing")
		quit(1)
		return

	game_state.set_current_character({
		"class_id": "warrior",
		"class_name": "战士",
		"reborn_job_id": "warrior",
		"reborn_job_name": "战士",
		"background_id": "student",
		"background_name": "学生",
		"profile_tags": ["student"],
		"trait_ids": [],
		"strength_id": "",
		"weakness_id": "",
		"personality_id": "",
		"level": 1,
		"a_stats": {
			"strength": 8,
			"agility": 6,
			"intelligence": 5,
			"perception": 6,
			"fortitude": 7,
			"willpower": 5,
		},
		"b_stats": {},
		"equipped_items": {},
		"inventory_slots": ItemSystem.get_default_inventory_state(),
	})

	if not await _check_newbie_village():
		return
	if not await _check_god_space_hub():
		return
	if not await _check_cultivation_corner_northwest():
		return

	print("check_overhead_display_system_ok")
	quit(0)


func _check_newbie_village() -> bool:
	var scene := await _load_scene("res://game/scenes/newbie_village.tscn")
	if scene == null:
		return false

	var player: Node = scene.get_player_node()
	if not _assert_overhead_state(player, "newbie player", OverheadDisplay.STYLE_GREEN, false, true, false):
		return false

	var melee := _get_enemy_by_template_id(scene, "melee_grunt")
	if not _assert_overhead_state(melee, "melee grunt", OverheadDisplay.STYLE_RED, true, true, true):
		return false
	if not _assert_legacy_labels_disabled(melee, "melee grunt"):
		return false

	var ranged := _get_enemy_by_template_id(scene, "ranged_grunt")
	if not _assert_overhead_state(ranged, "ranged grunt", OverheadDisplay.STYLE_RED, true, true, true):
		return false
	if not _assert_legacy_labels_disabled(ranged, "ranged grunt"):
		return false

	var boss := _get_enemy_by_template_id(scene, "boss_guardian")
	if not _assert_overhead_state(boss, "boss guardian", OverheadDisplay.STYLE_BOSS_RED_LARGE, true, true, true):
		return false
	if not _assert_legacy_labels_disabled(boss, "boss guardian"):
		return false

	var boss_debug: Dictionary = boss.get_overhead_display_debug_state()
	var melee_debug: Dictionary = melee.get_overhead_display_debug_state()
	if float(melee_debug.get("bar_width", 999.0)) >= 40.0:
		push_error("ordinary overhead bar should be shorter after calibration: %s" % str(melee_debug))
		quit(1)
		return false
	if float(melee_debug.get("bar_height", 999.0)) > 5.0:
		push_error("ordinary overhead bar should be slimmer after calibration: %s" % str(melee_debug))
		quit(1)
		return false
	if float(melee_debug.get("name_bar_gap", 999.0)) > 2.0:
		push_error("ordinary name gap should be tighter after calibration: %s" % str(melee_debug))
		quit(1)
		return false
	if float(melee_debug.get("head_display_offset_y", 0.0)) < -22.0:
		push_error("ordinary head offset should not remain overly high: %s" % str(melee_debug))
		quit(1)
		return false
	if (boss_debug.get("bar_size", Vector2.ZERO) as Vector2).x <= (melee_debug.get("bar_size", Vector2.ZERO) as Vector2).x:
		push_error("boss overhead bar should be longer than melee bar: %s vs %s" % [str(boss_debug), str(melee_debug)])
		quit(1)
		return false
	if (boss_debug.get("bar_size", Vector2.ZERO) as Vector2).y <= (melee_debug.get("bar_size", Vector2.ZERO) as Vector2).y:
		push_error("boss overhead bar should be thicker than melee bar: %s vs %s" % [str(boss_debug), str(melee_debug)])
		quit(1)
		return false

	var goddess := _find_goddess_actor(scene)
	if not _assert_overhead_state(goddess, "newbie goddess", OverheadDisplay.STYLE_NONE, true, false, true):
		return false
	if not _assert_legacy_labels_disabled(goddess, "newbie goddess"):
		return false
	var goddess_debug: Dictionary = goddess.get_overhead_display_debug_state()
	if float(goddess_debug.get("head_display_offset_y", 0.0)) < -24.0:
		push_error("name-only head offset should remain within the calibrated band: %s" % str(goddess_debug))
		quit(1)
		return false

	var player_before: Dictionary = player.get_overhead_display_debug_state()
	player.take_damage(20)
	await _await_frames(1, "waiting for player overhead refresh after damage")
	var player_after: Dictionary = player.get_overhead_display_debug_state()
	if float(player_after.get("hp_ratio", 1.0)) >= float(player_before.get("hp_ratio", 1.0)):
		push_error("player overhead bar did not shrink after damage: %s -> %s" % [str(player_before), str(player_after)])
		quit(1)
		return false

	var melee_before: Dictionary = melee.get_overhead_display_debug_state()
	melee.take_damage(10)
	await _await_frames(1, "waiting for melee overhead refresh after damage")
	var melee_after: Dictionary = melee.get_overhead_display_debug_state()
	if float(melee_after.get("hp_ratio", 1.0)) >= float(melee_before.get("hp_ratio", 1.0)):
		push_error("melee overhead bar did not shrink after damage: %s -> %s" % [str(melee_before), str(melee_after)])
		quit(1)
		return false

	return true


func _check_god_space_hub() -> bool:
	var scene := await _load_scene("res://game/scenes/god_space_hub.tscn")
	if scene == null:
		return false

	var player: Node = scene.get_player_node()
	if not _assert_overhead_state(player, "hub player", OverheadDisplay.STYLE_GREEN, false, true, false):
		return false

	var goddess: Node = scene.get("goddess_actor")
	if not _assert_overhead_state(goddess, "hub goddess", OverheadDisplay.STYLE_NONE, true, false, true):
		return false
	if not _assert_legacy_labels_disabled(goddess, "hub goddess"):
		return false

	return true


func _check_cultivation_corner_northwest() -> bool:
	var scene := await _load_scene("res://game/scenes/cultivation_region_corner_northwest.tscn")
	if scene == null:
		return false

	var player: Node = scene.get_player_node()
	if not _assert_overhead_state(player, "cultivation player", OverheadDisplay.STYLE_GREEN, false, true, false):
		return false

	var wolf := _get_enemy_by_template_id(scene, "frost_white_wolf")
	if not _assert_overhead_state(wolf, "frost white wolf", OverheadDisplay.STYLE_RED, true, true, true):
		return false
	if not _assert_legacy_labels_disabled(wolf, "frost white wolf"):
		return false

	var wolf_before: Dictionary = wolf.get_overhead_display_debug_state()
	if float(wolf_before.get("bar_width", 999.0)) >= 40.0:
		push_error("wolf should share the calibrated ordinary bar width: %s" % str(wolf_before))
		quit(1)
		return false
	wolf.take_damage(15)
	await _await_frames(1, "waiting for wolf overhead refresh after damage")
	var wolf_after: Dictionary = wolf.get_overhead_display_debug_state()
	if float(wolf_after.get("hp_ratio", 1.0)) >= float(wolf_before.get("hp_ratio", 1.0)):
		push_error("wolf overhead bar did not shrink after damage: %s -> %s" % [str(wolf_before), str(wolf_after)])
		quit(1)
		return false

	return true


func _load_scene(scene_path: String) -> Node:
	if change_scene_to_file(scene_path) != OK:
		push_error("failed to load scene: %s" % scene_path)
		quit(1)
		return null
	await _await_frames(4, "waiting for %s bootstrap" % scene_path)
	var scene := current_scene
	if scene == null:
		push_error("current scene missing after load: %s" % scene_path)
		quit(1)
		return null

	var contract_errors := GameplaySceneContract.validate_scene(scene, {
		"require_dialogue_registration": true,
	})
	if not contract_errors.is_empty():
		push_error("%s contract errors: %s" % [scene_path, str(contract_errors)])
		quit(1)
		return null
	return scene


func _assert_overhead_state(node: Node, label: String, expected_style: String, expected_show_name: bool, expect_bar_visible: bool, expect_name_visible: bool) -> bool:
	if node == null or not node.has_method("get_overhead_display_debug_state"):
		push_error("%s missing overhead debug state" % label)
		quit(1)
		return false
	var debug_state: Dictionary = node.get_overhead_display_debug_state()
	if debug_state.is_empty():
		push_error("%s overhead debug state empty" % label)
		quit(1)
		return false
	if str(debug_state.get("hp_bar_style", "")) != expected_style:
		push_error("%s overhead style mismatch: %s" % [label, str(debug_state)])
		quit(1)
		return false
	if bool(debug_state.get("show_name", not expected_show_name)) != expected_show_name:
		push_error("%s show_name mismatch: %s" % [label, str(debug_state)])
		quit(1)
		return false
	if bool(debug_state.get("bar_visible", not expect_bar_visible)) != expect_bar_visible:
		push_error("%s bar visibility mismatch: %s" % [label, str(debug_state)])
		quit(1)
		return false
	if bool(debug_state.get("name_visible", not expect_name_visible)) != expect_name_visible:
		push_error("%s name visibility mismatch: %s" % [label, str(debug_state)])
		quit(1)
		return false
	return true


func _assert_legacy_labels_disabled(node: Node, label: String) -> bool:
	var legacy_name := node.get_node_or_null("NameLabel") as Label
	var legacy_health := node.get_node_or_null("HealthLabel") as Label
	if legacy_name != null and legacy_name.visible:
		push_error("%s legacy NameLabel should be hidden" % label)
		quit(1)
		return false
	if legacy_health != null and legacy_health.visible:
		push_error("%s legacy HealthLabel should be hidden" % label)
		quit(1)
		return false
	return true


func _get_enemy_by_template_id(scene: Node, template_id: String) -> Node:
	if scene == null:
		return null
	var enemy_registry = scene.get("enemy_registry")
	if not (enemy_registry is Dictionary):
		return null
	for entry in (enemy_registry as Dictionary).values():
		var enemy_data: Dictionary = entry as Dictionary
		if str(enemy_data.get("template_id", "")) == template_id:
			return enemy_data.get("node")
	return null


func _find_goddess_actor(scene: Node) -> Node:
	if scene == null:
		return null
	var chest_layer = scene.get("chest_layer") as Node
	if chest_layer == null:
		return null
	for child in chest_layer.get_children():
		if child.has_method("get_display_name") and str(child.get_display_name()) == "复活女神":
			return child
	return null


func _start_watchdog() -> void:
	var watchdog := create_timer(CHECK_TIMEOUT_SEC)
	watchdog.timeout.connect(func() -> void:
		push_error("%s timed out after %.1f seconds" % [CHECK_NAME, CHECK_TIMEOUT_SEC])
		quit(1))


func _await_frames(frame_count: int, label: String) -> void:
	for _frame_index in range(frame_count):
		_guard_timeout(label)
		await process_frame
		_guard_timeout(label)


func _guard_timeout(label: String) -> void:
	var elapsed_sec := float(Time.get_ticks_msec() - _check_started_msec) / 1000.0
	if elapsed_sec > CHECK_TIMEOUT_SEC:
		push_error("%s timed out while %s after %.2f seconds" % [CHECK_NAME, label, elapsed_sec])
		quit(1)
