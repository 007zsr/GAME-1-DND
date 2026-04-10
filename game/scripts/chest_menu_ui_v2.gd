extends PanelContainer

const ItemSystem = preload("res://game/scripts/item_system.gd")
const ItemSlotScript = preload("res://game/scripts/item_slot.gd")
const ItemContextMenuScript = preload("res://game/scripts/item_context_menu.gd")
const SplitStackDialogScript = preload("res://game/scripts/split_stack_dialog.gd")

const CHEST_COLUMNS := 5
const BAG_COLUMNS := 3
const CHEST_SLOT_SIZE := Vector2(72.0, 72.0)
const BAG_SLOT_SIZE := Vector2(76.0, 76.0)

var player: Node
var village: Node
var current_chest: Node
var chest_slot_nodes: Array[Control] = []
var bag_slot_nodes: Array[Control] = []
var selected_slot_kind := ""
var selected_slot_key: Variant = null
var hovered_slot_kind := ""
var hovered_slot_key: Variant = null

var chest_grid: GridContainer
var bag_grid: GridContainer
var status_label: Label
var take_all_button: Button
var hover_detail_manager: Control
var item_context_menu
var split_stack_dialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(960.0, 560.0)
	_build_ui()


func configure(player_node: Node, village_node: Node) -> void:
	player = player_node
	village = village_node
	if village != null and village.has_method("get_hover_detail_manager"):
		hover_detail_manager = village.get_hover_detail_manager()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse_position := get_viewport().get_mouse_position()
		if split_stack_dialog != null and split_stack_dialog.visible and not split_stack_dialog.contains_global_point(mouse_position):
			split_stack_dialog.hide_dialog()
		if item_context_menu != null and item_context_menu.visible and not item_context_menu.contains_global_point(mouse_position):
			item_context_menu.hide_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not visible:
		return
	if event is InputEventKey and event.pressed and (event.keycode == KEY_E or event.keycode == KEY_ESCAPE):
		if _close_top_popup():
			get_viewport().set_input_as_handled()
			return
		close_menu()
		get_viewport().set_input_as_handled()


func open_for_chest(chest_node: Node) -> void:
	current_chest = chest_node
	if current_chest != null and current_chest.has_method("mark_opened"):
		current_chest.mark_opened()
	visible = true
	_refresh_all()


func close_menu() -> void:
	visible = false
	current_chest = null
	_close_transient_popups()
	_hide_hover_detail()
	if village != null and village.has_method("close_overlay"):
		village.close_overlay(self)


func _close_top_popup() -> bool:
	if split_stack_dialog != null and split_stack_dialog.visible:
		split_stack_dialog.hide_dialog()
		return true
	if item_context_menu != null and item_context_menu.visible:
		item_context_menu.hide_menu()
		return true
	return false


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = "宝箱"
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)
	title.text = "宝箱"

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	root.add_child(content)

	var chest_panel := PanelContainer.new()
	chest_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chest_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(chest_panel)

	var chest_margin := MarginContainer.new()
	chest_margin.add_theme_constant_override("margin_left", 12)
	chest_margin.add_theme_constant_override("margin_top", 12)
	chest_margin.add_theme_constant_override("margin_right", 12)
	chest_margin.add_theme_constant_override("margin_bottom", 12)
	chest_panel.add_child(chest_margin)

	var chest_stack := VBoxContainer.new()
	chest_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chest_stack.add_theme_constant_override("separation", 8)
	chest_margin.add_child(chest_stack)

	var chest_title := Label.new()
	chest_title.text = "宝箱 10 格"
	chest_title.add_theme_font_size_override("font_size", 20)
	chest_stack.add_child(chest_title)
	chest_title.text = "宝箱内容"

	take_all_button = Button.new()
	take_all_button.text = "拿取全部"
	take_all_button.pressed.connect(_on_take_all_button_pressed)
	chest_stack.add_child(take_all_button)

	status_label = Label.new()
	chest_stack.add_child(status_label)

	var chest_scroll := ScrollContainer.new()
	chest_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chest_stack.add_child(chest_scroll)

	chest_grid = GridContainer.new()
	chest_grid.columns = CHEST_COLUMNS
	chest_grid.add_theme_constant_override("h_separation", 10)
	chest_grid.add_theme_constant_override("v_separation", 10)
	chest_scroll.add_child(chest_grid)

	var bag_panel := PanelContainer.new()
	bag_panel.custom_minimum_size = Vector2(360.0, 0.0)
	bag_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(bag_panel)

	var bag_margin := MarginContainer.new()
	bag_margin.add_theme_constant_override("margin_left", 12)
	bag_margin.add_theme_constant_override("margin_top", 12)
	bag_margin.add_theme_constant_override("margin_right", 12)
	bag_margin.add_theme_constant_override("margin_bottom", 12)
	bag_panel.add_child(bag_margin)

	var bag_stack := VBoxContainer.new()
	bag_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_stack.add_theme_constant_override("separation", 8)
	bag_margin.add_child(bag_stack)

	var bag_title := Label.new()
	bag_title.text = "玩家背包"
	bag_title.add_theme_font_size_override("font_size", 20)
	bag_stack.add_child(bag_title)
	bag_title.text = "玩家背包"

	var bag_tip := Label.new()
	bag_tip.text = "显示全部背包物品。支持拖动整理和堆叠拆分。"
	bag_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bag_stack.add_child(bag_tip)
	bag_tip.text = "双击可快速转移，右键可查看更多操作。"

	var bag_scroll := ScrollContainer.new()
	bag_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_stack.add_child(bag_scroll)

	bag_grid = GridContainer.new()
	bag_grid.columns = BAG_COLUMNS
	bag_grid.add_theme_constant_override("h_separation", 10)
	bag_grid.add_theme_constant_override("v_separation", 10)
	bag_scroll.add_child(bag_grid)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	root.add_child(action_row)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(close_menu)
	action_row.add_child(close_button)

	item_context_menu = PanelContainer.new()
	item_context_menu.set_script(ItemContextMenuScript)
	item_context_menu.connect("action_selected", Callable(self, "_on_item_context_action_selected"))
	add_child(item_context_menu)

	split_stack_dialog = PanelContainer.new()
	split_stack_dialog.set_script(SplitStackDialogScript)
	split_stack_dialog.connect("split_confirmed", Callable(self, "_on_split_stack_confirmed"))
	add_child(split_stack_dialog)

func select_slot(slot_kind: String, slot_key: Variant) -> void:
	_close_transient_popups()
	selected_slot_kind = slot_kind
	selected_slot_key = slot_key


func hover_slot(slot_kind: String, slot_key: Variant) -> void:
	hovered_slot_kind = slot_kind
	hovered_slot_key = slot_key
	_request_slot_hover_detail(slot_kind, slot_key)


func unhover_slot(slot_kind: String, slot_key: Variant) -> void:
	if hovered_slot_kind == slot_kind and hovered_slot_key == slot_key:
		hovered_slot_kind = ""
		hovered_slot_key = null
	_hide_hover_detail()


func notify_item_drag_started() -> void:
	_close_transient_popups()
	_hide_hover_detail()


func handle_slot_double_click(slot_kind: String, slot_key: Variant) -> void:
	var action: String = _resolve_double_click_action(slot_kind, slot_key)
	match action:
		"move_to_inventory":
			if not _try_quick_transfer("chest", int(slot_key), "inventory"):
				_show_transfer_feedback("背包空间不足")
		"move_to_chest":
			if not _try_quick_transfer("inventory", int(slot_key), "chest"):
				_show_transfer_feedback("宝箱空间不足")


func handle_slot_right_click(slot_kind: String, slot_key: Variant, mouse_position: Vector2, anchor_rect: Rect2 = Rect2()) -> void:
	if current_chest == null or player == null:
		return
	var item_stack: Dictionary = _get_slot_stack(slot_kind, slot_key)
	var definition: Dictionary = player.get_item_stack_definition(item_stack)
	if item_stack.is_empty() or definition.is_empty():
		_close_transient_popups()
		return

	var actions := _build_item_context_actions(slot_kind, slot_key, item_stack, definition)
	if actions.is_empty():
		_close_transient_popups()
		return

	_close_transient_popups()
	_hide_hover_detail()
	item_context_menu.show_actions(str(definition.get("name", "")), actions, mouse_position, anchor_rect)


func _resolve_double_click_action(slot_kind: String, slot_key: Variant) -> String:
	if current_chest == null or player == null:
		return "none"

	var item_stack: Dictionary = _get_slot_stack(slot_kind, slot_key)
	if item_stack.is_empty():
		return "none"

	if slot_kind == "chest":
		return "move_to_inventory"
	if slot_kind == "inventory":
		return "move_to_chest"
	return "none"


func can_drop_on_slot(slot_kind: String, slot_key: Variant, data: Variant) -> bool:
	if current_chest == null or player == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var source_kind: String = str(data.get("slot_kind", ""))
	var source_key: Variant = data.get("slot_key")

	match slot_kind:
		"chest":
			return (source_kind == "chest" and int(source_key) != int(slot_key)) or source_kind == "inventory"
		"inventory":
			return (source_kind == "inventory" and int(source_key) != int(slot_key)) or source_kind == "chest"
	return false


func handle_drop_on_slot(slot_kind: String, slot_key: Variant, data: Variant) -> void:
	if not can_drop_on_slot(slot_kind, slot_key, data):
		return

	var source_kind: String = str(data.get("slot_kind", ""))
	var source_key: Variant = data.get("slot_key")
	var source_stack := ItemSystem.normalize_item_stack(_get_slot_stack(source_kind, source_key))
	var target_stack := ItemSystem.normalize_item_stack(_get_slot_stack(slot_kind, slot_key))

	if ItemSystem.can_merge_stacks(target_stack, source_stack):
		var merge_result := ItemSystem.merge_stacks(target_stack, source_stack)
		_set_slot_stack(slot_kind, int(slot_key), merge_result.get("target_stack", {}))
		_set_slot_stack(source_kind, int(source_key), merge_result.get("source_stack", {}))
		_refresh_all()
		return

	if slot_kind == "chest":
		current_chest.replace_stack(int(slot_key), source_stack)
	else:
		player.replace_inventory_stack(int(slot_key), source_stack)

	if source_kind == "chest":
		current_chest.replace_stack(int(source_key), target_stack)
	else:
		player.replace_inventory_stack(int(source_key), target_stack)

	_refresh_all()


func _try_quick_transfer(source_kind: String, source_index: int, target_kind: String) -> bool:
	var source_stack := ItemSystem.normalize_item_stack(_get_slot_stack(source_kind, source_index))
	if source_stack.is_empty():
		return false

	var target_index: int = _find_receive_target_index(target_kind, source_stack)
	if target_index == -1:
		return false

	var target_stack := ItemSystem.normalize_item_stack(_get_slot_stack(target_kind, target_index))
	if target_stack.is_empty():
		_set_slot_stack(target_kind, target_index, source_stack)
		_set_slot_stack(source_kind, source_index, {})
		_refresh_all()
		return true

	if not ItemSystem.can_merge_stacks(target_stack, source_stack):
		return false

	var merge_result := ItemSystem.merge_stacks(target_stack, source_stack)
	_set_slot_stack(target_kind, target_index, merge_result.get("target_stack", {}))
	_set_slot_stack(source_kind, source_index, merge_result.get("source_stack", {}))
	_refresh_all()
	return true


func _find_receive_target_index(target_kind: String, item_stack: Dictionary) -> int:
	if target_kind == "inventory":
		return player.find_inventory_receive_target_index(item_stack)
	if target_kind == "chest" and current_chest != null and current_chest.has_method("find_receive_target_index"):
		return current_chest.find_receive_target_index(item_stack)
	return -1


func _set_slot_stack(slot_kind: String, slot_key: int, item_stack: Dictionary) -> bool:
	if slot_kind == "inventory":
		return player.replace_inventory_stack(slot_key, ItemSystem.normalize_item_stack(item_stack))
	if slot_kind == "chest":
		return current_chest.replace_stack(slot_key, ItemSystem.normalize_item_stack(item_stack))
	return false


func _build_item_context_actions(slot_kind: String, slot_key: Variant, item_stack: Dictionary, definition: Dictionary) -> Array:
	var actions: Array = []
	if slot_kind == "chest":
		actions.append({
			"id": "move_to_inventory",
			"label": "取到背包",
			"slot_kind": slot_kind,
			"slot_key": slot_key,
		})
	elif slot_kind == "inventory":
		actions.append({
			"id": "move_to_chest",
			"label": "放入宝箱",
			"slot_kind": slot_kind,
			"slot_key": slot_key,
		})
		if bool(definition.get("can_split", false)) and int(item_stack.get("count", 1)) > 1:
			actions.append({
				"id": "split",
				"label": "拆分",
				"slot_kind": slot_kind,
				"slot_key": slot_key,
			})
	for action in actions:
		var action_id := str((action as Dictionary).get("id", ""))
		match action_id:
			"move_to_inventory":
				action["label"] = "取到背包"
			"move_to_chest":
				action["label"] = "放入宝箱"
			"split":
				action["label"] = "拆分"
	return actions


func _on_item_context_action_selected(action_id: String, action_context: Dictionary) -> void:
	match action_id:
		"move_to_inventory":
			if not _try_quick_transfer("chest", int(action_context.get("slot_key", -1)), "inventory"):
				_show_transfer_feedback("背包空间不足")
		"move_to_chest":
			if not _try_quick_transfer("inventory", int(action_context.get("slot_key", -1)), "chest"):
				_show_transfer_feedback("宝箱空间不足")
		"split":
			_open_split_dialog_for_inventory(int(action_context.get("slot_key", -1)))


func _open_split_dialog_for_inventory(index: int) -> void:
	var item_stack: Dictionary = player.get_inventory_stack(index)
	var definition: Dictionary = player.get_item_stack_definition(item_stack)
	if item_stack.is_empty() or definition.is_empty():
		return
	if not bool(definition.get("can_split", false)) or int(item_stack.get("count", 1)) <= 1:
		return

	var total_count: int = int(item_stack.get("count", 1))
	var default_split: int = max(total_count / 2, 1)
	_close_transient_popups()
	_hide_hover_detail()
	split_stack_dialog.popup_for_stack(
		str(definition.get("name", "")),
		total_count,
		default_split,
		{"slot_kind": "inventory", "slot_key": index},
		get_viewport().get_mouse_position()
	)


func _on_split_stack_confirmed(split_count: int, split_context: Dictionary) -> void:
	if str(split_context.get("slot_kind", "")) != "inventory":
		return
	if not player.split_inventory_stack_by_count(int(split_context.get("slot_key", -1)), split_count):
		_show_transfer_feedback("背包空间不足")
		return
	_refresh_all()


func _on_take_all_button_pressed() -> void:
	if current_chest == null or player == null:
		return
	if split_stack_dialog != null and split_stack_dialog.visible:
		_show_transfer_feedback("请先完成拆分操作。")
		return

	if item_context_menu != null and item_context_menu.visible:
		item_context_menu.hide_menu()
	_hide_hover_detail()

	var moved_count := 0
	var has_blocked_items := false
	var slot_count: int = current_chest.get_slots().size()

	for slot_index in range(slot_count):
		while true:
			var before_stack := ItemSystem.normalize_item_stack(current_chest.get_stack(slot_index))
			if before_stack.is_empty():
				break

			var before_count: int = int(before_stack.get("count", 1))
			if not _try_quick_transfer("chest", slot_index, "inventory"):
				has_blocked_items = true
				break

			var after_stack := ItemSystem.normalize_item_stack(current_chest.get_stack(slot_index))
			var after_count: int = int(after_stack.get("count", 0))
			moved_count += max(before_count - after_count, 0)

			if after_stack.is_empty():
				break
			if after_count >= before_count:
				has_blocked_items = true
				break

	_refresh_all()

	if moved_count <= 0:
		_show_transfer_feedback("背包空间不足，未能拿取物品。")
		return

	if has_blocked_items or _count_remaining_chest_stacks() > 0:
		_show_transfer_feedback("已拿取 %d 件物品，背包空间不足，部分物品仍留在宝箱。" % moved_count)
		return

	_show_transfer_feedback("已拿取全部 %d 件物品。" % moved_count)


func _close_transient_popups() -> void:
	if item_context_menu != null and item_context_menu.visible:
		item_context_menu.hide_menu()
	if split_stack_dialog != null and split_stack_dialog.visible:
		split_stack_dialog.hide_dialog()


func _show_transfer_feedback(text: String) -> void:
	status_label.text = text


func _refresh_all() -> void:
	if current_chest == null or player == null:
		return

	var chest_slots: Array = current_chest.get_slots()
	var inventory_slots: Array = player.get_inventory_slots()
	var visible_inventory_slots: int = max(player.get_inventory_capacity(), inventory_slots.size(), 1)

	_ensure_chest_slot_pool(chest_slots.size())
	_ensure_bag_slot_pool(visible_inventory_slots)

	for index in range(chest_slot_nodes.size()):
		var item_stack: Dictionary = chest_slots[index] if index < chest_slots.size() else {}
		chest_slot_nodes[index].visible = index < chest_slots.size()
		if index < chest_slots.size():
			chest_slot_nodes[index].set_item_view(item_stack, player.get_item_stack_definition(item_stack))

	for index in range(bag_slot_nodes.size()):
		var item_stack: Dictionary = inventory_slots[index] if index < inventory_slots.size() else {}
		bag_slot_nodes[index].visible = index < visible_inventory_slots
		if index < visible_inventory_slots:
			bag_slot_nodes[index].set_item_view(item_stack, player.get_item_stack_definition(item_stack))

	take_all_button.disabled = current_chest.is_empty()
	status_label.text = current_chest.get_prompt_text()


func _ensure_chest_slot_pool(target_count: int) -> void:
	while chest_slot_nodes.size() < target_count:
		var slot_index := chest_slot_nodes.size()
		var slot_control := PanelContainer.new()
		slot_control.set_script(ItemSlotScript)
		slot_control.setup(self, "chest", slot_index, "", "", CHEST_SLOT_SIZE)
		chest_slot_nodes.append(slot_control)
		chest_grid.add_child(slot_control)


func _ensure_bag_slot_pool(target_count: int) -> void:
	while bag_slot_nodes.size() < target_count:
		var slot_index := bag_slot_nodes.size()
		var slot_control := PanelContainer.new()
		slot_control.set_script(ItemSlotScript)
		slot_control.setup(self, "inventory", slot_index, "", "", BAG_SLOT_SIZE)
		bag_slot_nodes.append(slot_control)
		bag_grid.add_child(slot_control)


func _get_slot_stack(slot_kind: String, slot_key: Variant) -> Dictionary:
	if slot_kind == "chest":
		return current_chest.get_stack(int(slot_key))
	if slot_kind == "inventory":
		return player.get_inventory_stack(int(slot_key))
	return {}


func _request_slot_hover_detail(slot_kind: String, slot_key: Variant) -> void:
	if hover_detail_manager == null or player == null:
		return
	if (item_context_menu != null and item_context_menu.visible) or (split_stack_dialog != null and split_stack_dialog.visible):
		return
	var item_stack: Dictionary = _get_slot_stack(slot_kind, slot_key)
	var item_definition: Dictionary = player.get_item_stack_definition(item_stack)
	if item_stack.is_empty() or item_definition.is_empty():
		return

	var anchor_control := _get_slot_anchor_control(slot_kind, slot_key)
	if anchor_control == null:
		return

	var source_id := "chest_menu:%s:%s" % [slot_kind, str(slot_key)]
	hover_detail_manager.request_hover("item_entry", source_id, anchor_control, Callable(self, "_build_item_slot_hover_context").bind(slot_kind, slot_key), "target")


func _hide_hover_detail() -> void:
	if hover_detail_manager != null:
		hover_detail_manager.hide_immediately()


func _build_item_slot_hover_context(slot_kind: String, slot_key: Variant) -> Dictionary:
	if player == null:
		return {}
	var item_stack: Dictionary = _get_slot_stack(slot_kind, slot_key)
	var item_definition: Dictionary = player.get_item_stack_definition(item_stack)
	if item_stack.is_empty() or item_definition.is_empty():
		return {}
	return {
		"item_stack": item_stack,
		"item_definition": item_definition,
		"is_equipped": false,
		"source_context": "宝箱页",
	}


func _get_slot_anchor_control(slot_kind: String, slot_key: Variant) -> Control:
	if slot_kind == "chest":
		if int(slot_key) >= 0 and int(slot_key) < chest_slot_nodes.size():
			return chest_slot_nodes[int(slot_key)]
	elif slot_kind == "inventory":
		if int(slot_key) >= 0 and int(slot_key) < bag_slot_nodes.size():
			return bag_slot_nodes[int(slot_key)]
	return null


func _count_remaining_chest_stacks() -> int:
	if current_chest == null:
		return 0

	var remaining := 0
	for item_stack in current_chest.get_slots():
		if not ItemSystem.normalize_item_stack(item_stack as Dictionary).is_empty():
			remaining += 1
	return remaining


func _on_split_button_pressed() -> void:
	if selected_slot_kind != "inventory":
		return
	_open_split_dialog_for_inventory(int(selected_slot_key))
