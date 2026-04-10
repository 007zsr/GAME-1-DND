extends "res://game/ai/brains/ai_brain_base.gd"


func decide(_perception: Dictionary, _delta: float) -> Dictionary:
	var blackboard = _blackboard()
	if blackboard != null:
		blackboard.clear_target_state()
	return _idle_command()
