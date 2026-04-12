extends SceneTree

const ItemSystem = preload("res://game/scripts/item_system.gd")
const GameplaySceneContract = preload("res://game/scripts/gameplay_scene_contract.gd")
const CHECK_NAME := "check_gameplay_scene_integration"
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

	var tutorial_scene_path := str(game_state.get_tutorial_scene_path()) if game_state.has_method("get_tutorial_scene_path") else "res://game/scenes/newbie_village.tscn"
	var hub_scene_path := str(game_state.get_god_space_scene_path()) if game_state.has_method("get_god_space_scene_path") else "res://game/scenes/god_space_hub.tscn"
	var cultivation_scene_path := str(game_state.get_world_scene_path("cultivation_world")) if game_state.has_method("get_world_scene_path") else "res://game/scenes/cultivation_trial_world.tscn"

	await _load_and_validate_scene(tutorial_scene_path, "tutorial")
	await _load_and_validate_scene(hub_scene_path, "god space hub")
	await _load_and_validate_scene(cultivation_scene_path, "cultivation world")

	print("check_gameplay_scene_integration_ok")
	quit(0)


func _load_and_validate_scene(scene_path: String, label: String) -> void:
	if change_scene_to_file(scene_path) != OK:
		push_error("failed to change scene to %s" % scene_path)
		quit(1)
		return
	await _await_frames(4, "waiting for %s bootstrap" % label)

	var scene := current_scene
	if scene == null or str(scene.scene_file_path) != scene_path:
		push_error("%s did not become active scene" % label)
		quit(1)
		return

	var errors := GameplaySceneContract.validate_scene(scene, {
		"require_dialogue_registration": true,
	})
	if not errors.is_empty():
		push_error("%s scene contract errors: %s" % [label, str(errors)])
		quit(1)
		return

	var player_menu: Control = scene.get("player_menu")
	if player_menu == null:
		push_error("%s missing player menu reference" % label)
		quit(1)
		return
	if player_menu.process_mode != Node.PROCESS_MODE_ALWAYS:
		push_error("%s player menu process mode not ALWAYS" % label)
		quit(1)
		return

	var toggle_open_event := InputEventKey.new()
	toggle_open_event.pressed = true
	toggle_open_event.keycode = KEY_I
	player_menu._unhandled_input(toggle_open_event)
	await _await_frames(1, "waiting for %s I-key open handling" % label)
	if not player_menu.visible:
		push_error("%s I key did not open player menu" % label)
		quit(1)
		return
	player_menu._unhandled_input(toggle_open_event)
	await _await_frames(1, "waiting for %s I-key close handling" % label)
	if player_menu.visible:
		push_error("%s I key did not close player menu" % label)
		quit(1)
		return

	var player: Node = scene.get_player_node() if scene.has_method("get_player_node") else null
	if player == null:
		push_error("%s player binding missing" % label)
		quit(1)
		return
	var skill_id := str(player.get_equipped_skill_id(0)) if player.has_method("get_equipped_skill_id") else ""
	if skill_id.is_empty():
		push_error("%s equipped skill missing" % label)
		quit(1)
		return
	var hover_data: Dictionary = player.get_skill_hover_detail_data(skill_id) if player.has_method("get_skill_hover_detail_data") else {}
	if hover_data.is_empty():
		push_error("%s skill hover detail chain unresolved" % label)
		quit(1)
		return
	if not bool(hover_data.get("supports_shift", false)):
		push_error("%s skill hover detail shift layer missing" % label)
		quit(1)
		return


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
