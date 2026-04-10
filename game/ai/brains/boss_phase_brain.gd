extends "res://game/ai/brains/melee_brain.gd"


func decide(perception: Dictionary, delta: float) -> Dictionary:
	var blackboard = _blackboard()
	if blackboard != null:
		var ai_id: String = _current_ai_id()
		if ai_id.contains("phase2"):
			blackboard.phase_tag = "phase_two"
		else:
			blackboard.phase_tag = "phase_one"

	return super.decide(perception, delta)
