extends SceneTree

const CharacterCreationRegistryScript = preload("res://character_creation/scripts/character_creation_registry.gd")
const DialogueTriggerEvaluatorScript = preload("res://game/scripts/dialogue_trigger_evaluator.gd")
const HoverDetailResolverScript = preload("res://game/scripts/hover_detail_resolver.gd")
const CHECK_NAME := "check_character_creation_flow"
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

	var scene: PackedScene = load("res://character_creation/scenes/character_creation_flow.tscn")
	if scene == null:
		push_error("load character_creation_flow.tscn failed")
		quit(1)
		return

	var instance = scene.instantiate()
	if instance == null:
		push_error("instantiate character_creation_flow.tscn failed")
		quit(1)
		return

	root.add_child(instance)
	await _await_frames(2, "waiting for character creation scene bootstrap")

	var expected_past_lives := ["student", "worker", "esports", "courier", "idle"]
	if CharacterCreationRegistryScript.get_past_life_ids() != expected_past_lives:
		push_error("past life registry mismatch: %s" % str(CharacterCreationRegistryScript.get_past_life_ids()))
		quit(1)
		return

	instance.select_past_life("worker")
	instance.call("_show_step", 2)
	await _await_frames(1, "waiting for worker step 2 page")
	var worker_trait_candidates: Array = instance.call("_get_trait_candidate_ids", "职业相关特性")
	if worker_trait_candidates.size() != 2 or not worker_trait_candidates.has("pressure_inertia") or not worker_trait_candidates.has("process_familiarity"):
		push_error("worker profession traits did not refresh correctly")
		quit(1)
		return

	instance.select_past_life("student")
	instance.call("_show_step", 2)
	await _await_frames(1, "waiting for step 2 page")
	if not instance.has_method("_get_trait_candidate_ids"):
		push_error("step 2 helper methods missing")
		quit(1)
		return
	var student_trait_candidates: Array = instance.call("_get_trait_candidate_ids", "职业相关特性")
	if student_trait_candidates.size() != 2 or not student_trait_candidates.has("eager_learner") or not student_trait_candidates.has("exam_memory"):
		push_error("student profession traits did not refresh correctly")
		quit(1)
		return
	if _count_visible_drag_cards(instance.get_node("Step2Page")) < 3:
		push_error("step 2 visible drag cards too few")
		quit(1)
		return

	instance.handle_drop_on_drag_card("trait_slot", "", {"slot_index": 1, "selection_type": "trait"}, {
		"card_role": "trait_candidate",
		"card_id": "exam_memory",
		"payload": {"selection_type": "trait"},
	})
	await _await_frames(1, "waiting for trait drag into slot 2")
	if instance.selected_trait_slots[1] != "exam_memory":
		push_error("trait drag did not place exam_memory into slot 2")
		quit(1)
		return
	instance.handle_drag_card_double_click("trait_candidate", "observant", {"selection_type": "trait"})
	await _await_frames(1, "waiting for trait double click into first empty slot")
	if instance.selected_trait_slots[0] != "observant":
		push_error("trait double click did not fill first empty slot")
		quit(1)
		return
	if (instance.call("_get_trait_candidate_ids", "职业相关特性") as Array).has("exam_memory"):
		push_error("selected trait still appears in step 2 candidate pool")
		quit(1)
		return
	instance.handle_drop_on_drag_card("trait_pool", "", {"selection_type": "trait"}, {
		"card_role": "trait_slot",
		"card_id": "exam_memory",
		"payload": {"slot_index": 1, "selection_type": "trait"},
	})
	await _await_frames(1, "waiting for trait removal drag back to pool")
	if instance.selected_trait_ids.has("exam_memory"):
		push_error("trait drag back to pool did not remove selection")
		quit(1)
		return
	instance.handle_drag_card_double_click("trait_candidate", "exam_memory", {"selection_type": "trait"})
	await _await_frames(1, "waiting for trait re-selection")

	instance.call("_show_step", 3)
	await _await_frames(1, "waiting for step 3 page")
	var step_3_page: Control = instance.get_node_or_null("Step3Page")
	if step_3_page == null or not step_3_page.visible:
		push_error("step 3 page is not visible after _show_step(3)")
		quit(1)
		return
	var step_3_next_button: Button = instance.get_node_or_null("Step3Page/MarginContainer/Panel/Content/Stack/Footer/Step3NextButton")
	if step_3_next_button == null:
		push_error("step 3 next button missing")
		quit(1)
		return
	if not step_3_next_button.visible:
		push_error("step 3 next button is hidden")
		quit(1)
		return
	if step_3_next_button.size.y < 40.0:
		push_error("step 3 next button height looks collapsed")
		quit(1)
		return
	if not instance.can_drop_on_drag_card("strength_slot", instance.selected_strength_id, {"selection_type": "strength"}, {
		"card_role": "strength_candidate",
		"card_id": "keen_senses",
		"payload": {"selection_type": "strength"},
	}):
		push_error("strength candidate cannot be dropped into strength slot")
		quit(1)
		return
	if instance.can_drop_on_drag_card("weakness_slot", instance.selected_weakness_id, {"selection_type": "weakness"}, {
		"card_role": "strength_candidate",
		"card_id": "keen_senses",
		"payload": {"selection_type": "strength"},
	}):
		push_error("strength candidate should not be droppable into weakness slot")
		quit(1)
		return
	instance.handle_drop_on_drag_card("strength_slot", "", {"selection_type": "strength"}, {
		"card_role": "strength_candidate",
		"card_id": "keen_senses",
		"payload": {"selection_type": "strength"},
	})
	instance.handle_drop_on_drag_card("weakness_slot", "", {"selection_type": "weakness"}, {
		"card_role": "weakness_candidate",
		"card_id": "frail",
		"payload": {"selection_type": "weakness"},
	})
	await _await_frames(1, "waiting for step 3 drag selections")
	if instance.selected_strength_id != "keen_senses" or instance.selected_weakness_id != "frail":
		push_error("step 3 drag selection did not persist expected results")
		quit(1)
		return
	if _count_visible_drag_cards(instance.get_node("Step3Page")) < 4:
		push_error("step 3 visible drag cards too few")
		quit(1)
		return

	instance.call("_show_step", 4)
	await _await_frames(1, "waiting for step 4 page")
	var step_4_grid := _find_grid_with_columns(instance.get_node("Step4Page"), 3)
	if step_4_grid == null:
		push_error("step 4 horizontal card grid missing")
		quit(1)
		return
	if _count_visible_drag_cards(step_4_grid) <= 0:
		push_error("step 4 visible personality cards missing")
		quit(1)
		return
	instance.handle_drag_card_single_click("personality_choice", "calm", {"selection_type": "personality"})
	await _await_frames(1, "waiting for personality selection")
	if instance.selected_personality_id != "calm":
		push_error("step 4 single click did not select calm personality")
		quit(1)
		return

	instance.call("_show_step", 5)
	await _await_frames(1, "waiting for step 5 page")
	var step_5_grid := _find_grid_with_columns(instance.get_node("Step5Page"), 3)
	if step_5_grid == null:
		push_error("step 5 horizontal job grid missing")
		quit(1)
		return
	if _count_visible_drag_cards(step_5_grid) <= 0:
		push_error("step 5 visible reborn job cards missing")
		quit(1)
		return
	instance.handle_drag_card_single_click("reborn_job_choice", "warrior", {"selection_type": "reborn_job"})
	await _await_frames(1, "waiting for reborn job selection")
	if instance.selected_class_id != "warrior":
		push_error("step 5 single click did not select warrior reborn job")
		quit(1)
		return

	var hover_cases := [
		{"source_id": "past_life:student", "selection_type": "past_life", "selection_id": "student"},
		{"source_id": "strength:keen_senses", "selection_type": "strength", "selection_id": "keen_senses"},
		{"source_id": "weakness:frail", "selection_type": "weakness", "selection_id": "frail"},
	]
	for hover_case in hover_cases:
		var hover_detail: Dictionary = HoverDetailResolverScript.resolve(
			"creation_selection",
			str(hover_case.get("source_id", "")),
			{
				"selection_type": str(hover_case.get("selection_type", "")),
				"selection_id": str(hover_case.get("selection_id", "")),
				"selection_state": instance.build_character_preview_data(),
			}
		)
		if hover_detail.is_empty():
			push_error("creation selection hover detail missing: %s" % str(hover_case.get("source_id", "")))
			quit(1)
			return
		var summary_lines: Array = hover_detail.get("summary_lines", [])
		if summary_lines.is_empty():
			push_error("creation selection hover summary missing: %s" % str(hover_case.get("source_id", "")))
			quit(1)
			return

	if not instance.selected_trait_ids.has("exam_memory"):
		instance.toggle_trait("exam_memory")
	if not instance.selected_trait_ids.has("observant"):
		instance.toggle_trait("observant")
	instance.select_strength("keen_senses")
	instance.select_weakness("frail")
	instance.select_personality("calm")
	instance.select_reborn_job("warrior")
	instance.set_a_stat_target_value("strength", 9)
	await _await_frames(1, "waiting for character preview refresh")

	var character_data: Dictionary = instance.create_character_now()
	if character_data.is_empty():
		push_error("create_character_now returned empty data")
		quit(1)
		return

	var required_keys := [
		"past_life_id",
		"background_id",
		"trait_ids",
		"strength_id",
		"weakness_id",
		"personality_id",
		"reborn_job_id",
		"class_id",
		"profile_tags",
		"a_stats",
		"b_stats",
	]
	for key in required_keys:
		if not character_data.has(key):
			push_error("missing key in character data: %s" % str(key))
			quit(1)
			return

	if str(character_data.get("past_life_id", "")) != "student":
		push_error("past_life_id mismatch")
		quit(1)
		return
	if str(character_data.get("background_id", "")) != "student":
		push_error("background_id mismatch")
		quit(1)
		return
	if str(character_data.get("reborn_job_id", "")) != "warrior":
		push_error("reborn_job_id mismatch")
		quit(1)
		return
	if str(character_data.get("class_id", "")) != "warrior":
		push_error("class_id mismatch")
		quit(1)
		return

	var trait_ids: Array = character_data.get("trait_ids", [])
	if trait_ids.size() != 2 or not trait_ids.has("exam_memory") or not trait_ids.has("observant"):
		push_error("trait_ids mismatch")
		quit(1)
		return
	if str(character_data.get("strength_id", "")) != "keen_senses":
		push_error("strength_id mismatch")
		quit(1)
		return
	if str(character_data.get("weakness_id", "")) != "frail":
		push_error("weakness_id mismatch")
		quit(1)
		return
	if str(character_data.get("personality_id", "")) != "calm":
		push_error("personality_id mismatch")
		quit(1)
		return

	game_state.set_current_character(character_data)
	var trigger_evaluator := DialogueTriggerEvaluatorScript.new()
	var context := {"game_state": game_state}
	var required_triggers := [
		"bg_student",
		"trait_exam_memory",
		"trait_observant",
		"strength_keen_senses",
		"weakness_frail",
		"personality_calm",
	]
	for trigger_id in required_triggers:
		if not trigger_evaluator.has_trigger(trigger_id, context):
			push_error("expected trigger missing: %s" % trigger_id)
			quit(1)
			return

	if game_state.has_granted_trigger("bg_student"):
		push_error("derived trigger should not be stored as granted")
		quit(1)
		return

	print("check_character_creation_flow_ok")
	quit(0)


func _find_grid_with_columns(root_node: Node, expected_columns: int) -> GridContainer:
	if root_node == null:
		return null
	if root_node is GridContainer and (root_node as GridContainer).columns == expected_columns:
		return root_node as GridContainer
	for child in root_node.get_children():
		var nested := _find_grid_with_columns(child, expected_columns)
		if nested != null:
			return nested
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
