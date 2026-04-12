extends SceneTree

const GameplaySceneContract = preload("res://game/scripts/gameplay_scene_contract.gd")
const CHECK_NAME := "check_newbie_village"
const CHECK_TIMEOUT_SEC := 30.0

var _check_started_msec: int = 0


func _init() -> void:
	_check_started_msec = Time.get_ticks_msec()
	_start_watchdog()
	call_deferred("_run_check")


func _run_check() -> void:
	var scene: PackedScene = load("res://game/scenes/newbie_village.tscn")
	if scene == null:
		push_error("load newbie_village.tscn failed")
		quit(1)
		return

	var instance := scene.instantiate()
	if instance == null:
		push_error("instantiate newbie_village.tscn failed")
		quit(1)
		return

	root.add_child(instance)
	await _await_frames(2, "waiting for newbie_village bootstrap")

	var contract_errors := GameplaySceneContract.validate_scene(instance, {
		"require_dialogue_registration": true,
	})
	if not contract_errors.is_empty():
		push_error("newbie_village scene contract errors: %s" % str(contract_errors))
		quit(1)
		return

	if not str(instance.village_info_label.text).contains("新手教程房"):
		push_error("newbie_village display title mismatch: %s" % str(instance.village_info_label.text))
		quit(1)
		return

	var room_ids := PackedStringArray(instance.room_bounds_by_id.keys())
	room_ids.sort()
	var expected_room_ids := PackedStringArray(["boss_room", "spawn", "trial_room_1", "trial_room_2"])
	if room_ids != expected_room_ids:
		push_error("newbie_village room ids mismatch: %s" % str(room_ids))
		quit(1)
		return

	var room_templates := {
		"trial_room_1": [],
		"trial_room_2": [],
		"boss_room": [],
	}
	for entry in instance.enemy_registry.values():
		var enemy_data: Dictionary = entry as Dictionary
		var room_id := str(enemy_data.get("room_id", ""))
		if room_templates.has(room_id):
			(room_templates[room_id] as Array).append(str(enemy_data.get("template_id", "")))
	for room_id in room_templates.keys():
		(room_templates[room_id] as Array).sort()

	if room_templates["trial_room_1"] != ["melee_grunt"]:
		push_error("trial_room_1 enemy composition mismatch: %s" % str(room_templates["trial_room_1"]))
		quit(1)
		return
	if room_templates["trial_room_2"] != ["melee_grunt", "ranged_grunt"]:
		push_error("trial_room_2 enemy composition mismatch: %s" % str(room_templates["trial_room_2"]))
		quit(1)
		return
	if room_templates["boss_room"] != ["boss_guardian"]:
		push_error("boss_room enemy composition mismatch: %s" % str(room_templates["boss_room"]))
		quit(1)
		return

	var melee_visual_nodes: Array[Node] = []
	var ranged_visual_node: Node = null
	var boss_visual_node: Node = null
	for entry in instance.enemy_registry.values():
		var enemy_data: Dictionary = entry as Dictionary
		var template_id := str(enemy_data.get("template_id", ""))
		var enemy_node: Node = enemy_data.get("node")
		if template_id == "melee_grunt":
			_assert_enemy_owned_skills(enemy_node, ["melee_grunt_slash"], "melee_grunt")
		if template_id == "melee_grunt":
			melee_visual_nodes.append(enemy_node)
		elif template_id == "ranged_grunt":
			_assert_enemy_owned_skills(enemy_node, ["ranged_grunt_energy_shot", "ranged_grunt_close_counter"], "ranged_grunt")
			ranged_visual_node = enemy_node
		elif template_id == "boss_guardian":
			_assert_enemy_owned_skills(enemy_node, ["boss_guardian_triple_cleave"], "boss_guardian")
			boss_visual_node = enemy_node

	if melee_visual_nodes.size() != 2:
		push_error("expected 2 melee grunt nodes, got %d" % melee_visual_nodes.size())
		quit(1)
		return
	var expected_melee_sprite_frames_path := "res://game/assets/textures/characters/enemies/melee_grunt/animations/melee_grunt_sprite_frames_v001.tres"
	var expected_melee_sheet_path := "res://game/assets/textures/characters/enemies/melee_grunt/spritesheets/melee_grunt_sheet_v001.png"
	var expected_animations := [
		"idle_down",
		"idle_up",
		"idle_left",
		"idle_right",
		"move_down",
		"move_up",
		"move_left",
		"move_right",
	]
	for enemy_node in melee_visual_nodes:
		if enemy_node == null or not enemy_node.has_method("get_visual_debug_state"):
			push_error("melee grunt visual debug state missing")
			quit(1)
			return
		var visual_state: Dictionary = enemy_node.get_visual_debug_state()
		if not bool(visual_state.get("uses_sprite_visuals", false)):
			push_error("melee grunt did not enable sprite visuals")
			quit(1)
			return
		if str(visual_state.get("configured_sprite_frames_path", "")) != expected_melee_sprite_frames_path:
			push_error("melee grunt configured sprite frames path mismatch: %s" % str(visual_state.get("configured_sprite_frames_path", "")))
			quit(1)
			return
		if str(visual_state.get("sheet_path", "")) != expected_melee_sheet_path:
			push_error("melee grunt sheet path mismatch: %s" % str(visual_state.get("sheet_path", "")))
			quit(1)
			return
		if not bool(visual_state.get("visual_visible", false)) or bool(visual_state.get("body_visible", true)):
			push_error("melee grunt visual node visibility mismatch: %s" % str(visual_state))
			quit(1)
			return
		if not str(visual_state.get("current_animation", "")).begins_with("idle_"):
			push_error("melee grunt should bootstrap into idle animation: %s" % str(visual_state.get("current_animation", "")))
			quit(1)
			return
		var available_animations: Array = visual_state.get("available_animations", [])
		for animation_name in expected_animations:
			if not available_animations.has(animation_name):
				push_error("melee grunt missing animation %s in %s" % [animation_name, str(available_animations)])
				quit(1)
				return
		_assert_directional_atlas_regions(
			enemy_node,
			"melee grunt",
			Rect2(421, 997, 180, 270),
			Rect2(421, 675, 180, 270),
			Rect2(103, 997, 180, 270),
			Rect2(103, 675, 180, 270)
		)

	if ranged_visual_node == null or not ranged_visual_node.has_method("get_visual_debug_state"):
		push_error("ranged grunt visual debug state missing")
		quit(1)
		return
	var ranged_visual_state: Dictionary = ranged_visual_node.get_visual_debug_state()
	_assert_expected_visual_state(
		ranged_visual_state,
		"ranged grunt",
		"res://game/assets/textures/characters/enemies/ranged_grunt/animations/ranged_grunt_sprite_frames_v001.tres",
		"res://game/assets/textures/characters/enemies/ranged_grunt/spritesheets/ranged_grunt_sheet_v001.png",
		expected_animations
	)
	_assert_directional_atlas_regions(
		ranged_visual_node,
		"ranged grunt",
		Rect2(421, 997, 180, 270),
		Rect2(421, 675, 180, 270),
		Rect2(103, 997, 180, 270),
		Rect2(103, 675, 180, 270)
	)
	_assert_overhead_head_offset_y(ranged_visual_node, "ranged grunt", -22.0)

	if boss_visual_node == null or not boss_visual_node.has_method("get_visual_debug_state"):
		push_error("boss visual debug state missing")
		quit(1)
		return
	var boss_visual_state: Dictionary = boss_visual_node.get_visual_debug_state()
	_assert_expected_visual_state(
		boss_visual_state,
		"boss guardian",
		"",
		"res://game/assets/textures/characters/enemies/newbie_boss/spritesheets/newbie_boss_sheet_v002.png",
		expected_animations
	)
	_assert_boss_direction_frames(boss_visual_node)
	_assert_boss_animation_frame_counts(boss_visual_node)

	var goddess_actor: Node = null
	var chest_like_count := 0
	for child in instance.chest_layer.get_children():
		if child.has_method("get_display_name") and str(child.get_display_name()) == "复活女神":
			goddess_actor = child
		else:
			chest_like_count += 1
	if goddess_actor == null:
		push_error("spawn room goddess actor missing")
		quit(1)
		return
	if not goddess_actor.has_method("get_faction_id") or goddess_actor.get_faction_id() != "friendly":
		push_error("goddess actor faction mismatch")
		quit(1)
		return
	if not goddess_actor.has_method("get_ai_id") or goddess_actor.get_ai_id() != "npc_guard_friendly_idle":
		push_error("goddess actor ai mismatch")
		quit(1)
		return
	if not goddess_actor.has_method("get_actor_kind") or goddess_actor.get_actor_kind() != "npc":
		push_error("goddess actor kind mismatch")
		quit(1)
		return
	var dialogue_interactor: Node = goddess_actor.get_node_or_null("DialogueInteractor")
	if dialogue_interactor == null:
		push_error("goddess dialogue interactor missing")
		quit(1)
		return
	if str(dialogue_interactor.get("dialogue_id")) != "spawn_goddess_intro":
		push_error("goddess dialogue id mismatch: %s" % str(dialogue_interactor.get("dialogue_id")))
		quit(1)
		return
	if chest_like_count <= 0:
		push_error("spawn room chest appears to be missing")
		quit(1)
		return

	print("check_newbie_village_ok")
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


func _guard_timeout(label: String) -> void:
	var elapsed_sec := float(Time.get_ticks_msec() - _check_started_msec) / 1000.0
	if elapsed_sec > CHECK_TIMEOUT_SEC:
		push_error("%s timed out while %s after %.2f seconds" % [CHECK_NAME, label, elapsed_sec])
		quit(1)


func _assert_expected_visual_state(visual_state: Dictionary, label: String, expected_frames_path: String, expected_sheet_path: String, expected_animations: Array) -> void:
	if not bool(visual_state.get("uses_sprite_visuals", false)):
		push_error("%s did not enable sprite visuals" % label)
		quit(1)
		return
	if str(visual_state.get("configured_sprite_frames_path", "")) != expected_frames_path:
		push_error("%s configured sprite frames path mismatch: %s" % [label, str(visual_state.get("configured_sprite_frames_path", ""))])
		quit(1)
		return
	var actual_sheet_path := str(visual_state.get("sheet_path", ""))
	if expected_sheet_path.is_empty():
		if not actual_sheet_path.is_empty():
			push_error("%s sheet path should be empty but was %s" % [label, actual_sheet_path])
			quit(1)
			return
	else:
		if actual_sheet_path != expected_sheet_path:
			push_error("%s sheet path mismatch: %s" % [label, actual_sheet_path])
			quit(1)
			return
	if not bool(visual_state.get("visual_visible", false)) or bool(visual_state.get("body_visible", true)):
		push_error("%s visual node visibility mismatch: %s" % [label, str(visual_state)])
		quit(1)
		return
	if not str(visual_state.get("current_animation", "")).begins_with("idle_"):
		push_error("%s should bootstrap into idle animation: %s" % [label, str(visual_state.get("current_animation", ""))])
		quit(1)
		return
	var available_animations: Array = visual_state.get("available_animations", [])
	for animation_name in expected_animations:
		if not available_animations.has(animation_name):
			push_error("%s missing animation %s in %s" % [label, animation_name, str(available_animations)])
			quit(1)
			return


func _assert_boss_direction_frames(boss_visual_node: Node) -> void:
	if boss_visual_node == null:
		push_error("boss visual node missing for direction frame check")
		quit(1)
		return
	var visual_sprite := boss_visual_node.get_node_or_null("VisualSprite") as AnimatedSprite2D
	if visual_sprite == null or visual_sprite.sprite_frames == null:
		push_error("boss visual sprite missing runtime sprite frames")
		quit(1)
		return
	var sprite_frames := visual_sprite.sprite_frames
	var idle_left_region := _get_atlas_region(sprite_frames, "idle_left", 0)
	var idle_right_region := _get_atlas_region(sprite_frames, "idle_right", 0)
	var idle_up_region := _get_atlas_region(sprite_frames, "idle_up", 0)
	var idle_down_region := _get_atlas_region(sprite_frames, "idle_down", 0)
	if idle_left_region != Rect2(40, 2048, 259, 1024):
		push_error("boss idle_left region mismatch: %s" % str(idle_left_region))
		quit(1)
		return
	if idle_right_region != Rect2(21, 3072, 248, 1024):
		push_error("boss idle_right region mismatch: %s" % str(idle_right_region))
		quit(1)
		return
	if idle_up_region != Rect2(29, 1024, 268, 1024):
		push_error("boss idle_up region mismatch: %s" % str(idle_up_region))
		quit(1)
		return
	if idle_down_region != Rect2(33, 0, 265, 1024):
		push_error("boss idle_down region mismatch: %s" % str(idle_down_region))
		quit(1)
		return


func _assert_boss_animation_frame_counts(boss_visual_node: Node) -> void:
	var visual_sprite := boss_visual_node.get_node_or_null("VisualSprite") as AnimatedSprite2D
	if visual_sprite == null or visual_sprite.sprite_frames == null:
		push_error("boss visual sprite missing for frame count check")
		quit(1)
		return
	var sprite_frames := visual_sprite.sprite_frames
	if sprite_frames.get_frame_count("move_left") != 6:
		push_error("boss move_left frame count mismatch: %d" % sprite_frames.get_frame_count("move_left"))
		quit(1)
		return
	if sprite_frames.get_frame_count("move_right") != 6:
		push_error("boss move_right frame count mismatch: %d" % sprite_frames.get_frame_count("move_right"))
		quit(1)
		return
	if sprite_frames.get_frame_count("move_up") != 5:
		push_error("boss move_up frame count mismatch: %d" % sprite_frames.get_frame_count("move_up"))
		quit(1)
		return
	if sprite_frames.get_frame_count("move_down") != 5:
		push_error("boss move_down frame count mismatch: %d" % sprite_frames.get_frame_count("move_down"))
		quit(1)
		return
	if _get_atlas_region(sprite_frames, "move_left", 0).size.x >= 800.0:
		push_error("boss move_left first frame still looks like an oversized strip slice: %s" % str(_get_atlas_region(sprite_frames, "move_left", 0)))
		quit(1)
		return


func _get_atlas_region(sprite_frames: SpriteFrames, animation_name: StringName, frame_index: int) -> Rect2:
	var frame_texture := sprite_frames.get_frame_texture(animation_name, frame_index)
	var atlas_texture := frame_texture as AtlasTexture
	return atlas_texture.region if atlas_texture != null else Rect2()


func _assert_directional_atlas_regions(
	enemy_node: Node,
	label: String,
	expected_idle_left: Rect2,
	expected_idle_right: Rect2,
	expected_move_left: Rect2,
	expected_move_right: Rect2
) -> void:
	var visual_sprite := enemy_node.get_node_or_null("VisualSprite") as AnimatedSprite2D
	if visual_sprite == null or visual_sprite.sprite_frames == null:
		push_error("%s visual sprite missing runtime sprite frames" % label)
		quit(1)
		return
	var sprite_frames := visual_sprite.sprite_frames
	if _get_atlas_region(sprite_frames, "idle_left", 0) != expected_idle_left:
		push_error("%s idle_left region mismatch: %s" % [label, str(_get_atlas_region(sprite_frames, "idle_left", 0))])
		quit(1)
		return
	if _get_atlas_region(sprite_frames, "idle_right", 0) != expected_idle_right:
		push_error("%s idle_right region mismatch: %s" % [label, str(_get_atlas_region(sprite_frames, "idle_right", 0))])
		quit(1)
		return
	if _get_atlas_region(sprite_frames, "move_left", 0) != expected_move_left:
		push_error("%s move_left region mismatch: %s" % [label, str(_get_atlas_region(sprite_frames, "move_left", 0))])
		quit(1)
		return
	if _get_atlas_region(sprite_frames, "move_right", 0) != expected_move_right:
		push_error("%s move_right region mismatch: %s" % [label, str(_get_atlas_region(sprite_frames, "move_right", 0))])
		quit(1)
		return


func _assert_overhead_head_offset_y(enemy_node: Node, label: String, expected_y: float) -> void:
	var overhead_display := enemy_node.get_node_or_null("OverheadDisplay")
	if overhead_display == null or not overhead_display.has_method("get_debug_state"):
		push_error("%s overhead display debug state missing" % label)
		quit(1)
		return
	var debug_state: Dictionary = overhead_display.get_debug_state()
	var head_offset := debug_state.get("head_offset_pixels", Vector2.ZERO) as Vector2
	if absf(head_offset.y - expected_y) > 0.01:
		push_error("%s overhead head offset mismatch: %s" % [label, str(head_offset)])
		quit(1)
		return


func _assert_enemy_owned_skills(enemy_node: Node, expected_skill_ids: Array[String], label: String) -> void:
	if enemy_node == null or not enemy_node.has_method("get_owned_skill_ids"):
		push_error("%s missing skill runtime access" % label)
		quit(1)
		return
	var owned_skill_ids: Array[String] = enemy_node.get_owned_skill_ids()
	for expected_skill_id in expected_skill_ids:
		if not owned_skill_ids.has(expected_skill_id):
			push_error("%s missing formal skill_id %s in %s" % [label, expected_skill_id, str(owned_skill_ids)])
			quit(1)
			return
