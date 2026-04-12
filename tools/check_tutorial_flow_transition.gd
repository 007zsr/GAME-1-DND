extends SceneTree

const ItemSystem = preload("res://game/scripts/item_system.gd")
const GameplaySceneContract = preload("res://game/scripts/gameplay_scene_contract.gd")
const CHECK_NAME := "check_tutorial_flow_transition"
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

	var tutorial_scene_path := "res://game/scenes/newbie_village.tscn"
	if game_state.has_method("get_tutorial_scene_path"):
		tutorial_scene_path = str(game_state.get_tutorial_scene_path())
	if get_root().get_tree().change_scene_to_file(tutorial_scene_path) != OK:
		push_error("failed to change scene to tutorial scene: %s" % tutorial_scene_path)
		quit(1)
		return

	await _await_frames(4, "waiting for tutorial scene bootstrap")

	var village := current_scene
	if village == null or str(village.scene_file_path) != tutorial_scene_path:
		push_error("tutorial scene not active after bootstrap")
		quit(1)
		return

	var boss := _get_boss_enemy(village)
	if boss == null:
		push_error("boss missing in tutorial scene")
		quit(1)
		return
	boss.take_damage(99999)

	await _await_frames(6, "waiting for tutorial boss completion dialogue")

	var dialogue_manager: Node = root.get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("DialogueManager autoload missing")
		quit(1)
		return
	if not dialogue_manager.has_method("get_current_dialogue_id") or dialogue_manager.get_current_dialogue_id() != "tutorial_boss_clear_goddess":
		push_error("tutorial clear dialogue did not open: %s" % str(dialogue_manager.get_current_dialogue_id()))
		quit(1)
		return
	dialogue_manager.select_option("enter_god_space")

	await _await_frames(8, "waiting for transition into god space")

	var hub_scene_path := str(game_state.get_god_space_scene_path()) if game_state.has_method("get_god_space_scene_path") else "res://game/scenes/god_space_hub.tscn"
	var hub := current_scene
	if hub == null or str(hub.scene_file_path) != hub_scene_path:
		push_error("god space hub did not become active scene")
		quit(1)
		return
	if not game_state.has_method("has_completed_tutorial") or not game_state.has_completed_tutorial():
		push_error("tutorial completion flag missing in GameState")
		quit(1)
		return
	if not game_state.has_method("has_entered_god_space") or not game_state.has_entered_god_space():
		push_error("entered god space flag missing in GameState")
		quit(1)
		return
	if not _assert_skill_ui_hooked(hub, "god space hub"):
		return

	var world_gate: Node = hub.get_world_gate() if hub.has_method("get_world_gate") else null
	if world_gate == null:
		push_error("world gate missing in god space hub")
		quit(1)
		return
	if not hub.has_method("open_world_selection") or not hub.open_world_selection():
		push_error("failed to open world selection from god space hub")
		quit(1)
		return

	await _await_frames(2, "waiting for world selection panel")

	var world_panel: Node = hub.world_selection_panel
	if world_panel == null or not world_panel.visible:
		push_error("world selection panel not visible")
		quit(1)
		return

	var world_entries: Array = world_panel.get_entry_state_snapshot() if world_panel.has_method("get_entry_state_snapshot") else []
	var expected_names := ["修仙世界", "异能世界", "未来世界", "古代世界"]
	var seen_names: Array[String] = []
	for entry in world_entries:
		seen_names.append(str((entry as Dictionary).get("display_name", "")))
	if seen_names != expected_names:
		push_error("world selection names mismatch: %s" % str(seen_names))
		quit(1)
		return
	if not bool((world_entries[0] as Dictionary).get("is_available", false)):
		push_error("cultivation world should be the formal available test world")
		quit(1)
		return
	for index in range(1, world_entries.size()):
		if bool((world_entries[index] as Dictionary).get("is_available", false)):
			push_error("non-test world unexpectedly available: %s" % str(world_entries[index]))
			quit(1)
			return

	if not hub.has_method("handle_world_selection") or not hub.handle_world_selection("cultivation_world"):
		push_error("failed to enter cultivation world from hub")
		quit(1)
		return

	await _await_frames(6, "waiting for cultivation world load")

	var cultivation_scene_path := str(game_state.get_world_scene_path("cultivation_world")) if game_state.has_method("get_world_scene_path") else "res://game/scenes/cultivation_trial_world.tscn"
	var cultivation_world := current_scene
	if cultivation_world == null or str(cultivation_world.scene_file_path) != cultivation_scene_path:
		push_error("cultivation world did not become active scene")
		quit(1)
		return
	if not game_state.has_method("get_current_world_id") or game_state.get_current_world_id() != "cultivation_world":
		push_error("current world id not updated after entering cultivation world")
		quit(1)
		return
	if not _assert_skill_ui_hooked(cultivation_world, "cultivation world"):
		return

	var return_gate: Node = cultivation_world.get_return_gate() if cultivation_world.has_method("get_return_gate") else null
	if return_gate == null:
		push_error("return gate missing in cultivation world")
		quit(1)
		return
	if not cultivation_world.has_method("return_to_god_space") or not cultivation_world.return_to_god_space():
		push_error("failed to return from cultivation world to god space")
		quit(1)
		return

	await _await_frames(6, "waiting for return to god space")

	hub = current_scene
	if hub == null or str(hub.scene_file_path) != hub_scene_path:
		push_error("god space hub not restored after return")
		quit(1)
		return
	if game_state.get_current_world_id() != "":
		push_error("current world id should clear after returning to hub")
		quit(1)
		return
	if not _assert_skill_ui_hooked(hub, "god space hub after return"):
		return
	if dialogue_manager.has_method("get_current_dialogue_id") and str(dialogue_manager.get_current_dialogue_id()) != "":
		push_error("dialogue should not remain active after return to hub")
		quit(1)
		return

	print("check_tutorial_flow_transition_ok")
	quit(0)


func _get_boss_enemy(village: Node) -> Node:
	for entry in village.enemy_registry.values():
		var enemy_data: Dictionary = entry as Dictionary
		if str(enemy_data.get("template_id", "")) == "boss_guardian":
			return enemy_data.get("node")
	return null


func _assert_skill_ui_hooked(scene_node: Node, label: String) -> bool:
	var contract_errors := GameplaySceneContract.validate_scene(scene_node, {
		"require_dialogue_registration": true,
	})
	if not contract_errors.is_empty():
		push_error("%s scene contract errors: %s" % [label, str(contract_errors)])
		quit(1)
		return false
	var player: Node = scene_node.get_node_or_null("WorldLayers/Entities/Player")
	if player == null or not player.has_method("get_equipped_skill_id"):
		push_error("%s player missing skill runtime access" % label)
		quit(1)
		return false
	var skill_id := str(player.get_equipped_skill_id(0))
	if skill_id.is_empty():
		push_error("%s player missing equipped test skill" % label)
		quit(1)
		return false
	var detail_data: Dictionary = player.get_skill_hover_detail_data(skill_id) if player.has_method("get_skill_hover_detail_data") else {}
	if detail_data.is_empty():
		push_error("%s skill hover detail data unresolved for %s" % [label, skill_id])
		quit(1)
		return false
	if not bool(detail_data.get("supports_shift", false)):
		push_error("%s skill hover detail data missing shift support" % label)
		quit(1)
		return false
	return true


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
