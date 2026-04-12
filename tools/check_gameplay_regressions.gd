extends SceneTree

const ItemSystem = preload("res://game/scripts/item_system.gd")
const GameplaySceneContract = preload("res://game/scripts/gameplay_scene_contract.gd")
const SkillRegistry = preload("res://game/skills/skill_registry.gd")
const CHECK_NAME := "check_gameplay_regressions"
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
		"class_name": "鎴樺＋",
		"reborn_job_id": "warrior",
		"reborn_job_name": "鎴樺＋",
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

	var scene: PackedScene = load("res://game/scenes/newbie_village.tscn")
	if scene == null:
		push_error("load newbie_village.tscn failed")
		quit(1)
		return

	var village := scene.instantiate()
	if village == null:
		push_error("instantiate newbie_village.tscn failed")
		quit(1)
		return
	root.add_child(village)
	await _await_frames(2, "waiting for newbie_village scene bootstrap")

	var contract_errors := GameplaySceneContract.validate_scene(village, {
		"require_dialogue_registration": true,
	})
	if not contract_errors.is_empty():
		push_error("newbie_village scene contract errors: %s" % str(contract_errors))
		quit(1)
		return

	var player: Node = village.get_player_node()
	if player == null:
		push_error("player missing")
		quit(1)
		return
	var goddess := _find_goddess_actor(village)
	if goddess == null:
		push_error("goddess actor missing")
		quit(1)
		return
	if not goddess.has_method("get_actor_kind") or goddess.get_actor_kind() != "npc":
		push_error("goddess actor kind mismatch")
		quit(1)
		return
	if not goddess.has_method("get_faction_id") or goddess.get_faction_id() != "friendly":
		push_error("goddess faction mismatch")
		quit(1)
		return
	if not goddess.has_method("get_ai_id") or goddess.get_ai_id() != "npc_guard_friendly_idle":
		push_error("goddess AI mismatch")
		quit(1)
		return
	if goddess.get_node_or_null("DialogueInteractor") == null:
		push_error("goddess dialogue component missing")
		quit(1)
		return

	var player_menu: Control = village.player_menu
	var chest_menu: Control = village.chest_menu
	if player_menu == null or chest_menu == null:
		push_error("overlay menus missing")
		quit(1)
		return
	if player_menu.process_mode != Node.PROCESS_MODE_ALWAYS:
		push_error("player menu is not ALWAYS")
		quit(1)
		return
	if chest_menu.process_mode != Node.PROCESS_MODE_ALWAYS:
		push_error("chest menu is not ALWAYS")
		quit(1)
		return

	var toggle_open_event := InputEventKey.new()
	toggle_open_event.pressed = true
	toggle_open_event.keycode = KEY_I
	player_menu._unhandled_input(toggle_open_event)
	await _await_frames(1, "waiting for I-key open handling")
	if not player_menu.visible:
		push_error("I key did not open player menu")
		quit(1)
		return

	player_menu._unhandled_input(toggle_open_event)
	await _await_frames(1, "waiting for I-key close handling")
	if player_menu.visible:
		push_error("I key did not close player menu")
		quit(1)
		return

	var sword_index := _find_inventory_index(player, "iron_sword")
	if sword_index == -1:
		push_error("iron_sword not found in inventory")
		quit(1)
		return

	var base_damage: float = player.get_slash_damage_value()
	var base_damage_power: float = player.get_damage_power()

	if not village.request_open_overlay(player_menu):
		push_error("failed to open player menu overlay")
		quit(1)
		return
	player_menu.visible = true
	if not player_menu.page_nodes.has("skills"):
		push_error("skills page missing from player menu")
		quit(1)
		return
	player_menu._show_tab("skills")
	await _await_frames(1, "waiting for skills tab activation")
	if player_menu.current_tab != "skills":
		push_error("failed to switch to skills page")
		quit(1)
		return
	if _count_visible_drag_cards(player_menu.page_nodes.get("skills")) < 2:
		push_error("skills page visible drag cards too few")
		quit(1)
		return
	if not player.is_skill_owned("slash_skill"):
		push_error("player does not own slash_skill")
		quit(1)
		return
	if not player.is_skill_equipped("slash_skill"):
		push_error("slash_skill should start equipped")
		quit(1)
		return
	player_menu._show_tab("equipment")
	await _await_frames(1, "waiting for equipment tab activation")
	player_menu.handle_slot_double_click("inventory", sword_index)
	await _await_frames(1, "waiting for double-click equip application")

	var equipped_weapon: Dictionary = player.get_equipment_slot_stack("weapon")
	if str(equipped_weapon.get("template_id", "")) != "iron_sword":
		push_error("double click equip did not place iron_sword into weapon slot")
		quit(1)
		return
	if player.get_damage_power() <= base_damage_power:
		push_error("equip did not refresh damage power")
		quit(1)
		return
	if player.get_slash_damage_value() <= base_damage:
		push_error("equip did not refresh slash damage")
		quit(1)
		return

	player_menu._close_menu()
	await _await_frames(1, "waiting for player menu close")

	if not player.unequip_to_inventory_auto("weapon"):
		push_error("failed to unequip weapon for right-click path validation")
		quit(1)
		return
	await _await_frames(1, "waiting for weapon unequip refresh")

	var re_sword_index := _find_inventory_index(player, "iron_sword")
	if re_sword_index == -1:
		push_error("iron_sword missing after unequip")
		quit(1)
		return

	player_menu._execute_item_action("equip", {"slot_key": re_sword_index})
	await _await_frames(1, "waiting for right-click equip application")
	if str(player.get_equipment_slot_stack("weapon").get("template_id", "")) != "iron_sword":
		push_error("right-click equip action did not place iron_sword into weapon slot")
		quit(1)
		return

	var hover_data: Dictionary = player.get_slash_skill_hover_detail_data()
	if not _array_contains_text(hover_data.get("summary_lines", []), "当前伤害"):
		push_error("slash hover summary missing damage line")
		quit(1)
		return
	if not _array_contains_text(hover_data.get("summary_lines", []), "当前冷却"):
		push_error("slash hover summary missing cooldown line")
		quit(1)
		return
	if not _array_contains_text(hover_data.get("detail_lines", []), "伤害公式"):
		push_error("slash hover detail missing damage formula line")
		quit(1)
		return
	if not _array_contains_text(hover_data.get("detail_lines", []), "冷却公式"):
		push_error("slash hover detail missing cooldown formula line")
		quit(1)
		return

	var zoom_before: float = player.camera.zoom.x
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	player._unhandled_input(wheel_up)
	await _await_frames(1, "waiting for mouse wheel zoom")
	if player.camera.zoom.x <= zoom_before:
		push_error("mouse wheel up did not zoom in")
		quit(1)
		return
	var zoom_limits: Dictionary = player.get_camera_zoom_limits()
	for _index in range(12):
		player._unhandled_input(wheel_up)
	await _await_frames(1, "waiting for mouse wheel zoom-in clamp")
	if player.camera.zoom.x > float(zoom_limits.get("max", 999.0)) + 0.0001:
		push_error("mouse wheel up exceeded zoom max: %s > %s" % [str(player.camera.zoom.x), str(zoom_limits.get("max"))])
		quit(1)
		return
	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	for _index in range(12):
		player._unhandled_input(wheel_down)
	await _await_frames(1, "waiting for mouse wheel zoom-out clamp")
	if player.camera.zoom.x < float(zoom_limits.get("min", 0.0)) - 0.0001:
		push_error("mouse wheel down exceeded zoom min: %s < %s" % [str(player.camera.zoom.x), str(zoom_limits.get("min"))])
		quit(1)
		return

	var enemy := _get_first_hostile_enemy(village)
	var ranged_enemy := _get_enemy_by_template_id(village, "ranged_grunt")
	var registered_skill_ids := SkillRegistry.get_registered_skill_ids()
	for expected_skill_id in ["melee_grunt_slash", "ranged_grunt_energy_shot", "ranged_grunt_close_counter", "boss_guardian_triple_cleave"]:
		if not registered_skill_ids.has(expected_skill_id):
			push_error("SkillRegistry missing formal skill_id: %s in %s" % [expected_skill_id, str(registered_skill_ids)])
			quit(1)
			return
	if enemy == null:
		push_error("no hostile enemy found for slash regression check")
		quit(1)
		return
	if ranged_enemy == null:
		push_error("ranged grunt missing for visual regression check")
		quit(1)
		return
	if enemy.get_owned_skill_ids().is_empty():
		push_error("enemy skill runtime missing owned skills")
		quit(1)
		return
	if not enemy.get_owned_skill_ids().has("melee_grunt_slash"):
		push_error("melee grunt did not migrate to melee_grunt_slash: %s" % str(enemy.get_owned_skill_ids()))
		quit(1)
		return
	if not ranged_enemy.get_owned_skill_ids().has("ranged_grunt_energy_shot") or not ranged_enemy.get_owned_skill_ids().has("ranged_grunt_close_counter"):
		push_error("ranged grunt missing formal skill ids: %s" % str(ranged_enemy.get_owned_skill_ids()))
		quit(1)
		return
	var enemy_request_ok: bool = enemy.request_skill_use_by_mode("primary")
	if not enemy_request_ok:
		push_error("enemy primary skill request returned false: %s" % str(enemy.get_skill_runtime_state_snapshot()))
		quit(1)
		return
	await _await_physics_frames(24, "waiting for enemy primary skill execution window")
	if not enemy.has_method("get_last_requested_skill_id") or enemy.get_last_requested_skill_id().is_empty():
		push_error("enemy did not request a skill through actor skill entry")
		quit(1)
		return
	if not enemy.has_method("get_last_executed_skill_id") or enemy.get_last_executed_skill_id().is_empty():
		push_error("enemy did not execute a skill through the unified skill executor; requested=%s runtime=%s" % [
			str(enemy.get_last_requested_skill_id()),
			str(enemy.get_skill_runtime_state_snapshot()),
		])
		quit(1)
		return
	if enemy.get_last_executed_skill_id() != "melee_grunt_slash":
		push_error("melee grunt executed unexpected primary skill: %s" % str(enemy.get_last_executed_skill_id()))
		quit(1)
		return
	var ranged_primary_ok: bool = ranged_enemy.request_skill_use_by_mode("primary")
	if not ranged_primary_ok:
		push_error("ranged grunt primary request failed: %s" % str(ranged_enemy.get_skill_runtime_state_snapshot()))
		quit(1)
		return
	await _await_physics_frames(50, "waiting for ranged primary skill execution window")
	if ranged_enemy.get_last_executed_skill_id() != "ranged_grunt_energy_shot":
		push_error("ranged grunt primary execution mismatch: %s" % str(ranged_enemy.get_last_executed_skill_id()))
		quit(1)
		return
	var ranged_fallback_ok: bool = ranged_enemy.request_skill_use_by_mode("fallback")
	if not ranged_fallback_ok:
		push_error("ranged grunt fallback request failed: %s" % str(ranged_enemy.get_skill_runtime_state_snapshot()))
		quit(1)
		return
	await _await_physics_frames(40, "waiting for ranged fallback skill execution window")
	if ranged_enemy.get_last_executed_skill_id() != "ranged_grunt_close_counter":
		push_error("ranged grunt fallback execution mismatch: %s" % str(ranged_enemy.get_last_executed_skill_id()))
		quit(1)
		return

	var boss := _get_boss_enemy(village)
	if boss == null:
		push_error("boss enemy missing for skill execution regression check")
		quit(1)
		return
	if not _assert_enemy_visual_config(
		ranged_enemy,
		"ranged grunt",
		"res://game/assets/textures/characters/enemies/ranged_grunt/animations/ranged_grunt_sprite_frames_v001.tres",
		"res://game/assets/textures/characters/enemies/ranged_grunt/spritesheets/ranged_grunt_sheet_v001.png"
	):
		return
	if not _assert_enemy_visual_config(
		boss,
		"boss guardian",
		"",
		"res://game/assets/textures/characters/enemies/newbie_boss/spritesheets/newbie_boss_sheet_v002.png"
	):
		return
	if not boss.get_owned_skill_ids().has("boss_guardian_triple_cleave"):
		push_error("boss guardian missing formal triple cleave skill id: %s" % str(boss.get_owned_skill_ids()))
		quit(1)
		return
	var boss_position_before: Vector2 = boss.global_position
	var boss_request_ok: bool = boss.request_skill_use_by_mode("primary")
	if not boss_request_ok:
		push_error("boss primary skill request returned false: %s" % str(boss.get_skill_runtime_state_snapshot()))
		quit(1)
		return
	await _await_physics_frames(40, "waiting for boss primary skill execution window")
	if not boss.has_method("get_last_executed_skill_id") or boss.get_last_executed_skill_id().is_empty():
		push_error("boss did not execute a skill through the unified skill executor; requested=%s runtime=%s" % [
			str(boss.get_last_requested_skill_id()),
			str(boss.get_skill_runtime_state_snapshot()),
		])
		quit(1)
		return
	if boss.get_last_executed_skill_id() != "boss_guardian_triple_cleave":
		push_error("boss executed unexpected primary skill: %s" % str(boss.get_last_executed_skill_id()))
		quit(1)
		return
	if boss.global_position.distance_to(boss_position_before) > 1.0:
		push_error("boss moved during triple cleave execution: %s -> %s" % [str(boss_position_before), str(boss.global_position)])
		quit(1)
		return
	if boss.has_method("get_attack_execution_debug_state"):
		var boss_attack_state: Dictionary = boss.get_attack_execution_debug_state()
		var current_state: Dictionary = boss_attack_state.get("current_state", {})
		var last_state: Dictionary = boss_attack_state.get("last_state", {})
		var sequence_type := str(current_state.get("sequence_type", last_state.get("sequence_type", "")))
		if sequence_type != "multi_stage_sector":
			push_error("boss triple cleave did not record multi-stage sector execution: %s" % str(boss_attack_state))
			quit(1)
			return

	if not village.request_open_overlay(player_menu):
		push_error("failed to reopen player menu for skills page validation")
		quit(1)
		return
	player_menu.visible = true
	player_menu._show_tab("skills")
	await _await_frames(1, "waiting for skills tab reopen")
	player_menu.handle_skill_slot_double_click(0)
	await _await_frames(1, "waiting for slash unequip from skills page")
	if player.is_skill_equipped("slash_skill"):
		push_error("slash_skill should be unequipped after skill slot double click")
		quit(1)
		return
	player_menu._close_menu()
	await _await_frames(1, "waiting for skills page close after unequip")

	var enemy_before_without_skill: int = int(enemy.get_enemy_data().get("health", 0))
	player.global_position = enemy.global_position + Vector2(-2.0, 0.0)
	await _await_frames(4, "waiting for nearby auto-slash idle window while unequipped")
	if player.get_slash_cooldown_remaining() > 0.0:
		push_error("slash cooldown started even after unequipping the skill")
		quit(1)
		return
	if is_instance_valid(enemy) and int(enemy.get_enemy_data().get("health", 0)) < enemy_before_without_skill:
		push_error("unequipped slash_skill still damaged nearby enemy")
		quit(1)
		return

	player.global_position = enemy.global_position + Vector2(-96.0, 0.0)
	await _await_frames(1, "waiting for player reposition before re-equip")

	if not village.request_open_overlay(player_menu):
		push_error("failed to reopen player menu for slash re-equip validation")
		quit(1)
		return
	player_menu.visible = true
	player_menu._show_tab("skills")
	await _await_frames(1, "waiting for skills tab reopen before re-equip")
	player_menu.handle_skill_entry_double_click("slash_skill")
	await _await_frames(1, "waiting for slash re-equip from skills page")
	if not player.is_skill_equipped("slash_skill"):
		push_error("slash_skill did not re-equip from skills page")
		quit(1)
		return
	if player.get_equipped_skill_id(0) != "slash_skill":
		push_error("HUD skill slot did not sync to slash_skill after re-equip")
		quit(1)
		return
	if player_menu.skill_page_slot_grid == null or player_menu.skill_page_slot_grid.columns != 2:
		push_error("skills page slot grid did not switch to multi-slot layout")
		quit(1)
		return
	player_menu.handle_drop_on_drag_card("skill_pool", "", {}, {
		"card_role": "skill_slot",
		"card_id": "slash_skill",
		"payload": {"slot_index": 0},
	})
	await _await_frames(1, "waiting for slash drag unequip to skill pool")
	if player.is_skill_equipped("slash_skill"):
		push_error("skill drag back to pool did not unequip slash_skill")
		quit(1)
		return
	player_menu.handle_drop_on_drag_card("skill_slot", "", {"slot_index": 0}, {
		"card_role": "skill_pool_entry",
		"card_id": "slash_skill",
		"payload": {},
	})
	await _await_frames(1, "waiting for slash drag equip to slot 0")
	if player.get_equipped_skill_id(0) != "slash_skill":
		push_error("skill drag into slot 0 did not re-equip slash_skill")
		quit(1)
		return
	player_menu._close_menu()
	await _await_frames(1, "waiting for skills page close after re-equip")

	var enemy_before: int = int(enemy.get_enemy_data().get("health", 0))
	player.global_position = enemy.global_position + Vector2(-2.0, 0.0)
	await _await_frames(4, "waiting for nearby auto-slash idle window while equipped")

	if player.get_slash_cooldown_remaining() <= 0.0:
		push_error("slash auto trigger did not start cooldown")
		quit(1)
		return
	var enemy_was_damaged := not is_instance_valid(enemy)
	for _attempt in range(12):
		if not is_instance_valid(enemy):
			enemy_was_damaged = true
			break
		if int(enemy.get_enemy_data().get("health", 0)) < enemy_before:
			enemy_was_damaged = true
			break
		await _await_frames(1, "waiting for slash auto damage registration")
	if not enemy_was_damaged:
		push_error("slash auto trigger did not damage nearby enemy")
		quit(1)
		return

	print("check_gameplay_regressions_ok")
	quit(0)


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


func _await_physics_frames(frame_count: int, label: String) -> void:
	for _frame_index in range(frame_count):
		_guard_timeout(label)
		await physics_frame
		_guard_timeout(label)


func _guard_timeout(label: String) -> void:
	var elapsed_sec := float(Time.get_ticks_msec() - _check_started_msec) / 1000.0
	if elapsed_sec > CHECK_TIMEOUT_SEC:
		push_error("%s timed out while %s after %.2f seconds" % [CHECK_NAME, label, elapsed_sec])
		quit(1)


func _find_inventory_index(player: Node, template_id: String) -> int:
	var inventory_slots: Array = player.get_inventory_slots()
	for index in range(inventory_slots.size()):
		var item_stack := ItemSystem.normalize_item_stack(inventory_slots[index] as Dictionary)
		if str(item_stack.get("template_id", "")) == template_id:
			return index
	return -1


func _find_goddess_actor(village: Node) -> Node:
	if village == null or village.chest_layer == null:
		return null
	for child in village.chest_layer.get_children():
		if child.has_method("get_display_name") and str(child.get_display_name()) == "复活女神":
			return child
	return null


func _get_boss_enemy(village: Node) -> Node:
	for entry in village.enemy_registry.values():
		var enemy_data: Dictionary = entry as Dictionary
		if str(enemy_data.get("template_id", "")) == "boss_guardian":
			return enemy_data.get("node")
	return null


func _get_enemy_by_template_id(village: Node, template_id: String) -> Node:
	for entry in village.enemy_registry.values():
		var enemy_data: Dictionary = entry as Dictionary
		if str(enemy_data.get("template_id", "")) == template_id:
			return enemy_data.get("node")
	return null


func _assert_enemy_visual_config(enemy: Node, label: String, expected_frames_path: String, expected_sheet_path: String) -> bool:
	if enemy == null or not enemy.has_method("get_visual_debug_state"):
		push_error("%s visual debug state missing" % label)
		quit(1)
		return false
	var visual_state: Dictionary = enemy.get_visual_debug_state()
	if not bool(visual_state.get("uses_sprite_visuals", false)):
		push_error("%s sprite visuals not enabled" % label)
		quit(1)
		return false
	if str(visual_state.get("configured_sprite_frames_path", "")) != expected_frames_path:
		push_error("%s sprite frames path mismatch: %s" % [label, str(visual_state.get("configured_sprite_frames_path", ""))])
		quit(1)
		return false
	var actual_sheet_path := str(visual_state.get("sheet_path", ""))
	if expected_sheet_path.is_empty():
		if not actual_sheet_path.is_empty():
			push_error("%s sheet path should be empty but was %s" % [label, actual_sheet_path])
			quit(1)
			return false
	else:
		if actual_sheet_path != expected_sheet_path:
			push_error("%s sheet path mismatch: %s" % [label, actual_sheet_path])
			quit(1)
			return false
	if str(visual_state.get("current_animation", "")).is_empty():
		push_error("%s current animation empty" % label)
		quit(1)
		return false
	return true


func _array_contains_text(values: Array, needle: String) -> bool:
	for entry in values:
		if str(entry).contains(needle):
			return true
	return false


func _get_first_hostile_enemy(village: Node) -> Node2D:
	for entry in village.enemy_registry.values():
		var enemy: Node2D = (entry as Dictionary).get("node")
		if enemy != null and is_instance_valid(enemy) and enemy.has_method("is_hostile_to_player") and enemy.is_hostile_to_player():
			return enemy
	return null


func _count_visible_drag_cards(root_node: Node) -> int:
	if root_node == null:
		return 0
	var count := 0
	if root_node.has_method("get_render_debug_state"):
		var debug_state: Dictionary = root_node.call("get_render_debug_state")
		if bool(debug_state.get("visible", false)) \
		and float(debug_state.get("self_modulate_alpha", 0.0)) > 0.01 \
		and not str(debug_state.get("title_text", "")).is_empty() \
		and (debug_state.get("minimum_size", Vector2.ZERO) as Vector2).y > 0.0:
			count += 1
	for child in root_node.get_children():
		count += _count_visible_drag_cards(child)
	return count


