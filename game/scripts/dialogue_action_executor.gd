extends RefCounted
class_name DialogueActionExecutor


func execute_actions(actions: Array, manager: Node, context: Dictionary) -> void:
	if manager == null:
		return

	for raw_action in actions:
		if typeof(raw_action) != TYPE_DICTIONARY:
			_warn("action_entry_invalid", context, {"raw_action": raw_action})
			continue

		var action: Dictionary = raw_action
		var action_type: String = str(action.get("type", ""))
		match action_type:
			"goto_node":
				var next_node_id: String = str(action.get("node_id", ""))
				if next_node_id == "":
					_warn("goto_node_missing_node_id", context, action)
					manager.end_dialogue("missing_next_node")
					return
				manager.go_to_node(next_node_id)
				return
			"end_dialogue":
				manager.close_dialogue(str(action.get("reason", "completed")))
				return
			"set_flag":
				var flag_id: String = str(action.get("flag_id", ""))
				if flag_id == "":
					_warn("set_flag_missing_flag_id", context, action)
					continue
				manager.set_dialogue_flag(flag_id, bool(action.get("value", true)))
			"set_event_flag":
				var event_flag_id: String = str(action.get("flag_id", ""))
				if event_flag_id == "":
					_warn("set_event_flag_missing_flag_id", context, action)
					continue
				if manager.has_method("set_event_flag"):
					manager.set_event_flag(event_flag_id, bool(action.get("value", true)))
			"grant_trigger":
				var trigger_id := str(action.get("trigger_id", ""))
				if trigger_id == "":
					_warn("grant_trigger_missing_trigger_id", context, action)
					continue
				if manager.has_method("grant_trigger"):
					manager.grant_trigger(trigger_id)
			"open_shop":
				manager.execute_scene_action("open_shop", action, true)
				return
			"open_training":
				manager.execute_scene_action("open_training", action, true)
				return
			"start_hostile", "start_battle":
				manager.execute_scene_action("start_hostile", action, true)
				return
			"call_hook":
				manager.execute_scene_action("call_hook", action, true)
				return
			_:
				_warn("unknown_action_type", context, action)


func _warn(code: String, context: Dictionary, extra: Variant = null) -> void:
	push_warning(
		"DialogueActionExecutor[%s] dialogue_id=%s node_id=%s option_id=%s extra=%s" % [
			code,
			str(context.get("dialogue_id", "")),
			str(context.get("node_id", "")),
			str(context.get("option_id", "")),
			str(extra),
		]
	)
