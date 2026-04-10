extends SceneTree

const CHECK_NAME := "check_dialogue_system"
const CHECK_TIMEOUT_SEC := 30.0

var _check_started_msec: int = 0


func _init() -> void:
	_check_started_msec = Time.get_ticks_msec()
	_start_watchdog()
	call_deferred("_run_check")


func _run_check() -> void:
	var game_state: Node = root.get_node_or_null("/root/GameState")
	var dialogue_manager: Node = root.get_node_or_null("/root/DialogueManager")
	if game_state == null:
		push_error("GameState autoload missing")
		quit(1)
		return
	if dialogue_manager == null:
		push_error("DialogueManager autoload missing")
		quit(1)
		return

	game_state.set_current_character({
		"class_id": "warrior",
		"class_name": "战士",
		"background_id": "student",
		"background_name": "学生",
		"trait_ids": ["eager_learner", "observant"],
		"profile_tags": ["student", "trait_eager_learner", "trait_observant"],
		"granted_triggers": [],
		"event_flags": {},
		"level": 1,
		"a_stats": {
			"strength": 7,
			"agility": 6,
			"intelligence": 8,
			"perception": 10,
			"fortitude": 6,
			"willpower": 7,
		},
		"b_stats": {},
	})

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
	await _await_frames(2, "waiting for newbie_village scene bootstrap")

	if not dialogue_manager.start_dialogue("spawn_goddess_intro", null, {"source_name": "smoke_test"}):
		push_error("start spawn_goddess_intro failed")
		quit(1)
		return

	var opening_view: Dictionary = dialogue_manager.get_current_view_model()
	if not _view_model_contains_text(opening_view, "学生"):
		push_error("student background feedback missing in goddess intro")
		quit(1)
		return
	if not _view_model_contains_text(opening_view, "求知欲"):
		push_error("trait eager_learner feedback missing in goddess intro")
		quit(1)
		return
	if not _view_model_contains_text(opening_view, "观察入微"):
		push_error("trait observant feedback missing in goddess intro")
		quit(1)
		return

	if not _option_exists(dialogue_manager.get_current_options(), "ask_about_trials"):
		push_error("ask_about_trials option missing on goddess intro")
		quit(1)
		return

	dialogue_manager.choose_option("ask_about_trials")
	await _await_frames(1, "waiting for goddess trial briefing branch")
	if dialogue_manager.get_current_node_id() != "trial_briefing":
		push_error("did not jump to trial_briefing")
		quit(1)
		return
	if not _view_model_contains_text(dialogue_manager.get_current_view_model(), "三段试炼"):
		push_error("trial briefing text missing expected flow summary")
		quit(1)
		return

	dialogue_manager.choose_option("begin_trial")
	await _await_frames(1, "waiting for goddess intro completion")
	if dialogue_manager.is_dialogue_active():
		push_error("dialogue should be closed after begin_trial")
		quit(1)
		return

	if not game_state.has_granted_trigger("finished_goddess_intro_dialogue"):
		push_error("finished_goddess_intro_dialogue trigger not granted")
		quit(1)
		return
	if not game_state.has_granted_trigger("finished_intro_villager_dialogue"):
		push_error("legacy intro completion trigger not granted for compatibility")
		quit(1)
		return
	if not bool(game_state.get_event_flag("intro_room_overview_seen", false)):
		push_error("intro_room_overview_seen flag not set")
		quit(1)
		return

	print("check_dialogue_system_ok")
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


func _option_exists(options: Array, option_id: String) -> bool:
	for option in options:
		if str((option as Dictionary).get("id", "")) == option_id:
			return true
	return false


func _view_model_contains_text(view_model: Dictionary, needle: String) -> bool:
	for row in view_model.get("text_rows", []):
		for fragment in row:
			if str((fragment as Dictionary).get("text", "")).contains(needle):
				return true
	return false
