extends Node

const DialogueConditionEvaluatorScript = preload("res://game/scripts/dialogue_condition_evaluator.gd")
const DialogueActionExecutorScript = preload("res://game/scripts/dialogue_action_executor.gd")
const DialogueDataRegistryScript = preload("res://game/scripts/dialogue_data_registry.gd")
const DialogueTriggerEvaluatorScript = preload("res://game/scripts/dialogue_trigger_evaluator.gd")
const DialogueUIScene = preload("res://game/scenes/dialogue_ui.tscn")

signal dialogue_opened(dialogue_id: String)
signal dialogue_closed(dialogue_id: String, reason: String)
signal dialogue_view_changed(view_model: Dictionary)
signal dialogue_action_requested(action_type: String, payload: Dictionary)
signal dialogue_scene_adapter_changed(adapter: Node)

var scene_adapter: Node = null
var player: Node = null
var dialogue_ui_parent: Node = null
var hover_detail_manager: Control = null
var dialogue_ui: Control = null
var game_state: Node = null
var condition_evaluator = DialogueConditionEvaluatorScript.new()
var action_executor = DialogueActionExecutorScript.new()
var trigger_evaluator = DialogueTriggerEvaluatorScript.new()
var current_dialogue_id: String = ""
var current_node_id: String = ""
var current_dialogue_data: Dictionary = {}
var current_source: Node = null
var current_source_context: Dictionary = {}
var current_view_model: Dictionary = {}
var current_options: Array = []
var option_commit_locked: bool = false
var dialogue_flags: Dictionary = {}
var context_token_serial: int = 0
var active_context_token: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game_state = get_node_or_null("/root/GameState")
	condition_evaluator.configure(trigger_evaluator)


func is_dialogue_active() -> bool:
	return current_dialogue_id != ""


func register_scene_adapter(adapter: Node, player_node: Node, dialogue_ui_parent_node: Node, hover_manager: Control = null) -> void:
	if adapter == null:
		return
	if scene_adapter != null and scene_adapter != adapter and is_dialogue_active():
		close_dialogue("scene_adapter_switched")

	scene_adapter = adapter
	player = player_node
	dialogue_ui_parent = dialogue_ui_parent_node
	hover_detail_manager = hover_manager
	_ensure_dialogue_ui()
	emit_signal("dialogue_scene_adapter_changed", scene_adapter)


func unregister_scene_adapter(adapter: Node) -> void:
	if adapter == null or adapter != scene_adapter:
		return
	if is_dialogue_active():
		close_dialogue("scene_adapter_unregistered")
	scene_adapter = null
	player = null
	dialogue_ui_parent = null
	hover_detail_manager = null
	if dialogue_ui != null and is_instance_valid(dialogue_ui):
		dialogue_ui.queue_free()
	dialogue_ui = null


func get_dialogue_flags() -> Dictionary:
	return dialogue_flags.duplicate(true)


func set_dialogue_flag(flag_id: String, value: bool) -> void:
	if flag_id == "":
		return
	dialogue_flags[flag_id] = value


func start_dialogue(dialogue_id: String, source: Node = null, context: Dictionary = {}) -> bool:
	if dialogue_id == "":
		_warn("open_missing_dialogue_id", {"dialogue_id": dialogue_id})
		return false
	if is_dialogue_active():
		_warn("open_rejected_already_active", {"dialogue_id": current_dialogue_id})
		return false
	if scene_adapter == null or not is_instance_valid(scene_adapter):
		_warn("open_missing_scene_adapter", {"dialogue_id": dialogue_id})
		return false
	if not _ensure_dialogue_ui():
		_warn("open_missing_dialogue_ui", {"dialogue_id": dialogue_id})
		return false

	var dialogue_data: Dictionary = DialogueDataRegistryScript.get_dialogue(dialogue_id)
	if dialogue_data.is_empty():
		_warn("dialogue_data_missing", {"dialogue_id": dialogue_id})
		return false
	if not _begin_dialogue_context(dialogue_id, source):
		_warn("dialogue_context_rejected", {"dialogue_id": dialogue_id})
		return false

	current_dialogue_id = dialogue_id
	current_dialogue_data = dialogue_data
	current_source = source
	current_source_context = context.duplicate(true)
	current_view_model.clear()
	current_options.clear()
	option_commit_locked = false
	dialogue_flags.clear()

	var start_node_id: String = str(dialogue_data.get("start_node_id", ""))
	if start_node_id == "":
		close_dialogue("missing_start_node")
		return false

	if dialogue_ui.has_method("open_dialogue"):
		dialogue_ui.open_dialogue()
	emit_signal("dialogue_opened", current_dialogue_id)
	go_to_node(start_node_id)
	return true


func open_dialogue(dialogue_id: String, npc_node: Node) -> bool:
	return start_dialogue(dialogue_id, npc_node, {})


func close_dialogue(reason: String = "completed") -> void:
	end_dialogue(reason)


func choose_option(option_id: String) -> void:
	select_option(option_id)


func set_event_flag(flag_id: String, value: bool = true) -> void:
	if flag_id == "" or game_state == null or not game_state.has_method("set_event_flag"):
		return
	game_state.set_event_flag(flag_id, value)


func grant_trigger(trigger_id: String) -> void:
	if trigger_id == "" or game_state == null or not game_state.has_method("grant_trigger"):
		return
	game_state.grant_trigger(trigger_id)


func has_trigger(trigger_id: String) -> bool:
	return trigger_evaluator.has_trigger(trigger_id, _build_condition_context())


func get_current_view_model() -> Dictionary:
	return current_view_model.duplicate(true)


func get_current_options() -> Array:
	return current_options.duplicate(true)


func get_current_dialogue_id() -> String:
	return current_dialogue_id


func get_current_node_id() -> String:
	return current_node_id


func execute_scene_action(action_type: String, payload: Dictionary = {}, close_first: bool = true) -> bool:
	var final_payload := payload.duplicate(true)
	final_payload["action_type"] = action_type
	final_payload["dialogue_id"] = current_dialogue_id
	final_payload["node_id"] = current_node_id
	final_payload["context_token"] = active_context_token
	final_payload["source_context"] = current_source_context.duplicate(true)
	if current_source != null and is_instance_valid(current_source) and not final_payload.has("source_node"):
		final_payload["source_node"] = current_source

	if close_first and is_dialogue_active():
		end_dialogue("%s_requested" % action_type)

	emit_signal("dialogue_action_requested", action_type, final_payload)
	if scene_adapter != null and is_instance_valid(scene_adapter) and scene_adapter.has_method("handle_dialogue_action"):
		return bool(scene_adapter.handle_dialogue_action(action_type, final_payload, self))
	return false


func go_to_node(node_id: String) -> void:
	if current_dialogue_data.is_empty():
		return

	var nodes: Dictionary = current_dialogue_data.get("nodes", {})
	if not nodes.has(node_id):
		_warn("missing_node", {"dialogue_id": current_dialogue_id, "node_id": node_id})
		close_dialogue("missing_node")
		return

	var node_data: Dictionary = nodes[node_id] as Dictionary
	var node_log_context := {
		"dialogue_id": current_dialogue_id,
		"node_id": node_id,
	}
	if not condition_evaluator.are_conditions_met(node_data.get("conditions", []), _build_condition_context(), node_log_context, node_data):
		_warn("node_blocked_by_conditions", node_log_context)
		close_dialogue("node_blocked")
		return

	current_node_id = node_id
	option_commit_locked = false
	var view_model: Dictionary = _build_view_model(node_data)
	if view_model.is_empty():
		close_dialogue("empty_view_model")
		return

	if dialogue_ui != null and dialogue_ui.has_method("show_view_model"):
		dialogue_ui.show_view_model(view_model)
	emit_signal("dialogue_view_changed", view_model)
	current_view_model = view_model.duplicate(true)
	current_options = view_model.get("options", []).duplicate(true)
	if current_options.is_empty() and bool(node_data.get("auto_end_when_no_options", false)):
		close_dialogue("no_options_auto_end")


func select_option(option_id: String) -> void:
	if option_commit_locked:
		return
	if option_id == "":
		return

	var selected_option: Dictionary = {}
	for option in current_options:
		if str((option as Dictionary).get("id", "")) == option_id:
			selected_option = option as Dictionary
			break

	if selected_option.is_empty():
		_warn("option_missing", {
			"dialogue_id": current_dialogue_id,
			"node_id": current_node_id,
			"option_id": option_id,
		})
		return

	option_commit_locked = true
	if dialogue_ui != null and dialogue_ui.has_method("set_option_commit_locked"):
		dialogue_ui.set_option_commit_locked(true)

	var action_context := {
		"dialogue_id": current_dialogue_id,
		"node_id": current_node_id,
		"option_id": option_id,
	}
	action_executor.execute_actions(selected_option.get("actions", []), self, action_context)

	if is_dialogue_active() and dialogue_ui != null and dialogue_ui.has_method("set_option_commit_locked"):
		dialogue_ui.set_option_commit_locked(false)
		option_commit_locked = false


func end_dialogue(reason: String = "completed") -> void:
	var closed_dialogue_id: String = current_dialogue_id

	if dialogue_ui != null and dialogue_ui.has_method("close_dialogue"):
		dialogue_ui.close_dialogue()

	_end_dialogue_context(reason)

	current_dialogue_id = ""
	current_node_id = ""
	current_dialogue_data.clear()
	current_source = null
	current_source_context.clear()
	current_view_model.clear()
	current_options.clear()
	option_commit_locked = false
	dialogue_flags.clear()
	active_context_token = ""

	if closed_dialogue_id != "":
		emit_signal("dialogue_closed", closed_dialogue_id, reason)


func _process(_delta: float) -> void:
	if not is_dialogue_active():
		return
	if current_source != null and not is_instance_valid(current_source):
		end_dialogue("npc_invalidated")
		return
	if player != null and player.has_method("is_alive") and not player.is_alive():
		end_dialogue("player_unavailable")
		return
	if scene_adapter == null or not is_instance_valid(scene_adapter):
		end_dialogue("scene_adapter_invalidated")
		return


func _build_view_model(node_data: Dictionary) -> Dictionary:
	var view_model := {
		"dialogue_id": current_dialogue_id,
		"node_id": current_node_id,
		"speaker_name": str(node_data.get("speaker_name", "")),
		"text_rows": _build_text_rows(node_data),
		"options": _build_visible_options(node_data),
	}

	if (view_model["options"] as Array).is_empty() and not bool(node_data.get("auto_end_when_no_options", false)):
		view_model["options"] = [
			{
				"id": "__leave__",
				"text": "离开",
				"actions": [{"type": "end_dialogue", "reason": "default_leave"}],
			},
		]

	return view_model


func _build_text_rows(node_data: Dictionary) -> Array:
	var rows: Array = []
	var base_text: String = str(node_data.get("base_text", ""))
	if base_text != "":
		rows.append([{"text": base_text}])

	for raw_segment in node_data.get("conditional_text_segments", []):
		if typeof(raw_segment) != TYPE_DICTIONARY:
			_warn("conditional_segment_invalid", {
				"dialogue_id": current_dialogue_id,
				"node_id": current_node_id,
			})
			continue

		var segment: Dictionary = raw_segment
		var log_context := {
			"dialogue_id": current_dialogue_id,
			"node_id": current_node_id,
		}
		if not condition_evaluator.are_conditions_met(segment.get("conditions", []), _build_condition_context(), log_context, segment):
			continue

		if segment.has("fragments"):
			rows.append(_normalize_text_fragments(segment.get("fragments", [])))
		else:
			rows.append([{"text": str(segment.get("text", ""))}])

	return rows


func _build_visible_options(node_data: Dictionary) -> Array:
	var visible_options: Array = []

	for raw_option in node_data.get("options", []):
		if typeof(raw_option) != TYPE_DICTIONARY:
			_warn("option_entry_invalid", {
				"dialogue_id": current_dialogue_id,
				"node_id": current_node_id,
			})
			continue

		var option: Dictionary = (raw_option as Dictionary).duplicate(true)
		var log_context := {
			"dialogue_id": current_dialogue_id,
			"node_id": current_node_id,
			"option_id": str(option.get("id", "")),
		}
		if not condition_evaluator.are_conditions_met(option.get("conditions", []), _build_condition_context(), log_context, option):
			continue
		visible_options.append(option)

	return visible_options


func _normalize_text_fragments(raw_fragments: Array) -> Array:
	var normalized: Array = []
	for raw_fragment in raw_fragments:
		if typeof(raw_fragment) == TYPE_DICTIONARY:
			var fragment: Dictionary = (raw_fragment as Dictionary).duplicate(true)
			var trigger_id := str(fragment.get("trigger_id", ""))
			if trigger_id != "":
				var trigger_tooltip: Dictionary = trigger_evaluator.build_hover_detail(
					trigger_id,
					_build_condition_context(),
					fragment.get("tooltip_data", {})
				)
				if not trigger_tooltip.is_empty():
					fragment["tooltip_data"] = trigger_tooltip
			normalized.append(fragment)
		else:
			normalized.append({"text": str(raw_fragment)})
	return normalized


func _build_condition_context() -> Dictionary:
	return {
		"player": player,
		"game_state": game_state,
		"dialogue_manager": self,
		"scene_adapter": scene_adapter,
		"source_node": current_source,
		"source_context": current_source_context.duplicate(true),
	}


func _ensure_dialogue_ui() -> bool:
	if dialogue_ui_parent == null or not is_instance_valid(dialogue_ui_parent):
		return false
	if dialogue_ui == null or not is_instance_valid(dialogue_ui):
		dialogue_ui = DialogueUIScene.instantiate()
		dialogue_ui.name = "DialogueUI"
		dialogue_ui_parent.add_child(dialogue_ui)
	elif dialogue_ui.get_parent() != dialogue_ui_parent:
		var old_parent: Node = dialogue_ui.get_parent()
		if old_parent != null:
			old_parent.remove_child(dialogue_ui)
		dialogue_ui_parent.add_child(dialogue_ui)

	if dialogue_ui.has_method("configure"):
		dialogue_ui.configure(self, hover_detail_manager)
	return true


func _begin_dialogue_context(dialogue_id: String, source: Node) -> bool:
	if scene_adapter == null or not is_instance_valid(scene_adapter):
		return false
	context_token_serial += 1
	active_context_token = "dialogue_%d" % context_token_serial
	if scene_adapter.has_method("begin_dialogue_context"):
		return bool(scene_adapter.begin_dialogue_context(dialogue_ui, {
			"dialogue_id": dialogue_id,
			"source_node": source,
			"context_token": active_context_token,
		}))
	return true


func _end_dialogue_context(reason: String) -> void:
	if scene_adapter == null or not is_instance_valid(scene_adapter):
		return
	if scene_adapter.has_method("end_dialogue_context"):
		scene_adapter.end_dialogue_context(dialogue_ui, {
			"reason": reason,
			"context_token": active_context_token,
		})


func _warn(code: String, context: Dictionary) -> void:
	push_warning("DialogueManager[%s] %s" % [code, str(context)])
