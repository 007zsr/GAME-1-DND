extends PanelContainer

const CharacterStats = preload("res://game/scripts/character_stats.gd")
const ItemSystem = preload("res://game/scripts/item_system.gd")
const ItemSlotScript = preload("res://game/scripts/item_slot.gd")
const ItemContextMenuScript = preload("res://game/scripts/item_context_menu.gd")
const SplitStackDialogScript = preload("res://game/scripts/split_stack_dialog.gd")
const DragCardScript = preload("res://game/scripts/drag_card.gd")

const SIMPLE_SLOT_SIZE := Vector2(76.0, 76.0)
const FULL_SLOT_SIZE := Vector2(80.0, 80.0)
const INVENTORY_COLUMNS := 3
const SKILL_MAX_VISIBLE_SLOTS := 6

var player: Node
var village: Node
var current_tab := "quest"
var selected_slot_kind := ""
var selected_slot_key: Variant = null
var hovered_slot_kind := ""
var hovered_slot_key: Variant = null
var pending_drop_index := -1

var page_nodes: Dictionary = {}
var tab_buttons: Dictionary = {}
var equipment_slot_nodes: Dictionary = {}
var equipment_bag_slot_nodes: Array[Control] = []
var full_bag_slot_nodes: Array[Control] = []
var a_stat_labels: Dictionary = {}
var b_stat_labels: Dictionary = {}
var b_stat_row_nodes: Dictionary = {}
var skill_page_owned_list: VBoxContainer
var skill_page_slot_list: VBoxContainer
var skill_page_pool_grid: GridContainer
var skill_page_slot_grid: GridContainer
var skill_page_status_label: Label

var detail_name_label: Label
var detail_type_label: Label
var detail_rarity_label: Label
var detail_count_label: Label
var detail_bonus_label: RichTextLabel
var detail_description_label: RichTextLabel
var equipment_bag_status_label: Label
var bag_status_label: Label
var interaction_feedback_label: Label
var drop_confirm_dialog: ConfirmationDialog
var hover_detail_manager: Control
var item_context_menu
var split_stack_dialog

var equipment_bag_grid: GridContainer
var full_bag_grid: GridContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 70.0
	offset_top = 50.0
	offset_right = -70.0
	offset_bottom = -50.0
	_build_ui()


func configure(player_node: Node, village_node: Node) -> void:
	player = player_node
	village = village_node
	if village != null and village.has_method("get_hover_detail_manager"):
		hover_detail_manager = village.get_hover_detail_manager()
	if player != null and player.has_signal("runtime_values_recalculated") and not player.is_connected("runtime_values_recalculated", Callable(self, "_refresh_all")):
		player.connect("runtime_values_recalculated", Callable(self, "_refresh_all"))
	_refresh_all()


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
	if event.is_echo():
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and visible:
			if _close_top_popup():
				get_viewport().set_input_as_handled()
				return
			_close_menu()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_I:
			if visible:
				_close_menu()
			else:
				if village != null and village.has_method("request_open_overlay") and not village.request_open_overlay(self):
					return
				_open_menu()
			get_viewport().set_input_as_handled()


func _open_menu() -> void:
	if player == null:
		return
	visible = true
	_clear_feedback()
	_refresh_all()


func _close_menu() -> void:
	visible = false
	pending_drop_index = -1
	_close_transient_popups()
	if drop_confirm_dialog != null and drop_confirm_dialog.visible:
		drop_confirm_dialog.hide()
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
	if drop_confirm_dialog != null and drop_confirm_dialog.visible:
		drop_confirm_dialog.hide()
		pending_drop_index = -1
		return true
	return false


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = "统合界面"
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)

	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	root.add_child(tab_bar)

	for tab_info in [
		{"id": "quest", "label": "任务"},
		{"id": "skills", "label": "技能"},
		{"id": "equipment", "label": "装备"},
		{"id": "bag", "label": "背包"},
	]:
		var button := Button.new()
		button.text = str(tab_info["label"])
		button.custom_minimum_size = Vector2(96.0, 40.0)
		button.pressed.connect(_on_tab_button_pressed.bind(String(tab_info["id"])))
		tab_buttons[String(tab_info["id"])] = button
		tab_bar.add_child(button)

	var content_holder := Control.new()
	content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content_holder)

	interaction_feedback_label = Label.new()
	interaction_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interaction_feedback_label.modulate = Color(0.96, 0.84, 0.60, 1.0)
	root.add_child(interaction_feedback_label)

	page_nodes["quest"] = _build_quest_page()
	page_nodes["skills"] = _build_skill_page_v2()
	page_nodes["equipment"] = _build_equipment_page()
	page_nodes["bag"] = _build_bag_page()

	for page_key in page_nodes.keys():
		content_holder.add_child(page_nodes[page_key])

	drop_confirm_dialog = ConfirmationDialog.new()
	drop_confirm_dialog.dialog_text = "确认要丢弃这件物品吗？"
	drop_confirm_dialog.confirmed.connect(_on_drop_confirmed)
	add_child(drop_confirm_dialog)

	item_context_menu = PanelContainer.new()
	item_context_menu.set_script(ItemContextMenuScript)
	item_context_menu.connect("action_selected", Callable(self, "_on_item_context_action_selected"))
	add_child(item_context_menu)

	split_stack_dialog = PanelContainer.new()
	split_stack_dialog.set_script(SplitStackDialogScript)
	split_stack_dialog.connect("split_confirmed", Callable(self, "_on_split_stack_confirmed"))
	add_child(split_stack_dialog)

	_show_tab("quest")


func _build_quest_page() -> Control:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "任务"
	title.add_theme_font_size_override("font_size", 22)
	page.add_child(title)

	var description := Label.new()
	description.text = "当前没有任务"
	page.add_child(description)
	return page


func _build_skill_page() -> Control:
	var page := HBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 16)

	var owned_panel := PanelContainer.new()
	owned_panel.custom_minimum_size = Vector2(430.0, 0.0)
	owned_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(owned_panel)

	var owned_margin := MarginContainer.new()
	owned_margin.add_theme_constant_override("margin_left", 14)
	owned_margin.add_theme_constant_override("margin_top", 14)
	owned_margin.add_theme_constant_override("margin_right", 14)
	owned_margin.add_theme_constant_override("margin_bottom", 14)
	owned_panel.add_child(owned_margin)

	var owned_stack := VBoxContainer.new()
	owned_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	owned_stack.add_theme_constant_override("separation", 10)
	owned_margin.add_child(owned_stack)

	var owned_title := Label.new()
	owned_title.text = "已拥有技能"
	owned_title.add_theme_font_size_override("font_size", 22)
	owned_stack.add_child(owned_title)

	var owned_tip := Label.new()
	owned_tip.text = "双击技能可装入第一个空槽，技能说明仍走统一 Tooltip。"
	owned_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owned_stack.add_child(owned_tip)

	var owned_scroll := ScrollContainer.new()
	owned_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	owned_stack.add_child(owned_scroll)

	skill_page_owned_list = VBoxContainer.new()
	skill_page_owned_list.add_theme_constant_override("separation", 8)
	owned_scroll.add_child(skill_page_owned_list)

	var slot_panel := PanelContainer.new()
	slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(slot_panel)

	var slot_margin := MarginContainer.new()
	slot_margin.add_theme_constant_override("margin_left", 14)
	slot_margin.add_theme_constant_override("margin_top", 14)
	slot_margin.add_theme_constant_override("margin_right", 14)
	slot_margin.add_theme_constant_override("margin_bottom", 14)
	slot_panel.add_child(slot_margin)

	var slot_stack := VBoxContainer.new()
	slot_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_stack.add_theme_constant_override("separation", 10)
	slot_margin.add_child(slot_stack)

	var slot_title := Label.new()
	slot_title.text = "当前技能栏"
	slot_title.add_theme_font_size_override("font_size", 22)
	slot_stack.add_child(slot_title)

	skill_page_status_label = Label.new()
	skill_page_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_stack.add_child(skill_page_status_label)

	skill_page_slot_list = VBoxContainer.new()
	skill_page_slot_list.add_theme_constant_override("separation", 8)
	slot_stack.add_child(skill_page_slot_list)

	return page


func _build_equipment_page() -> Control:
	var page := HBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 18)

	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(470.0, 0.0)
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 16)
	page.add_child(left_column)

	var equip_panel := PanelContainer.new()
	equip_panel.custom_minimum_size = Vector2(450.0, 250.0)
	left_column.add_child(equip_panel)

	var equip_margin := MarginContainer.new()
	equip_margin.add_theme_constant_override("margin_left", 14)
	equip_margin.add_theme_constant_override("margin_top", 14)
	equip_margin.add_theme_constant_override("margin_right", 14)
	equip_margin.add_theme_constant_override("margin_bottom", 14)
	equip_panel.add_child(equip_margin)

	var equip_stack := VBoxContainer.new()
	equip_stack.add_theme_constant_override("separation", 10)
	equip_margin.add_child(equip_stack)

	var equip_title := Label.new()
	equip_title.text = "装备槽"
	equip_title.add_theme_font_size_override("font_size", 20)
	equip_stack.add_child(equip_title)

	var main_title := Label.new()
	main_title.text = "主装备区"
	main_title.add_theme_font_size_override("font_size", 17)
	equip_stack.add_child(main_title)

	var main_grid := GridContainer.new()
	main_grid.columns = 2
	main_grid.add_theme_constant_override("h_separation", 12)
	main_grid.add_theme_constant_override("v_separation", 12)
	equip_stack.add_child(main_grid)

	for slot_definition in ItemSystem.get_main_slot_definitions():
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		main_grid.add_child(cell)

		var slot_label := Label.new()
		slot_label.text = str(slot_definition["label"])
		cell.add_child(slot_label)

		var slot_control := PanelContainer.new()
		slot_control.set_script(ItemSlotScript)
		slot_control.setup(self, "equipment", str(slot_definition["slot"]), str(slot_definition["label"]), "", SIMPLE_SLOT_SIZE)
		equipment_slot_nodes[str(slot_definition["slot"])] = slot_control
		cell.add_child(slot_control)

	var accessory_title := Label.new()
	accessory_title.text = "饰品区"
	accessory_title.add_theme_font_size_override("font_size", 17)
	equip_stack.add_child(accessory_title)

	var accessory_grid := GridContainer.new()
	accessory_grid.columns = 3
	accessory_grid.add_theme_constant_override("h_separation", 12)
	accessory_grid.add_theme_constant_override("v_separation", 12)
	equip_stack.add_child(accessory_grid)

	for slot_definition in ItemSystem.get_accessory_slot_definitions():
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		accessory_grid.add_child(cell)

		var slot_label := Label.new()
		slot_label.text = str(slot_definition["label"])
		cell.add_child(slot_label)

		var slot_control := PanelContainer.new()
		slot_control.set_script(ItemSlotScript)
		slot_control.setup(self, "equipment", str(slot_definition["slot"]), str(slot_definition["label"]), "", SIMPLE_SLOT_SIZE)
		equipment_slot_nodes[str(slot_definition["slot"])] = slot_control
		cell.add_child(slot_control)

	var stats_panel := PanelContainer.new()
	stats_panel.custom_minimum_size = Vector2(450.0, 360.0)
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_child(stats_panel)

	var stats_margin := MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", 14)
	stats_margin.add_theme_constant_override("margin_top", 14)
	stats_margin.add_theme_constant_override("margin_right", 14)
	stats_margin.add_theme_constant_override("margin_bottom", 14)
	stats_panel.add_child(stats_margin)

	var stats_scroll := ScrollContainer.new()
	stats_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_margin.add_child(stats_scroll)

	var stats_stack := VBoxContainer.new()
	stats_stack.add_theme_constant_override("separation", 8)
	stats_scroll.add_child(stats_stack)

	var a_title := Label.new()
	a_title.text = "A 类属性"
	a_title.add_theme_font_size_override("font_size", 20)
	stats_stack.add_child(a_title)

	for stat_definition in CharacterStats.A_STAT_ORDER:
		var stat_label := Label.new()
		a_stat_labels[str(stat_definition["key"])] = stat_label
		stats_stack.add_child(stat_label)

	var level_label := Label.new()
	a_stat_labels["level"] = level_label
	stats_stack.add_child(level_label)

	var b_title := Label.new()
	b_title.text = "B 类属性"
	b_title.add_theme_font_size_override("font_size", 20)
	stats_stack.add_child(b_title)

	for stat_definition in CharacterStats.B_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		var stat_row := PanelContainer.new()
		stat_row.mouse_filter = Control.MOUSE_FILTER_STOP
		stat_row.mouse_entered.connect(_on_b_stat_row_mouse_entered.bind(stat_key))
		stat_row.mouse_exited.connect(_on_b_stat_row_mouse_exited.bind(stat_key))
		stats_stack.add_child(stat_row)
		b_stat_row_nodes[stat_key] = stat_row

		var stat_margin := MarginContainer.new()
		stat_margin.add_theme_constant_override("margin_left", 6)
		stat_margin.add_theme_constant_override("margin_top", 4)
		stat_margin.add_theme_constant_override("margin_right", 6)
		stat_margin.add_theme_constant_override("margin_bottom", 4)
		stat_row.add_child(stat_margin)

		var stat_label := Label.new()
		stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b_stat_labels[stat_key] = stat_label
		stat_margin.add_child(stat_label)

	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(380.0, 0.0)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 14)
	right_margin.add_theme_constant_override("margin_top", 14)
	right_margin.add_theme_constant_override("margin_right", 14)
	right_margin.add_theme_constant_override("margin_bottom", 14)
	right_panel.add_child(right_margin)

	var right_stack := VBoxContainer.new()
	right_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_stack.add_theme_constant_override("separation", 8)
	right_margin.add_child(right_stack)

	var bag_title := Label.new()
	bag_title.text = "背包"
	bag_title.add_theme_font_size_override("font_size", 20)
	right_stack.add_child(bag_title)

	equipment_bag_status_label = Label.new()
	right_stack.add_child(equipment_bag_status_label)

	var bag_tip := Label.new()
	bag_tip.text = "双击装备或卸下，右键查看更多操作。"
	bag_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_stack.add_child(bag_tip)

	var bag_scroll := ScrollContainer.new()
	bag_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_stack.add_child(bag_scroll)

	equipment_bag_grid = GridContainer.new()
	equipment_bag_grid.columns = INVENTORY_COLUMNS
	equipment_bag_grid.add_theme_constant_override("h_separation", 10)
	equipment_bag_grid.add_theme_constant_override("v_separation", 10)
	bag_scroll.add_child(equipment_bag_grid)

	return page


func _build_bag_page() -> Control:
	var page := HBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 16)

	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(360.0, 0.0)
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 14)
	detail_margin.add_theme_constant_override("margin_top", 14)
	detail_margin.add_theme_constant_override("margin_right", 14)
	detail_margin.add_theme_constant_override("margin_bottom", 14)
	detail_panel.add_child(detail_margin)

	var detail_stack := VBoxContainer.new()
	detail_stack.add_theme_constant_override("separation", 8)
	detail_margin.add_child(detail_stack)

	detail_name_label = Label.new()
	detail_name_label.text = "未选择物品"
	detail_name_label.add_theme_font_size_override("font_size", 22)
	detail_stack.add_child(detail_name_label)

	detail_type_label = Label.new()
	detail_stack.add_child(detail_type_label)

	detail_rarity_label = Label.new()
	detail_stack.add_child(detail_rarity_label)

	detail_count_label = Label.new()
	detail_stack.add_child(detail_count_label)

	detail_bonus_label = RichTextLabel.new()
	detail_bonus_label.bbcode_enabled = true
	detail_bonus_label.fit_content = true
	detail_bonus_label.scroll_active = false
	detail_bonus_label.custom_minimum_size = Vector2(320.0, 220.0)
	detail_stack.add_child(detail_bonus_label)

	detail_description_label = RichTextLabel.new()
	detail_description_label.bbcode_enabled = true
	detail_description_label.fit_content = true
	detail_description_label.scroll_active = false
	detail_description_label.custom_minimum_size = Vector2(320.0, 260.0)
	detail_stack.add_child(detail_description_label)

	var center_panel := PanelContainer.new()
	center_panel.custom_minimum_size = Vector2(360.0, 0.0)
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(center_panel)

	var center_margin := MarginContainer.new()
	center_margin.add_theme_constant_override("margin_left", 14)
	center_margin.add_theme_constant_override("margin_top", 14)
	center_margin.add_theme_constant_override("margin_right", 14)
	center_margin.add_theme_constant_override("margin_bottom", 14)
	center_panel.add_child(center_margin)

	var center_stack := VBoxContainer.new()
	center_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_stack.add_theme_constant_override("separation", 8)
	center_margin.add_child(center_stack)

	var bag_title := Label.new()
	bag_title.text = "完整背包"
	bag_title.add_theme_font_size_override("font_size", 20)
	center_stack.add_child(bag_title)

	bag_status_label = Label.new()
	center_stack.add_child(bag_status_label)

	var full_bag_tip := Label.new()
	full_bag_tip.text = "完整背包页显示完整版信息，右侧区域负责操作。"
	full_bag_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_stack.add_child(full_bag_tip)

	var bag_scroll := ScrollContainer.new()
	bag_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_stack.add_child(bag_scroll)

	full_bag_grid = GridContainer.new()
	full_bag_grid.columns = INVENTORY_COLUMNS
	full_bag_grid.add_theme_constant_override("h_separation", 10)
	full_bag_grid.add_theme_constant_override("v_separation", 10)
	bag_scroll.add_child(full_bag_grid)

	var action_panel := PanelContainer.new()
	action_panel.custom_minimum_size = Vector2(180.0, 0.0)
	action_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(action_panel)

	var action_margin := MarginContainer.new()
	action_margin.add_theme_constant_override("margin_left", 14)
	action_margin.add_theme_constant_override("margin_top", 14)
	action_margin.add_theme_constant_override("margin_right", 14)
	action_margin.add_theme_constant_override("margin_bottom", 14)
	action_panel.add_child(action_margin)

	var action_stack := VBoxContainer.new()
	action_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_stack.add_theme_constant_override("separation", 10)
	action_margin.add_child(action_stack)

	var action_title := Label.new()
	action_title.text = "操作区"
	action_title.add_theme_font_size_override("font_size", 20)
	action_stack.add_child(action_title)

	var drop_zone_slot := PanelContainer.new()
	drop_zone_slot.set_script(ItemSlotScript)
	drop_zone_slot.setup(self, "drop_zone", -1, "", "丢弃区", FULL_SLOT_SIZE)
	drop_zone_slot.custom_minimum_size = Vector2(150.0, 80.0)
	action_stack.add_child(drop_zone_slot)

	var drop_button := Button.new()
	drop_button.text = "丢弃"
	drop_button.pressed.connect(_on_drop_button_pressed)
	action_stack.add_child(drop_button)

	var split_button := Button.new()
	split_button.text = "拆分"
	split_button.pressed.connect(_on_split_button_pressed)
	action_stack.add_child(split_button)

	var use_button := Button.new()
	use_button.text = "使用"
	use_button.pressed.connect(_on_use_button_pressed)
	action_stack.add_child(use_button)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(_close_menu)
	action_stack.add_child(close_button)

	return page


func _show_tab(tab_id: String) -> void:
	current_tab = tab_id
	_close_transient_popups()
	_clear_feedback()
	_hide_hover_detail()
	for page_key in page_nodes.keys():
		page_nodes[page_key].visible = page_key == tab_id
	for tab_key in tab_buttons.keys():
		tab_buttons[tab_key].disabled = tab_key == tab_id


func _on_tab_button_pressed(tab_id: String) -> void:
	_show_tab(tab_id)
	_refresh_all()


func select_slot(slot_kind: String, slot_key: Variant) -> void:
	_close_transient_popups()
	selected_slot_kind = slot_kind
	selected_slot_key = slot_key
	if current_tab == "bag":
		_refresh_detail_panel()


func hover_slot(slot_kind: String, slot_key: Variant) -> void:
	hovered_slot_kind = slot_kind
	hovered_slot_key = slot_key
	if current_tab == "bag":
		_refresh_detail_panel()
	_request_slot_hover_detail(slot_kind, slot_key)


func unhover_slot(slot_kind: String, slot_key: Variant) -> void:
	if hovered_slot_kind == slot_kind and hovered_slot_key == slot_key:
		hovered_slot_kind = ""
		hovered_slot_key = null
	_hide_hover_detail()
	if current_tab == "bag":
		_refresh_detail_panel()


func notify_item_drag_started() -> void:
	_close_transient_popups()
	_hide_hover_detail()


func handle_slot_double_click(slot_kind: String, slot_key: Variant) -> void:
	if player == null:
		return
	var action_id := _resolve_default_item_action(slot_kind, slot_key)
	if action_id == "":
		return
	_execute_item_action(action_id, {
		"slot_kind": slot_kind,
		"slot_key": slot_key,
	})


func handle_skill_entry_double_click(skill_id: String) -> void:
	if player == null or not player.has_method("equip_skill_to_first_empty_slot"):
		return
	if not player.equip_skill_to_first_empty_slot(skill_id):
		_set_feedback("当前没有空技能槽，或该技能已在技能栏中。")
		return
	_clear_feedback()
	_refresh_all()


func handle_skill_slot_double_click(slot_index: int) -> void:
	if player == null or not player.has_method("unequip_skill_at_slot"):
		return
	if not player.unequip_skill_at_slot(slot_index):
		return
	_clear_feedback()
	_refresh_all()


func handle_slot_right_click(slot_kind: String, slot_key: Variant, mouse_position: Vector2, anchor_rect: Rect2 = Rect2()) -> void:
	if player == null:
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


func can_drop_on_slot(slot_kind: String, slot_key: Variant, data: Variant) -> bool:
	if player == null or typeof(data) != TYPE_DICTIONARY:
		return false

	var source_kind: String = str(data.get("slot_kind", ""))
	var source_key: Variant = data.get("slot_key")
	var item_stack: Dictionary = data.get("item_stack", {})
	if item_stack.is_empty():
		return false

	match slot_kind:
		"inventory":
			if source_kind == "inventory":
				return int(source_key) != int(slot_key)
			if source_kind == "equipment":
				var target_stack: Dictionary = player.get_inventory_stack(int(slot_key))
				if target_stack.is_empty():
					return true
				if ItemSystem.can_merge_stacks(target_stack, item_stack):
					return true
				return player.can_equip_item_to_slot(target_stack, str(source_key))
		"equipment":
			return source_kind == "inventory" and player.can_equip_item_to_slot(item_stack, str(slot_key))
		"drop_zone":
			return source_kind == "inventory"

	return false


func handle_drop_on_slot(slot_kind: String, slot_key: Variant, data: Variant) -> void:
	if not can_drop_on_slot(slot_kind, slot_key, data):
		return

	var source_kind: String = str(data.get("slot_kind", ""))
	var source_key: Variant = data.get("slot_key")

	match slot_kind:
		"inventory":
			if source_kind == "inventory":
				player.move_inventory_item(int(source_key), int(slot_key))
			elif source_kind == "equipment":
				if not player.unequip_to_inventory(str(source_key), int(slot_key)):
					_set_feedback("当前无法放回背包。")
					return
		"equipment":
			if not player.equip_from_inventory(int(source_key), str(slot_key)):
				_set_feedback("当前无法装备到该槽位。")
				return
		"drop_zone":
			_request_drop_inventory(int(source_key))
			return

	_clear_feedback()
	_refresh_all()


func _refresh_all() -> void:
	if player == null:
		return
	_refresh_skill_page_v2()
	_refresh_equipment_slots()
	_refresh_backpack_views()
	_refresh_stat_panel()
	_refresh_detail_panel()


func _refresh_equipment_slots() -> void:
	for slot_definition in ItemSystem.EQUIP_SLOT_ORDER:
		var slot_type: String = str(slot_definition["slot"])
		var item_stack: Dictionary = player.get_equipment_slot_stack(slot_type)
		equipment_slot_nodes[slot_type].set_item_view(item_stack, player.get_item_stack_definition(item_stack))


func _refresh_backpack_views() -> void:
	var inventory_slots: Array = player.get_inventory_slots()
	var capacity: int = player.get_inventory_capacity()
	var visible_slot_count: int = max(capacity, inventory_slots.size(), 1)

	_ensure_equipment_bag_slot_pool(visible_slot_count)
	_ensure_full_bag_slot_pool(visible_slot_count)

	equipment_bag_status_label.text = "背包容量：%d / %d%s" % [
		_count_occupied_slots(inventory_slots),
		capacity,
		"（超载）" if player.is_inventory_overloaded() else "",
	]
	bag_status_label.text = equipment_bag_status_label.text

	for index in range(equipment_bag_slot_nodes.size()):
		var item_stack: Dictionary = inventory_slots[index] if index < inventory_slots.size() else {}
		equipment_bag_slot_nodes[index].visible = index < visible_slot_count
		if index < visible_slot_count:
			equipment_bag_slot_nodes[index].set_item_view(item_stack, player.get_item_stack_definition(item_stack))

	for index in range(full_bag_slot_nodes.size()):
		var item_stack: Dictionary = inventory_slots[index] if index < inventory_slots.size() else {}
		full_bag_slot_nodes[index].visible = index < visible_slot_count
		if index < visible_slot_count:
			full_bag_slot_nodes[index].set_item_view(item_stack, player.get_item_stack_definition(item_stack))


func _refresh_skill_page() -> void:
	if skill_page_owned_list == null or skill_page_slot_list == null or player == null:
		return
	for child in skill_page_owned_list.get_children():
		child.free()
	for child in skill_page_slot_list.get_children():
		child.free()

	var owned_entries: Array = player.get_owned_skill_entries() if player.has_method("get_owned_skill_entries") else []
	var slot_entries: Array = player.get_skill_slot_entries() if player.has_method("get_skill_slot_entries") else []

	if skill_page_status_label != null:
		skill_page_status_label.text = "已拥有 %d 个技能，当前配置 %d / %d。双击已拥有技能装入，双击槽位卸下。" % [
			owned_entries.size(),
			_count_equipped_skills(slot_entries),
			slot_entries.size(),
		]

	if owned_entries.is_empty():
		var empty_owned := Label.new()
		empty_owned.text = "当前没有已拥有技能。"
		skill_page_owned_list.add_child(empty_owned)
	else:
		for entry in owned_entries:
			skill_page_owned_list.add_child(_build_owned_skill_entry(entry as Dictionary))

	if slot_entries.is_empty():
		var empty_slot := Label.new()
		empty_slot.text = "当前没有技能槽。"
		skill_page_slot_list.add_child(empty_slot)
	else:
		for entry in slot_entries:
			skill_page_slot_list.add_child(_build_skill_slot_entry(entry as Dictionary))


func _build_owned_skill_entry(skill_data: Dictionary) -> Control:
	var skill_id := str(skill_data.get("skill_id", ""))
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "%s [%s]\n%s" % [
		str(skill_data.get("display_name", skill_id)),
		str(skill_data.get("skill_type_label", "")),
		str(skill_data.get("summary", "")),
	]
	button.custom_minimum_size = Vector2(0.0, 72.0)
	button.mouse_entered.connect(_on_skill_hover_entered.bind(skill_id, button))
	button.mouse_exited.connect(_on_skill_hover_exited.bind(skill_id))
	button.gui_input.connect(_on_owned_skill_entry_gui_input.bind(skill_id))
	return button


func _build_skill_slot_entry(slot_data: Dictionary) -> Control:
	var slot_index := int(slot_data.get("slot_index", -1))
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, 72.0)
	if bool(slot_data.get("is_empty", false)):
		button.text = "槽位 %d：空\n双击已拥有技能可装入这里。" % [slot_index + 1]
	else:
		button.text = "槽位 %d：%s [%s]\n双击可卸下，HUD 会立即同步。" % [
			slot_index + 1,
			str(slot_data.get("display_name", "")),
			str(slot_data.get("skill_type_label", "")),
		]
		var skill_id := str(slot_data.get("skill_id", ""))
		button.mouse_entered.connect(_on_skill_hover_entered.bind(skill_id, button))
		button.mouse_exited.connect(_on_skill_hover_exited.bind(skill_id))
	button.gui_input.connect(_on_skill_slot_entry_gui_input.bind(slot_index))
	return button


func _count_equipped_skills(slot_entries: Array) -> int:
	var count := 0
	for entry in slot_entries:
		if not bool((entry as Dictionary).get("is_empty", true)):
			count += 1
	return count


func _ensure_equipment_bag_slot_pool(target_count: int) -> void:
	while equipment_bag_slot_nodes.size() < target_count:
		var slot_index := equipment_bag_slot_nodes.size()
		var slot_control := PanelContainer.new()
		slot_control.set_script(ItemSlotScript)
		slot_control.setup(self, "inventory", slot_index, "", "", SIMPLE_SLOT_SIZE)
		equipment_bag_slot_nodes.append(slot_control)
		equipment_bag_grid.add_child(slot_control)


func _ensure_full_bag_slot_pool(target_count: int) -> void:
	while full_bag_slot_nodes.size() < target_count:
		var slot_index := full_bag_slot_nodes.size()
		var slot_control := PanelContainer.new()
		slot_control.set_script(ItemSlotScript)
		slot_control.setup(self, "inventory", slot_index, "", "", FULL_SLOT_SIZE)
		full_bag_slot_nodes.append(slot_control)
		full_bag_grid.add_child(slot_control)


func _count_occupied_slots(inventory_slots: Array) -> int:
	var count := 0
	for item_stack in inventory_slots:
		if not (item_stack as Dictionary).is_empty():
			count += 1
	return count


func _refresh_stat_panel() -> void:
	var base_a: Dictionary = player.get_base_a_stats()
	var current_a: Dictionary = player.get_character_a_stats()
	var base_b: Dictionary = player.get_base_b_stats() if player.has_method("get_base_b_stats") else CharacterStats.calculate_b_stats(current_a)
	var current_b: Dictionary = player.get_character_b_stats()

	for stat_definition in CharacterStats.A_STAT_ORDER:
		var stat_key: String = str(stat_definition["key"])
		var value: int = int(current_a.get(stat_key, 0))
		var bonus: int = value - int(base_a.get(stat_key, 0))
		a_stat_labels[stat_key].text = "%s：%d%s" % [
			str(stat_definition["label"]),
			value,
			_format_delta_text(float(bonus), false),
		]

	a_stat_labels["level"].text = "等级：%d" % player.get_level()

	for stat_definition in CharacterStats.B_STAT_ORDER:
		var stat_key: String = str(stat_definition["key"])
		var value: float = float(current_b.get(stat_key, 0.0))
		var base_value: float = float(base_b.get(stat_key, 0.0))
		b_stat_labels[stat_key].text = "%s：%s%s" % [
			str(stat_definition["label"]),
			CharacterStats.format_b_stat_value(stat_key, value),
			_format_delta_text(value - base_value, true),
		]


func _format_delta_text(delta_value: float, is_b_stat: bool) -> String:
	if absf(delta_value) < 0.001:
		return ""
	if not is_b_stat:
		return " (%+d)" % int(round(delta_value))
	if absf(delta_value - round(delta_value)) < 0.001:
		return " (%+d)" % int(round(delta_value))
	return " (%+.1f)" % delta_value


func _refresh_detail_panel() -> void:
	if current_tab != "bag":
		return
	var slot_ref := _get_active_slot_reference()
	if slot_ref["kind"] == "":
		_clear_detail_panel("未选择物品")
		return

	var item_stack: Dictionary = _get_slot_stack(slot_ref["kind"], slot_ref["key"])
	var definition: Dictionary = player.get_item_stack_definition(item_stack)
	if item_stack.is_empty() or definition.is_empty():
		_clear_detail_panel("空槽位")
		return

	detail_name_label.text = str(definition.get("name", ""))
	detail_type_label.text = "类型：%s" % _get_item_type_display(definition)
	detail_rarity_label.text = "稀有度：%s" % str(definition.get("rarity", ""))
	detail_rarity_label.modulate = ItemSystem.get_rarity_color(str(definition.get("rarity", "")))
	detail_count_label.text = "叠加数量：%d" % int(item_stack.get("count", 1))

	detail_bonus_label.clear()
	detail_bonus_label.append_text(_build_item_full_text(definition))

	detail_description_label.clear()
	detail_description_label.append_text("[b]描述[/b]\n%s\n\n[b]补充说明[/b]\n%s" % [
		str(definition.get("description", "")),
		str(definition.get("flavor_text", "")),
	])


func _clear_detail_panel(title_text: String) -> void:
	detail_name_label.text = title_text
	detail_type_label.text = ""
	detail_rarity_label.text = ""
	detail_count_label.text = ""
	detail_bonus_label.clear()
	detail_description_label.clear()


func _build_item_full_text(definition: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[b]属性加成[/b]")

	var modifier_entries := ItemSystem.get_modifier_entries(definition)
	if modifier_entries.is_empty():
		lines.append("无")
	else:
		for entry in modifier_entries:
			lines.append(ItemSystem._format_modifier_entry_line(entry))

	lines.append("")
	lines.append("[b]特殊效果[/b]")
	var special_effects: Array = definition.get("special_effects", [])
	if special_effects.is_empty():
		lines.append("当前无特殊效果")
	else:
		for effect in special_effects:
			lines.append(str(effect))
	return "\n".join(lines)


func _build_item_simple_text(definition: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % str(definition.get("display_name", definition.get("name", ""))))
	lines.append("类型：%s" % _get_item_type_display(definition))
	lines.append("稀有度：%s" % str(definition.get("rarity", "")))

	var bonus_lines: Array[String] = []
	for entry in ItemSystem.get_modifier_entries(definition):
		bonus_lines.append(ItemSystem._format_modifier_entry_line(entry))
	if not bonus_lines.is_empty():
		lines.append("")
		lines.append("[b]核心属性[/b]")
		for bonus_line in bonus_lines:
			lines.append(bonus_line)

	lines.append("")
	lines.append("[b]特殊效果摘要[/b]")
	var special_effects: Array = definition.get("special_effects", [])
	if special_effects.is_empty():
		lines.append("无特殊效果")
	else:
		for effect in special_effects:
			lines.append(str(effect))
	return "\n".join(lines)


func _request_slot_hover_detail(slot_kind: String, slot_key: Variant) -> void:
	if hover_detail_manager == null:
		return
	if (item_context_menu != null and item_context_menu.visible) or (split_stack_dialog != null and split_stack_dialog.visible):
		return
	var anchor_control := _get_slot_anchor_control(slot_kind, slot_key)
	if anchor_control == null:
		return

	if slot_kind == "equipment":
		var equipment_source_id := "%s:%s" % [slot_kind, str(slot_key)]
		hover_detail_manager.request_hover("equipment_slot", equipment_source_id, anchor_control, Callable(self, "_build_equipment_slot_hover_context").bind(str(slot_key)), "target")
		return

	if slot_kind != "inventory":
		return

	var item_source_id := "%s:%s:%s" % [current_tab, slot_kind, str(slot_key)]
	hover_detail_manager.request_hover("item_entry", item_source_id, anchor_control, Callable(self, "_build_item_slot_hover_context").bind(slot_kind, slot_key), "target")


func _hide_hover_detail() -> void:
	if hover_detail_manager != null:
		hover_detail_manager.hide_immediately()


func _on_skill_hover_entered(skill_id: String, anchor_control: Control) -> void:
	if hover_detail_manager == null or skill_id.is_empty():
		return
	hover_detail_manager.request_hover("skill_entry", skill_id, anchor_control, Callable(self, "_build_skill_hover_context").bind(skill_id), "target")


func _on_skill_hover_exited(skill_id: String) -> void:
	if hover_detail_manager != null and not skill_id.is_empty():
		hover_detail_manager.clear_hover(skill_id)


func _on_owned_skill_entry_gui_input(event: InputEvent, skill_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
			handle_skill_entry_double_click(skill_id)
			get_viewport().set_input_as_handled()


func _on_skill_slot_entry_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
			handle_skill_slot_double_click(slot_index)
			get_viewport().set_input_as_handled()


func _on_b_stat_row_mouse_entered(stat_key: String) -> void:
	if hover_detail_manager == null or player == null or current_tab != "equipment":
		return
	hover_detail_manager.request_hover("attribute_b_entry", "b_stat:%s" % stat_key, b_stat_row_nodes.get(stat_key, self), Callable(self, "_build_b_stat_hover_context").bind(stat_key), "target")


func _on_b_stat_row_mouse_exited(stat_key: String) -> void:
	if hover_detail_manager != null:
		hover_detail_manager.clear_hover("b_stat:%s" % stat_key)


func _build_equipment_slot_hover_context(slot_type: String) -> Dictionary:
	if player == null:
		return {}
	return {
		"player": player,
		"slot_key": slot_type,
		"slot_kind": "equipment",
		"source_context": "装备页",
	}


func _build_b_stat_hover_context(stat_key: String) -> Dictionary:
	if player == null:
		return {}
	return {
		"player": player,
		"stat_key": stat_key,
		"source_context": "装备页",
	}


func _build_skill_hover_context(skill_id: String) -> Dictionary:
	if player == null:
		return {}
	return {
		"player": player,
		"skill_id": skill_id,
	}


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
		"source_context": "背包页" if current_tab == "bag" else "装备页",
	}


func _get_slot_anchor_control(slot_kind: String, slot_key: Variant) -> Control:
	match slot_kind:
		"equipment":
			return equipment_slot_nodes.get(str(slot_key))
		"inventory":
			if current_tab == "bag":
				if int(slot_key) >= 0 and int(slot_key) < full_bag_slot_nodes.size():
					return full_bag_slot_nodes[int(slot_key)]
			else:
				if int(slot_key) >= 0 and int(slot_key) < equipment_bag_slot_nodes.size():
					return equipment_bag_slot_nodes[int(slot_key)]
	return null


func _get_item_type_display(definition: Dictionary) -> String:
	return ItemSystem.get_item_type_display(definition)


func _get_slot_label(slot_type: String) -> String:
	return ItemSystem.get_slot_label(slot_type)


func _get_active_slot_reference() -> Dictionary:
	if hovered_slot_kind != "":
		return {"kind": hovered_slot_kind, "key": hovered_slot_key}
	return {"kind": selected_slot_kind, "key": selected_slot_key}


func _get_slot_stack(slot_kind: String, slot_key: Variant) -> Dictionary:
	if player == null:
		return {}
	if slot_kind == "equipment":
		return player.get_equipment_slot_stack(str(slot_key))
	if slot_kind == "inventory":
		return player.get_inventory_stack(int(slot_key))
	return {}


func _resolve_default_item_action(slot_kind: String, slot_key: Variant) -> String:
	var item_stack: Dictionary = _get_slot_stack(slot_kind, slot_key)
	if item_stack.is_empty():
		return ""

	if slot_kind == "equipment":
		return "unequip"

	if slot_kind != "inventory":
		return ""

	var definition: Dictionary = player.get_item_stack_definition(item_stack)
	if definition.is_empty():
		return ""
	if str(definition.get("item_type", "")) == "equipment" and str(definition.get("equip_slot_type", "")) != "":
		return "equip"
	return ""


func _build_item_context_actions(slot_kind: String, slot_key: Variant, item_stack: Dictionary, definition: Dictionary) -> Array:
	var actions: Array = []
	var base_context := {
		"slot_kind": slot_kind,
		"slot_key": slot_key,
	}

	if slot_kind == "inventory":
		if str(definition.get("item_type", "")) == "equipment" and str(definition.get("equip_slot_type", "")) != "":
			actions.append({
				"id": "equip",
				"label": "装备",
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
		if bool(definition.get("can_drop", true)):
			actions.append({
				"id": "drop",
				"label": "丢弃",
				"slot_kind": slot_kind,
				"slot_key": slot_key,
			})
	elif slot_kind == "equipment":
		actions.append({
			"id": "unequip",
			"label": "卸下",
			"slot_kind": slot_kind,
			"slot_key": slot_key,
		})

	return actions


func _execute_item_action(action_id: String, action_context: Dictionary) -> void:
	match action_id:
		"equip":
			_attempt_equip_inventory(int(action_context.get("slot_key", -1)))
		"unequip":
			_attempt_unequip_slot(str(action_context.get("slot_key", "")))
		"drop":
			_request_drop_inventory(int(action_context.get("slot_key", -1)))
		"split":
			_open_split_dialog_for_inventory(int(action_context.get("slot_key", -1)))


func _attempt_equip_inventory(index: int) -> void:
	var item_stack: Dictionary = player.get_inventory_stack(index)
	var definition: Dictionary = player.get_item_stack_definition(item_stack)
	if item_stack.is_empty() or definition.is_empty():
		return

	var target_slot: String = player.find_best_equip_slot_for_item_stack(item_stack)
	if target_slot == "":
		if str(definition.get("equip_slot_type", "")) == "accessory":
			_set_feedback("饰品槽已满。")
		else:
			_set_feedback("当前无法装备这件物品。")
		return

	if not player.equip_from_inventory(index, target_slot):
		_set_feedback("当前无法装备这件物品。")
		return

	_clear_feedback()
	_refresh_all()


func _attempt_unequip_slot(slot_type: String) -> void:
	if slot_type == "":
		return
	if not player.unequip_to_inventory_auto(slot_type):
		_set_feedback("背包已满，无法卸下。")
		return

	_clear_feedback()
	_refresh_all()


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


func _on_item_context_action_selected(action_id: String, action_context: Dictionary) -> void:
	_execute_item_action(action_id, action_context)


func _on_split_stack_confirmed(split_count: int, split_context: Dictionary) -> void:
	if str(split_context.get("slot_kind", "")) != "inventory":
		return
	if not player.split_inventory_stack_by_count(int(split_context.get("slot_key", -1)), split_count):
		_set_feedback("背包空间不足，无法拆分。")
		return

	_clear_feedback()
	_refresh_all()


func _close_transient_popups() -> void:
	if item_context_menu != null and item_context_menu.visible:
		item_context_menu.hide_menu()
	if split_stack_dialog != null and split_stack_dialog.visible:
		split_stack_dialog.hide_dialog()


func _set_feedback(text: String) -> void:
	if interaction_feedback_label != null:
		interaction_feedback_label.text = text


func _clear_feedback() -> void:
	if interaction_feedback_label != null:
		interaction_feedback_label.text = ""


func _request_drop_inventory(index: int) -> void:
	var item_stack: Dictionary = player.get_inventory_stack(index)
	if item_stack.is_empty():
		return
	pending_drop_index = index
	_close_transient_popups()
	_hide_hover_detail()
	drop_confirm_dialog.popup_centered()


func _on_drop_confirmed() -> void:
	if pending_drop_index < 0:
		return
	player.drop_inventory_item(pending_drop_index)
	pending_drop_index = -1
	_clear_feedback()
	_refresh_all()


func _on_drop_button_pressed() -> void:
	if selected_slot_kind != "inventory":
		return
	_request_drop_inventory(int(selected_slot_key))


func _on_split_button_pressed() -> void:
	if selected_slot_kind != "inventory":
		return
	_open_split_dialog_for_inventory(int(selected_slot_key))


func _build_skill_page_v2() -> Control:
	var page := HBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 16)

	var slot_panel := PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(420.0, 0.0)
	slot_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(slot_panel)

	var slot_margin := MarginContainer.new()
	slot_margin.add_theme_constant_override("margin_left", 14)
	slot_margin.add_theme_constant_override("margin_top", 14)
	slot_margin.add_theme_constant_override("margin_right", 14)
	slot_margin.add_theme_constant_override("margin_bottom", 14)
	slot_panel.add_child(slot_margin)

	var slot_stack := VBoxContainer.new()
	slot_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_stack.add_theme_constant_override("separation", 10)
	slot_margin.add_child(slot_stack)

	var slot_title := Label.new()
	slot_title.text = "技能槽位"
	slot_title.add_theme_font_size_override("font_size", 22)
	slot_stack.add_child(slot_title)

	skill_page_status_label = Label.new()
	skill_page_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_stack.add_child(skill_page_status_label)

	var slot_tip := Label.new()
	slot_tip.text = "左侧显示已配置技能，未来预留到 6 槽。双击或拖拽都直接修改同一份技能配置数据。"
	slot_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_stack.add_child(slot_tip)

	skill_page_slot_grid = GridContainer.new()
	skill_page_slot_grid.columns = 2
	skill_page_slot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_page_slot_grid.add_theme_constant_override("h_separation", 12)
	skill_page_slot_grid.add_theme_constant_override("v_separation", 12)
	slot_stack.add_child(skill_page_slot_grid)

	var pool_panel := PanelContainer.new()
	pool_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pool_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(pool_panel)

	var pool_margin := MarginContainer.new()
	pool_margin.add_theme_constant_override("margin_left", 14)
	pool_margin.add_theme_constant_override("margin_top", 14)
	pool_margin.add_theme_constant_override("margin_right", 14)
	pool_margin.add_theme_constant_override("margin_bottom", 14)
	pool_panel.add_child(pool_margin)

	var pool_stack := VBoxContainer.new()
	pool_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pool_stack.add_theme_constant_override("separation", 10)
	pool_margin.add_child(pool_stack)

	var pool_title := Label.new()
	pool_title.text = "可选技能池"
	pool_title.add_theme_font_size_override("font_size", 22)
	pool_stack.add_child(pool_title)

	var pool_tip := Label.new()
	pool_tip.text = "右侧只显示已拥有但未配置的技能。装入后会立即从候选池隐藏。"
	pool_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pool_stack.add_child(pool_tip)

	var pool_scroll := ScrollContainer.new()
	pool_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pool_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pool_stack.add_child(pool_scroll)

	skill_page_pool_grid = GridContainer.new()
	skill_page_pool_grid.columns = 2
	skill_page_pool_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_page_pool_grid.add_theme_constant_override("h_separation", 12)
	skill_page_pool_grid.add_theme_constant_override("v_separation", 12)
	pool_scroll.add_child(skill_page_pool_grid)

	return page


func _refresh_skill_page_v2() -> void:
	if skill_page_pool_grid == null or skill_page_slot_grid == null or player == null:
		return
	for child in skill_page_pool_grid.get_children():
		child.queue_free()
	for child in skill_page_slot_grid.get_children():
		child.queue_free()

	var owned_entries: Array = player.get_owned_skill_entries() if player.has_method("get_owned_skill_entries") else []
	var slot_entries: Array = player.get_skill_slot_entries() if player.has_method("get_skill_slot_entries") else []
	var pool_entries: Array = []
	for entry in owned_entries:
		var skill_data: Dictionary = entry as Dictionary
		if not bool(skill_data.get("is_equipped", false)):
			pool_entries.append(skill_data)

	if skill_page_status_label != null:
		skill_page_status_label.text = "已拥有 %d 个技能，当前配置 %d / %d，界面预留到 %d 槽。" % [
			owned_entries.size(),
			_count_equipped_skills(slot_entries),
			slot_entries.size(),
			SKILL_MAX_VISIBLE_SLOTS,
		]

	var visible_slot_count: int = max(slot_entries.size(), SKILL_MAX_VISIBLE_SLOTS)
	for slot_index in range(visible_slot_count):
		if slot_index < slot_entries.size():
			skill_page_slot_grid.add_child(_build_skill_slot_card_v2(slot_entries[slot_index] as Dictionary, true))
		else:
			skill_page_slot_grid.add_child(_build_skill_slot_card_v2({"slot_index": slot_index, "is_locked": true}, false))

	skill_page_pool_grid.add_child(_build_skill_drag_card(
		"skill_pool",
		"",
		{},
		{
			"title": "技能候选池",
			"summary": "把左侧已装技能拖回这里即可卸下，并立即返回候选池。",
			"badge": "移出区",
			"empty_state": true,
			"draggable": false,
			"minimum_size": Vector2(0.0, 110.0),
		}
	))

	if pool_entries.is_empty():
		skill_page_pool_grid.add_child(_build_skill_drag_card(
			"skill_pool_locked",
			"",
			{},
			{
				"title": "暂无未配置技能",
				"summary": "当前已拥有技能都已经装入左侧槽位，或尚未学会新的技能。",
				"badge": "空",
				"empty_state": true,
				"draggable": false,
				"minimum_size": Vector2(0.0, 110.0),
			}
		))
	else:
		for entry in pool_entries:
			skill_page_pool_grid.add_child(_build_skill_pool_card_v2(entry as Dictionary))


func _build_skill_pool_card_v2(skill_data: Dictionary) -> Control:
	var skill_id := str(skill_data.get("skill_id", ""))
	return _build_skill_drag_card(
		"skill_pool_entry",
		skill_id,
		{},
		{
			"title": str(skill_data.get("display_name", skill_id)),
			"summary": str(skill_data.get("summary", "")),
			"badge": str(skill_data.get("skill_type_label", "")),
			"footer": "双击装入第一个空槽，或拖到左侧指定槽位",
			"minimum_size": Vector2(0.0, 130.0),
		}
	)


func _build_skill_slot_card_v2(slot_data: Dictionary, is_active_slot: bool) -> Control:
	var slot_index := int(slot_data.get("slot_index", -1))
	if not is_active_slot or bool(slot_data.get("is_locked", false)):
		return _build_skill_drag_card(
			"skill_slot_locked",
			"",
			{"slot_index": slot_index},
			{
				"title": "槽位 %d" % [slot_index + 1],
				"summary": "该槽位尚未开放，但布局和刷新逻辑已经为未来 6 槽预留。",
				"badge": "未开放",
				"locked_state": true,
				"draggable": false,
				"minimum_size": Vector2(0.0, 120.0),
			}
		)
	if bool(slot_data.get("is_empty", false)):
		return _build_skill_drag_card(
			"skill_slot",
			"",
			{"slot_index": slot_index},
			{
				"title": "槽位 %d" % [slot_index + 1],
				"summary": "空槽。可从右侧候选池装入技能。",
				"badge": "空槽",
				"footer": "双击右侧候选技能会自动填入第一个空槽",
				"empty_state": true,
				"draggable": false,
				"minimum_size": Vector2(0.0, 120.0),
			}
		)
	var skill_id := str(slot_data.get("skill_id", ""))
	return _build_skill_drag_card(
		"skill_slot",
		skill_id,
		{"slot_index": slot_index},
		{
			"title": str(slot_data.get("display_name", skill_id)),
			"summary": str(slot_data.get("summary", "")),
			"badge": "槽位 %d | %s" % [slot_index + 1, str(slot_data.get("skill_type_label", ""))],
			"footer": "双击卸下，或拖到其他槽位换槽 / 拖回右侧候选池",
			"selected_state": true,
			"minimum_size": Vector2(0.0, 120.0),
		}
	)


func _build_skill_drag_card(role: String, entry_id: String, payload: Dictionary, view_data: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.set_script(DragCardScript)
	card.custom_minimum_size = view_data.get("minimum_size", Vector2(0.0, 120.0))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.setup(self, role, entry_id, payload, bool(view_data.get("draggable", true)), false)
	card.set_card_content(
		str(view_data.get("title", "")),
		str(view_data.get("summary", "")),
		str(view_data.get("badge", "")),
		str(view_data.get("footer", "")),
		bool(view_data.get("empty_state", false)),
		bool(view_data.get("locked_state", false)),
		bool(view_data.get("selected_state", false))
	)
	return card


func notify_drag_card_started() -> void:
	_close_transient_popups()
	_hide_hover_detail()


func handle_drag_card_hover(is_entering: bool, card_role: String, card_id: String, _payload: Dictionary, anchor_control: Control) -> void:
	if not ["skill_pool_entry", "skill_slot"].has(card_role) or card_id.is_empty():
		if not is_entering:
			_hide_hover_detail()
		return
	if is_entering:
		_on_skill_hover_entered(card_id, anchor_control)
	else:
		_on_skill_hover_exited(card_id)


func handle_drag_card_double_click(card_role: String, card_id: String, payload: Dictionary) -> void:
	match card_role:
		"skill_pool_entry":
			handle_skill_entry_double_click(card_id)
		"skill_slot":
			if not card_id.is_empty():
				handle_skill_slot_double_click(int(payload.get("slot_index", -1)))


func can_drop_on_drag_card(card_role: String, card_id: String, payload: Dictionary, data: Variant) -> bool:
	if player == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var source_role := str(data.get("card_role", ""))
	var source_id := str(data.get("card_id", ""))
	var source_payload := data.get("payload", {}) as Dictionary
	match card_role:
		"skill_slot":
			var target_slot_index := int(payload.get("slot_index", -1))
			if target_slot_index < 0:
				return false
			if source_role == "skill_pool_entry":
				return card_id.is_empty() and not source_id.is_empty()
			if source_role == "skill_slot":
				var source_slot_index := int(source_payload.get("slot_index", -1))
				return source_slot_index >= 0 and source_slot_index != target_slot_index and not source_id.is_empty()
		"skill_pool":
			return source_role == "skill_slot" and not source_id.is_empty()
	return false


func handle_drop_on_drag_card(card_role: String, _card_id: String, payload: Dictionary, data: Variant) -> void:
	if not can_drop_on_drag_card(card_role, _card_id, payload, data):
		return
	var source_role := str(data.get("card_role", ""))
	var source_id := str(data.get("card_id", ""))
	var source_payload := data.get("payload", {}) as Dictionary
	match card_role:
		"skill_slot":
			var target_slot_index := int(payload.get("slot_index", -1))
			if source_role == "skill_pool_entry":
				if not player.has_method("equip_skill_to_slot") or not player.equip_skill_to_slot(source_id, target_slot_index):
					_set_feedback("当前无法把该技能装入指定槽位。")
					return
			elif source_role == "skill_slot":
				if not player.has_method("swap_skill_slots") or not player.swap_skill_slots(int(source_payload.get("slot_index", -1)), target_slot_index):
					_set_feedback("当前无法交换技能槽位。")
					return
		"skill_pool":
			if not player.has_method("unequip_skill_at_slot") or not player.unequip_skill_at_slot(int(source_payload.get("slot_index", -1))):
				_set_feedback("当前无法卸下该技能。")
				return
	_clear_feedback()
	_refresh_all()


func _on_use_button_pressed() -> void:
	detail_description_label.clear()
	detail_description_label.append_text("[b]提示[/b]\n当前版本暂未实装“使用”逻辑。")
