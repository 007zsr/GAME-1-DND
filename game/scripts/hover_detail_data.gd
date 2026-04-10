extends RefCounted
class_name HoverDetailData

var title: String = ""
var summary_lines: Array[String] = []
var detail_lines: Array[String] = []
var icon: Texture2D
var style_id: String = "default"
var source_type: String = ""
var source_id: String = ""
var context_flags: Dictionary = {}
var supports_shift: bool = false


func to_dictionary() -> Dictionary:
	return {
		"title": title,
		"summary_lines": summary_lines.duplicate(),
		"detail_lines": detail_lines.duplicate(),
		"icon": icon,
		"style_id": style_id,
		"source_type": source_type,
		"source_id": source_id,
		"context_flags": context_flags.duplicate(true),
		"supports_shift": supports_shift,
	}
