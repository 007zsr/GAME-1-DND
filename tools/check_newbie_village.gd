extends SceneTree

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
