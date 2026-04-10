extends Control

const CharacterStats = preload("res://game/scripts/character_stats.gd")
const HoverDetailManagerScript = preload("res://game/scripts/hover_detail_manager.gd")
const CharacterCreationRegistry = preload("res://character_creation/scripts/character_creation_registry.gd")
const DragCardScript = preload("res://game/scripts/drag_card.gd")

signal back_requested
signal character_created(character_data: Dictionary, total_count: int)

const A_STAT_ORDER := CharacterStats.A_STAT_ORDER
const B_STAT_ORDER := CharacterStats.B_STAT_ORDER
const SOURCE_CONTEXT_STEP_6 := "创建第6步"
const SOURCE_CONTEXT_CONFIRM := "创建第7步"
const HOVER_META_STAT_ID := "hover_detail_stat_id"
const HOVER_META_SOURCE_CONTEXT := "hover_detail_source_context"
const HOVER_SOURCE_CREATION_SELECTION := "creation_selection"
const STEP_SCROLL_MIN_HEIGHT := 260.0

var player_characters: Array[Dictionary] = []
var selected_class_id: String = CharacterCreationRegistry.get_default_reborn_job_id()
var selected_background_id: String = ""
var selected_trait_ids: Array[String] = []
var selected_trait_slots: Array[String] = ["", ""]
var selected_strength_id: String = ""
var selected_weakness_id: String = ""
var selected_personality_id: String = ""
var current_level: int = CharacterCreationRegistry.get_default_level()
var current_a_stats: Dictionary = {}
var base_a_stats: Dictionary = {}
var allocated_bonus_by_stat: Dictionary = {}
var remaining_bonus_points: int = 0
var current_step: int = 1
var spinboxes_by_stat: Dictionary = {}
var b_value_labels: Dictionary = {}
var confirm_a_value_labels: Dictionary = {}
var confirm_b_value_labels: Dictionary = {}
var past_life_button_by_id: Dictionary = {}
var trait_checkbox_by_id: Dictionary = {}
var strength_button_by_id: Dictionary = {}
var weakness_button_by_id: Dictionary = {}
var personality_button_by_id: Dictionary = {}
var reborn_job_button_by_id: Dictionary = {}
var step_2_status_label: Label
var step_3_status_label: Label
var step_4_status_label: Label
var step_5_status_label: Label
var step_3_title_label: Label
var step_4_title_label: Label
var step_5_title_label: Label
var confirm_identity_labels: Dictionary = {}
var confirm_job_labels: Dictionary = {}
var confirm_skill_list_label: Label
var removed_trait_notice: String = ""
var hover_detail_manager: Control
var step_2_content_stack: VBoxContainer
var step_3_content_stack: VBoxContainer
var step_4_content_stack: VBoxContainer
var step_5_content_stack: VBoxContainer

@onready var step_1_page: Control = %Step1Page
@onready var step_2_page: Control = %Step2Page
@onready var step_3_page: Control = %Step3Page
@onready var step_4_page: Control = %Step4Page
@onready var step_5_page: Control = %Step5Page
@onready var step_6_page: Control = %Step6Page
@onready var confirm_page: Control = %ConfirmPage
@onready var class_status_label: Label = %ClassStatusLabel
@onready var class_scroll: ScrollContainer = %ClassScroll
@onready var warrior_card_button: Button = %WarriorCardButton
@onready var step_1_next_button: Button = %Step1NextButton
@onready var step_1_title_label: Label = $Step1Page/MarginContainer/Panel/Content/Stack/Title
@onready var step_1_hint_label: Label = $Step1Page/MarginContainer/Panel/Content/Stack/Hint
@onready var step_1_cards_container: HBoxContainer = $Step1Page/MarginContainer/Panel/Content/Stack/ClassScroll/Cards
@onready var step_title_label: Label = %StepTitleLabel
@onready var step_hint_label: Label = %StepHintLabel
@onready var step_2_stack: VBoxContainer = $Step2Page/MarginContainer/Panel/Content/Stack
@onready var step_2_footer: HBoxContainer = $Step2Page/MarginContainer/Panel/Content/Stack/Footer
@onready var step_2_back_button: Button = $Step2Page/MarginContainer/Panel/Content/Stack/Footer/Step2BackButton
@onready var step_2_next_button: Button = $Step2Page/MarginContainer/Panel/Content/Stack/Footer/Step2NextButton
@onready var step_3_stack: VBoxContainer = $Step3Page/MarginContainer/Panel/Content/Stack
@onready var step_3_info_label: Label = $Step3Page/MarginContainer/Panel/Content/Stack/InfoLabel
@onready var step_3_footer: HBoxContainer = $Step3Page/MarginContainer/Panel/Content/Stack/Footer
@onready var step_3_back_button: Button = $Step3Page/MarginContainer/Panel/Content/Stack/Footer/Step3BackButton
@onready var step_3_next_button: Button = $Step3Page/MarginContainer/Panel/Content/Stack/Footer/Step3NextButton
@onready var step_4_stack: VBoxContainer = $Step4Page/MarginContainer/Panel/Content/Stack
@onready var step_4_info_label: Label = $Step4Page/MarginContainer/Panel/Content/Stack/InfoLabel
@onready var step_4_footer: HBoxContainer = $Step4Page/MarginContainer/Panel/Content/Stack/Footer
@onready var step_4_back_button: Button = $Step4Page/MarginContainer/Panel/Content/Stack/Footer/Step4BackButton
@onready var step_4_next_button: Button = $Step4Page/MarginContainer/Panel/Content/Stack/Footer/Step4NextButton
@onready var selected_class_name_label: Label = %SelectedClassNameLabel
@onready var selected_class_description_label: Label = %SelectedClassDescriptionLabel
@onready var portrait_name_label: Label = %PortraitNameLabel
@onready var level_label: Label = %LevelLabel
@onready var points_value_label: Label = %PointsValueLabel
@onready var total_characters_label: Label = %TotalCharactersLabel
@onready var a_stats_container: VBoxContainer = %AStatsContainer
@onready var b_stats_container: VBoxContainer = %BStatsContainer
@onready var confirm_summary_label: Label = %ConfirmSummaryLabel
@onready var confirm_hint_label: Label = %ConfirmHintLabel
@onready var step_5_stack: VBoxContainer = $Step5Page/MarginContainer/Panel/Content/Stack
@onready var step_5_info_label: Label = $Step5Page/MarginContainer/Panel/Content/Stack/InfoLabel
@onready var step_5_footer: HBoxContainer = $Step5Page/MarginContainer/Panel/Content/Stack/Footer
@onready var step_5_back_button: Button = $Step5Page/MarginContainer/Panel/Content/Stack/Footer/Step5BackButton
@onready var step_5_next_button: Button = $Step5Page/MarginContainer/Panel/Content/Stack/Footer/Step5NextButton
@onready var confirm_stack: VBoxContainer = $ConfirmPage/MarginContainer/Panel/Content/Stack
@onready var confirm_title_label: Label = $ConfirmPage/MarginContainer/Panel/Content/Stack/Title
@onready var confirm_footer: HBoxContainer = $ConfirmPage/MarginContainer/Panel/Content/Stack/Footer


func _ready() -> void:
	_setup_hover_detail_manager()
	_build_step_1_page()
	_build_step_2_page()
	_build_step_3_page()
	_build_step_4_page()
	_build_step_5_page()
	_build_confirmation_page()
	_build_stat_rows()
	open_creation()


func open_creation() -> void:
	selected_background_id = ""
	selected_trait_ids.clear()
	selected_trait_slots = ["", ""]
	selected_strength_id = ""
	selected_weakness_id = ""
	selected_personality_id = ""
	selected_class_id = CharacterCreationRegistry.get_default_reborn_job_id()
	current_level = CharacterCreationRegistry.get_default_level()
	allocated_bonus_by_stat.clear()
	removed_trait_notice = ""
	_recalculate_creation_state()
	_refresh_all_pages()
	_show_step(1)


func get_player_characters() -> Array[Dictionary]:
	return player_characters.duplicate(true)


func select_past_life(past_life_id: String) -> void:
	if CharacterCreationRegistry.get_past_life(past_life_id).is_empty():
		return
	selected_background_id = past_life_id
	var removed_traits := _sanitize_selected_traits()
	if removed_traits.is_empty():
		removed_trait_notice = ""
	else:
		removed_trait_notice = "已移除不再适配当前前世职业的特性：%s" % "、".join(_collect_names_from_ids(removed_traits, "trait"))
	_recalculate_creation_state()
	_refresh_all_pages()


func toggle_trait(trait_id: String) -> void:
	if CharacterCreationRegistry.get_trait(trait_id).is_empty():
		return
	if not CharacterCreationRegistry.is_trait_available_for_past_life(trait_id, selected_background_id):
		return
	if selected_trait_ids.has(trait_id):
		_remove_trait_from_slot_by_id(trait_id)
	else:
		_assign_trait_to_slot(trait_id)
	removed_trait_notice = ""
	_recalculate_creation_state()
	_refresh_all_pages()


func select_strength(strength_id: String) -> void:
	if CharacterCreationRegistry.get_strength(strength_id).is_empty():
		return
	selected_strength_id = strength_id
	_recalculate_creation_state()
	_refresh_all_pages()


func select_weakness(weakness_id: String) -> void:
	if CharacterCreationRegistry.get_weakness(weakness_id).is_empty():
		return
	selected_weakness_id = weakness_id
	_recalculate_creation_state()
	_refresh_all_pages()


func select_personality(personality_id: String) -> void:
	if CharacterCreationRegistry.get_personality(personality_id).is_empty():
		return
	selected_personality_id = personality_id
	_recalculate_creation_state()
	_refresh_all_pages()


func select_reborn_job(job_id: String) -> void:
	if CharacterCreationRegistry.get_reborn_job(job_id).is_empty():
		return
	selected_class_id = job_id
	_recalculate_creation_state()
	_refresh_all_pages()


func set_a_stat_target_value(stat_key: String, target_value: int) -> void:
	var spinbox: SpinBox = spinboxes_by_stat.get(stat_key)
	if spinbox == null:
		return
	spinbox.set_block_signals(true)
	spinbox.value = target_value
	spinbox.set_block_signals(false)
	_on_a_stat_spinbox_value_changed(float(target_value), stat_key)


func build_character_preview_data() -> Dictionary:
	return _build_created_character_data()


func create_character_now() -> Dictionary:
	if not _can_submit_creation():
		return {}
	var created_character := _build_created_character_data()
	player_characters.append(created_character)
	emit_signal("character_created", created_character, player_characters.size())
	return created_character


func _setup_hover_detail_manager() -> void:
	hover_detail_manager = Control.new()
	hover_detail_manager.name = "HoverDetailManager"
	hover_detail_manager.set_script(HoverDetailManagerScript)
	add_child(hover_detail_manager)


func _build_step_1_page() -> void:
	step_1_title_label.text = "第1步：前世职业"
	step_1_hint_label.text = "请选择 1 个前世职业。老师 / 学生已并入这一层，并会继续兼容当前对话里的 bg_* trigger。"
	step_1_next_button.text = "下一步"
	for child in step_1_cards_container.get_children():
		child.queue_free()
	past_life_button_by_id.clear()
	for past_life_id in CharacterCreationRegistry.get_past_life_ids():
		var config := CharacterCreationRegistry.get_past_life(past_life_id)
		step_1_cards_container.add_child(_build_selection_card(
			str(config.get("display_name", past_life_id)),
			str(config.get("summary", "")),
			"选择%s" % str(config.get("display_name", past_life_id)),
			_on_past_life_button_pressed.bind(past_life_id),
			past_life_button_by_id,
			past_life_id,
			Vector2(240.0, 200.0),
			"past_life"
		))


func _build_step_2_page() -> void:
	step_title_label.text = "第2步：特性选择"
	step_hint_label.text = "总共只能选 2 个特性。职业相关特性会随前世职业变化而变化，通用特性始终可选。"
	step_2_back_button.text = "上一步"
	step_2_next_button.text = "下一步"
	step_2_content_stack = _ensure_scrollable_step_content(step_2_stack, step_2_footer, [step_title_label, step_hint_label], "Step2ContentScroll", "Step2ContentStack")
	trait_checkbox_by_id.clear()

	if step_2_status_label == null:
		step_2_status_label = Label.new()
		step_2_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_insert_before_child(step_2_stack, step_2_status_label, step_2_footer)


func _build_step_3_page() -> void:
	step_3_title_label = _ensure_title_label(step_3_stack, step_3_info_label, "第3步：特长 / 缺点")
	step_3_info_label.text = "必须选择 1 个特长和 1 个缺点。两类数据独立写入，不会混成同一组字段。"
	step_3_back_button.text = "上一步"
	step_3_next_button.text = "下一步"
	step_3_content_stack = _ensure_scrollable_step_content(step_3_stack, step_3_footer, [step_3_title_label, step_3_info_label], "Step3ContentScroll", "Step3ContentStack")
	strength_button_by_id.clear()
	weakness_button_by_id.clear()

	if step_3_status_label == null:
		step_3_status_label = Label.new()
		step_3_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_insert_before_child(step_3_stack, step_3_status_label, step_3_footer)


func _build_step_4_page() -> void:
	step_4_title_label = _ensure_title_label(step_4_stack, step_4_info_label, "第4步：性格选择")
	step_4_info_label.text = "请选择 1 个性格。它会作为正式角色字段写入，并可被 trigger 体系直接读取。"
	step_4_back_button.text = "上一步"
	step_4_next_button.text = "下一步"
	step_4_content_stack = _ensure_scrollable_step_content(step_4_stack, step_4_footer, [step_4_title_label, step_4_info_label], "Step4ContentScroll", "Step4ContentStack")
	personality_button_by_id.clear()

	if step_4_status_label == null:
		step_4_status_label = Label.new()
		step_4_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_insert_before_child(step_4_stack, step_4_status_label, step_4_footer)


func _build_step_5_page() -> void:
	step_5_title_label = _ensure_title_label(step_5_stack, step_5_info_label, "第5步：重生职业")
	step_5_info_label.text = "重生职业与前世职业是两个独立维度。当前仍沿用现役职业入口，但结果会正式保留。"
	step_5_back_button.text = "上一步"
	step_5_next_button.text = "下一步"
	step_5_content_stack = _ensure_scrollable_step_content(step_5_stack, step_5_footer, [step_5_title_label, step_5_info_label], "Step5ContentScroll", "Step5ContentStack")
	reborn_job_button_by_id.clear()

	if step_5_status_label == null:
		step_5_status_label = Label.new()
		step_5_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_insert_before_child(step_5_stack, step_5_status_label, step_5_footer)


func _build_confirmation_page() -> void:
	confirm_title_label.text = "第7步：最终展示 / 确认"
	confirm_summary_label.text = "请确认本次角色创建的完整结果。属性区继续复用现役 Tooltip 与 Shift 详细模式。"
	confirm_hint_label.text = "确认页只做只读总览。若要修改前面的创建项，请返回对应步骤。"
	_clear_container_before_footer(confirm_stack, confirm_footer, [confirm_title_label, confirm_summary_label, confirm_hint_label])

	var identity_panel := _create_summary_panel("身份塑形区")
	var identity_content: VBoxContainer = identity_panel.get_meta("content")
	confirm_identity_labels["past_life"] = _add_summary_line(identity_content, "前世职业")
	confirm_identity_labels["traits"] = _add_summary_line(identity_content, "特性")
	confirm_identity_labels["strength"] = _add_summary_line(identity_content, "特长")
	confirm_identity_labels["weakness"] = _add_summary_line(identity_content, "缺点")
	confirm_identity_labels["personality"] = _add_summary_line(identity_content, "性格")
	_insert_before_child(confirm_stack, identity_panel, confirm_footer)

	var job_panel := _create_summary_panel("职业与技能区")
	var job_content: VBoxContainer = job_panel.get_meta("content")
	confirm_job_labels["reborn_job"] = _add_summary_line(job_content, "重生职业")
	confirm_job_labels["level"] = _add_summary_line(job_content, "等级")
	var skill_title := Label.new()
	skill_title.text = "当前技能"
	skill_title.add_theme_font_size_override("font_size", 16)
	job_content.add_child(skill_title)
	confirm_skill_list_label = Label.new()
	confirm_skill_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	job_content.add_child(confirm_skill_list_label)
	_insert_before_child(confirm_stack, job_panel, confirm_footer)

	var attributes_panel := PanelContainer.new()
	attributes_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var attributes_margin := MarginContainer.new()
	attributes_margin.add_theme_constant_override("margin_left", 12)
	attributes_margin.add_theme_constant_override("margin_top", 12)
	attributes_margin.add_theme_constant_override("margin_right", 12)
	attributes_margin.add_theme_constant_override("margin_bottom", 12)
	attributes_panel.add_child(attributes_margin)
	var attributes_row := HBoxContainer.new()
	attributes_row.add_theme_constant_override("separation", 14)
	attributes_margin.add_child(attributes_row)
	attributes_row.add_child(_build_readonly_a_stat_panel(confirm_a_value_labels, "最终 A 类属性"))
	attributes_row.add_child(_build_readonly_b_stat_panel(confirm_b_value_labels, SOURCE_CONTEXT_CONFIRM, "最终 B 类属性"))
	_insert_before_child(confirm_stack, attributes_panel, confirm_footer)

func _build_selection_card(title_text: String, description_text: String, button_text: String, callback: Callable, button_lookup: Dictionary, lookup_key: String, minimum_size: Vector2 = Vector2(0.0, 150.0), selection_type: String = "") -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = minimum_size
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var title_label := Label.new()
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", 22)
	stack.add_child(title_label)

	var description_label := Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.text = description_text
	stack.add_child(description_label)

	var select_button := Button.new()
	select_button.text = button_text
	select_button.custom_minimum_size = Vector2(0.0, 44.0)
	select_button.pressed.connect(callback)
	stack.add_child(select_button)
	button_lookup[lookup_key] = select_button
	if selection_type != "":
		_bind_creation_selection_hover(card, selection_type, lookup_key)
		_bind_creation_selection_hover(select_button, selection_type, lookup_key)
	return card


func _build_step_2_layout() -> void:
	var row := _create_dual_column_row()
	step_2_content_stack.add_child(row)

	var selected_panel := _create_options_section("已选特性槽位")
	selected_panel.custom_minimum_size = Vector2(280.0, 0.0)
	var selected_content: VBoxContainer = selected_panel.get_meta("content")
	selected_content.add_child(_create_hint_label("左侧槽位是当前正式结果。双击已选特性可卸下，也可以拖回右侧候选区。"))
	for slot_index in range(2):
		var trait_id := str(selected_trait_slots[slot_index])
		selected_content.add_child(_build_creation_drag_card(
			"trait_slot",
			trait_id,
			{"slot_index": slot_index, "selection_type": "trait"},
			_build_trait_slot_view_data(slot_index, trait_id)
		))
	row.add_child(selected_panel)

	var pool_panel := _create_options_section("可选特性池")
	var pool_content: VBoxContainer = pool_panel.get_meta("content")
	pool_content.add_child(_create_hint_label("双击候选特性会进入左侧第一个空槽；拖到指定空槽可直接定向放入。"))
	pool_content.add_child(_build_creation_drag_card(
		"trait_pool",
		"",
		{"selection_type": "trait"},
		{
			"title": "候选池",
			"summary": "把左侧已选特性拖回这里可取消选择。",
			"badge": "移出区",
			"footer": "",
			"empty_state": true,
			"draggable": false,
		}
	))
	for section_title in ["职业相关特性", "通用特性"]:
		var candidate_ids := _get_trait_candidate_ids(section_title)
		pool_content.add_child(_create_subsection_label(section_title))
		if candidate_ids.is_empty():
			pool_content.add_child(_create_hint_label("当前没有可放入左侧槽位的条目。"))
			continue
		var grid := _create_card_grid(2)
		pool_content.add_child(grid)
		for trait_id in candidate_ids:
			grid.add_child(_build_creation_drag_card(
				"trait_candidate",
				trait_id,
				{"selection_type": "trait"},
				_build_registry_entry_view_data("trait", trait_id, "候选")
			))
	row.add_child(pool_panel)


func _build_step_3_layout() -> void:
	var row := _create_dual_column_row()
	step_3_content_stack.add_child(row)

	var selected_panel := _create_options_section("已选结果")
	selected_panel.custom_minimum_size = Vector2(300.0, 0.0)
	var selected_content: VBoxContainer = selected_panel.get_meta("content")
	selected_content.add_child(_create_hint_label("左侧两个槽位分别代表特长与缺点，右侧候选项不会重复显示已入槽内容。"))
	selected_content.add_child(_build_creation_drag_card(
		"strength_slot",
		selected_strength_id,
		{"selection_type": "strength"},
		_build_single_selection_slot_view_data("特长槽", "strength", selected_strength_id, "双击或拖回右侧可卸下。")
	))
	selected_content.add_child(_build_creation_drag_card(
		"weakness_slot",
		selected_weakness_id,
		{"selection_type": "weakness"},
		_build_single_selection_slot_view_data("缺点槽", "weakness", selected_weakness_id, "双击或拖回右侧可卸下。")
	))
	row.add_child(selected_panel)

	var pool_panel := _create_options_section("候选池")
	var pool_content: VBoxContainer = pool_panel.get_meta("content")
	pool_content.add_child(_create_hint_label("双击或拖拽候选项进入对应槽位。特长和缺点的目标槽位不会混用。"))
	pool_content.add_child(_build_creation_drag_card(
		"strength_pool",
		"",
		{"selection_type": "strength"},
		{
			"title": "特长候选区",
			"summary": "把左侧已选特长拖回这里可取消选择。",
			"badge": "移出区",
			"empty_state": true,
			"draggable": false,
		}
	))
	_append_selection_candidate_grid(pool_content, "特长", CharacterCreationRegistry.get_strength_ids(), selected_strength_id, "strength_candidate", "strength")
	pool_content.add_child(_build_creation_drag_card(
		"weakness_pool",
		"",
		{"selection_type": "weakness"},
		{
			"title": "缺点候选区",
			"summary": "把左侧已选缺点拖回这里可取消选择。",
			"badge": "移出区",
			"empty_state": true,
			"draggable": false,
		}
	))
	_append_selection_candidate_grid(pool_content, "缺点", CharacterCreationRegistry.get_weakness_ids(), selected_weakness_id, "weakness_candidate", "weakness")
	row.add_child(pool_panel)


func _build_step_4_layout() -> void:
	var panel := _create_options_section("性格卡片")
	var content: VBoxContainer = panel.get_meta("content")
	content.add_child(_create_hint_label("横向卡片是唯一点击入口，单击或双击即可设为当前性格。"))
	var grid := _create_card_grid(3)
	content.add_child(grid)
	for personality_id in CharacterCreationRegistry.get_personality_ids():
		var config := CharacterCreationRegistry.get_personality(personality_id)
		grid.add_child(_build_creation_drag_card(
			"personality_choice",
			personality_id,
			{"selection_type": "personality"},
			{
				"title": str(config.get("display_name", personality_id)),
				"summary": str(config.get("summary", "")),
				"badge": "已选" if personality_id == selected_personality_id else "性格",
				"footer": "单击设为当前性格",
				"selected_state": personality_id == selected_personality_id,
				"draggable": false,
				"single_click": true,
			}
		))
	step_4_content_stack.add_child(panel)


func _build_step_5_layout() -> void:
	var panel := _create_options_section("重生职业卡片")
	var content: VBoxContainer = panel.get_meta("content")
	content.add_child(_create_hint_label("横向职业卡片会直接写入正式职业字段，并同步影响确认页与起始技能预览。"))
	var grid := _create_card_grid(3)
	content.add_child(grid)
	for job_id in CharacterCreationRegistry.get_reborn_job_ids():
		var config := CharacterCreationRegistry.get_reborn_job(job_id)
		grid.add_child(_build_creation_drag_card(
			"reborn_job_choice",
			job_id,
			{"selection_type": "reborn_job"},
			{
				"title": str(config.get("display_name", job_id)),
				"summary": str(config.get("description", "")),
				"badge": "已选" if job_id == selected_class_id else "职业",
				"footer": _build_skill_preview_text(job_id),
				"selected_state": job_id == selected_class_id,
				"draggable": false,
				"single_click": true,
			}
		))
	step_5_content_stack.add_child(panel)


func _build_creation_drag_card(role: String, entry_id: String, payload: Dictionary, view_data: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.set_script(DragCardScript)
	card.custom_minimum_size = view_data.get("minimum_size", Vector2(0.0, 120.0))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.setup(
		self,
		role,
		entry_id,
		payload,
		bool(view_data.get("draggable", true)),
		bool(view_data.get("single_click", false))
	)
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


func _build_trait_slot_view_data(slot_index: int, trait_id: String) -> Dictionary:
	if trait_id.is_empty():
		return {
			"title": "槽位 %d" % [slot_index + 1],
			"summary": "空槽。把右侧候选特性拖到这里，或双击候选特性自动填入空槽。",
			"badge": "空槽",
			"footer": "当前最多可配置 2 个特性",
			"empty_state": true,
			"draggable": false,
		}
	var config := CharacterCreationRegistry.get_trait(trait_id)
	return {
		"title": str(config.get("display_name", trait_id)),
		"summary": str(config.get("summary", "")),
		"badge": "槽位 %d" % [slot_index + 1],
		"footer": "双击可卸下，或拖回右侧候选区",
		"selected_state": true,
	}


func _build_single_selection_slot_view_data(slot_title: String, selection_type: String, selection_id: String, footer_text: String) -> Dictionary:
	if selection_id.is_empty():
		return {
			"title": slot_title,
			"summary": "当前未选择。请从右侧候选池装入匹配项。",
			"badge": "空槽",
			"footer": footer_text,
			"empty_state": true,
			"draggable": false,
		}
	var config := CharacterCreationRegistry.get_selection_config(selection_type, selection_id)
	return {
		"title": str(config.get("display_name", selection_id)),
		"summary": str(config.get("summary", "")),
		"badge": slot_title,
		"footer": footer_text,
		"selected_state": true,
	}


func _build_registry_entry_view_data(selection_type: String, selection_id: String, badge_text: String = "") -> Dictionary:
	var config := CharacterCreationRegistry.get_selection_config(selection_type, selection_id)
	return {
		"title": str(config.get("display_name", selection_id)),
		"summary": str(config.get("summary", config.get("description", ""))),
		"badge": badge_text,
		"footer": "双击或拖拽放入左侧槽位",
	}


func _append_selection_candidate_grid(parent: VBoxContainer, title_text: String, candidate_ids: Array[String], selected_id: String, role: String, selection_type: String) -> void:
	parent.add_child(_create_subsection_label(title_text))
	var filtered_ids: Array[String] = []
	for entry_id in candidate_ids:
		if entry_id != selected_id:
			filtered_ids.append(entry_id)
	if filtered_ids.is_empty():
		parent.add_child(_create_hint_label("当前没有未配置的%s候选。" % title_text))
		return
	var grid := _create_card_grid(2)
	parent.add_child(grid)
	for entry_id in filtered_ids:
		grid.add_child(_build_creation_drag_card(
			role,
			entry_id,
			{"selection_type": selection_type},
			_build_registry_entry_view_data(selection_type, entry_id, "候选")
		))


func _get_trait_candidate_ids(section_title: String) -> Array[String]:
	var candidate_ids: Array[String] = []
	for trait_id in CharacterCreationRegistry.get_trait_ids():
		var config := CharacterCreationRegistry.get_trait(trait_id)
		if str(config.get("category", "通用特性")) != section_title:
			continue
		if not CharacterCreationRegistry.is_trait_available_for_past_life(trait_id, selected_background_id):
			continue
		if selected_trait_ids.has(trait_id):
			continue
		candidate_ids.append(trait_id)
	return candidate_ids


func _create_dual_column_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	return row


func _create_card_grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	return grid


func _create_hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _create_subsection_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label


func notify_drag_card_started() -> void:
	_hide_hover_detail()


func handle_drag_card_hover(is_entering: bool, card_role: String, card_id: String, card_payload: Dictionary, anchor_control: Control) -> void:
	var hover_type := ""
	var hover_id := card_id
	match card_role:
		"trait_candidate", "trait_slot":
			hover_type = "trait"
		"strength_candidate", "strength_slot":
			hover_type = "strength"
		"weakness_candidate", "weakness_slot":
			hover_type = "weakness"
		"personality_choice":
			hover_type = "personality"
		"reborn_job_choice":
			hover_type = "reborn_job"
		_:
			hover_type = ""
	if hover_type == "" or hover_id.is_empty():
		if not is_entering:
			_hide_hover_detail()
		return
	if is_entering:
		_on_creation_selection_mouse_entered(anchor_control, hover_type, hover_id)
	else:
		_on_creation_selection_mouse_exited(hover_type, hover_id)


func handle_drag_card_single_click(card_role: String, card_id: String, _card_payload: Dictionary) -> void:
	match card_role:
		"personality_choice":
			select_personality(card_id)
		"reborn_job_choice":
			select_reborn_job(card_id)


func handle_drag_card_double_click(card_role: String, card_id: String, card_payload: Dictionary) -> void:
	var changed := false
	match card_role:
		"trait_candidate":
			changed = _assign_trait_to_slot(card_id)
		"trait_slot":
			changed = _remove_trait_from_slot(int(card_payload.get("slot_index", -1)))
		"strength_candidate":
			if card_id != selected_strength_id:
				selected_strength_id = card_id
				changed = true
		"weakness_candidate":
			if card_id != selected_weakness_id:
				selected_weakness_id = card_id
				changed = true
		"strength_slot":
			if not selected_strength_id.is_empty():
				selected_strength_id = ""
				changed = true
		"weakness_slot":
			if not selected_weakness_id.is_empty():
				selected_weakness_id = ""
				changed = true
		"personality_choice":
			select_personality(card_id)
			return
		"reborn_job_choice":
			select_reborn_job(card_id)
			return
	if not changed:
		return
	removed_trait_notice = ""
	_recalculate_creation_state()
	_refresh_all_pages()


func can_drop_on_drag_card(card_role: String, _card_id: String, card_payload: Dictionary, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var source_role := str(data.get("card_role", ""))
	var source_id := str(data.get("card_id", ""))
	match card_role:
		"trait_slot":
			return source_role == "trait_candidate" and not source_id.is_empty() and str(selected_trait_slots[int(card_payload.get("slot_index", -1))]).is_empty()
		"trait_pool":
			return source_role == "trait_slot"
		"strength_slot":
			return source_role == "strength_candidate"
		"weakness_slot":
			return source_role == "weakness_candidate"
		"strength_pool":
			return source_role == "strength_slot"
		"weakness_pool":
			return source_role == "weakness_slot"
	return false


func handle_drop_on_drag_card(card_role: String, _card_id: String, card_payload: Dictionary, data: Variant) -> void:
	if not can_drop_on_drag_card(card_role, _card_id, card_payload, data):
		return
	var source_role := str(data.get("card_role", ""))
	var source_id := str(data.get("card_id", ""))
	var changed := false
	match card_role:
		"trait_slot":
			changed = _assign_trait_to_slot(source_id, int(card_payload.get("slot_index", -1)))
		"trait_pool":
			if source_role == "trait_slot":
				changed = _remove_trait_from_slot(int((data.get("payload", {}) as Dictionary).get("slot_index", -1)))
		"strength_slot":
			selected_strength_id = source_id
			changed = true
		"weakness_slot":
			selected_weakness_id = source_id
			changed = true
		"strength_pool":
			if source_role == "strength_slot" and not selected_strength_id.is_empty():
				selected_strength_id = ""
				changed = true
		"weakness_pool":
			if source_role == "weakness_slot" and not selected_weakness_id.is_empty():
				selected_weakness_id = ""
				changed = true
	if not changed:
		return
	removed_trait_notice = ""
	_recalculate_creation_state()
	_refresh_all_pages()


func _ensure_scrollable_step_content(container: VBoxContainer, footer: Control, preserved_nodes: Array, scroll_name: String, stack_name: String) -> VBoxContainer:
	var content_scroll: ScrollContainer = container.get_node_or_null(scroll_name)
	if content_scroll == null:
		content_scroll = ScrollContainer.new()
		content_scroll.name = scroll_name
		content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_scroll.custom_minimum_size = Vector2(0.0, STEP_SCROLL_MIN_HEIGHT)
		_insert_before_child(container, content_scroll, footer)

	var content_stack: VBoxContainer = content_scroll.get_node_or_null(stack_name)
	if content_stack == null:
		content_stack = VBoxContainer.new()
		content_stack.name = stack_name
		content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_stack.add_theme_constant_override("separation", 12)
		content_scroll.add_child(content_stack)

	for child in container.get_children():
		if child == footer or child == content_scroll:
			continue
		if preserved_nodes.has(child):
			continue
		if child.get_parent() == container:
			container.remove_child(child)
			content_stack.add_child(child)

	return content_stack


func _clear_scrollable_content(content_stack: VBoxContainer) -> void:
	if content_stack == null:
		return
	for child in content_stack.get_children():
		child.queue_free()


func _bind_creation_selection_hover(target_control: Control, selection_type: String, selection_id: String) -> void:
	if target_control == null or selection_type == "" or selection_id == "":
		return
	target_control.mouse_entered.connect(_on_creation_selection_mouse_entered.bind(target_control, selection_type, selection_id))
	target_control.mouse_exited.connect(_on_creation_selection_mouse_exited.bind(selection_type, selection_id))


func _on_creation_selection_mouse_entered(target_control: Control, selection_type: String, selection_id: String) -> void:
	if hover_detail_manager == null:
		return
	var source_id := "%s:%s" % [selection_type, selection_id]
	hover_detail_manager.request_hover(
		HOVER_SOURCE_CREATION_SELECTION,
		source_id,
		target_control,
		Callable(self, "_build_creation_selection_hover_context").bind(selection_type, selection_id),
		"target"
	)


func _on_creation_selection_mouse_exited(selection_type: String, selection_id: String) -> void:
	if hover_detail_manager == null:
		return
	hover_detail_manager.clear_hover("%s:%s" % [selection_type, selection_id])


func _build_creation_selection_hover_context(selection_type: String, selection_id: String) -> Dictionary:
	return {
		"selection_type": selection_type,
		"selection_id": selection_id,
		"selection_state": _build_selection_state(),
		"source_context": "角色创建",
	}


func _create_options_section(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	var title_label := Label.new()
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", 22)
	stack.add_child(title_label)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	stack.add_child(content)
	panel.set_meta("content", content)
	return panel


func _create_summary_panel(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var title_label := Label.new()
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", 22)
	stack.add_child(title_label)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	stack.add_child(content)
	panel.set_meta("content", content)
	return panel


func _add_summary_line(parent: VBoxContainer, title_text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var title_label := Label.new()
	title_label.text = "%s：" % title_text
	title_label.custom_minimum_size = Vector2(110.0, 0.0)
	row.add_child(title_label)

	var value_label := Label.new()
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_label)
	return value_label


func _build_readonly_a_stat_panel(target_labels: Dictionary, panel_title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var title_label := Label.new()
	title_label.text = panel_title
	title_label.add_theme_font_size_override("font_size", 20)
	stack.add_child(title_label)

	for stat_definition in A_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		stack.add_child(row)

		var name_label := Label.new()
		name_label.text = str(stat_definition["label"])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var value_label := Label.new()
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		target_labels[stat_key] = value_label

	return panel


func _build_readonly_b_stat_panel(target_labels: Dictionary, source_context: String, panel_title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	var title_label := Label.new()
	title_label.text = panel_title
	title_label.add_theme_font_size_override("font_size", 20)
	stack.add_child(title_label)

	var hint_label := Label.new()
	hint_label.text = "提示：悬停单条属性块可查看实时公式。"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(hint_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	stack.add_child(grid)

	for stat_definition in B_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		grid.add_child(_create_b_stat_block(str(stat_definition["label"]), stat_key, target_labels, source_context))

	return panel


func _create_b_stat_block(title_text: String, stat_key: String, target_labels: Dictionary, source_context: String) -> PanelContainer:
	var block := PanelContainer.new()
	block.custom_minimum_size = Vector2(150.0, 70.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	block.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)

	var title_label := Label.new()
	title_label.text = title_text
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title_label)

	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(value_label)
	target_labels[stat_key] = value_label

	_mark_b_stat_hover_target(block, stat_key, source_context)
	return block


func _build_stat_rows() -> void:
	for child in a_stats_container.get_children():
		child.queue_free()
	for child in b_stats_container.get_children():
		child.queue_free()
	spinboxes_by_stat.clear()
	b_value_labels.clear()

	for stat_definition in A_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)

		var stat_label := Label.new()
		stat_label.text = str(stat_definition["label"])
		stat_label.custom_minimum_size = Vector2(140.0, 0.0)
		stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(stat_label)

		var stat_spinbox := SpinBox.new()
		stat_spinbox.min_value = 1
		stat_spinbox.max_value = 30
		stat_spinbox.step = 1
		stat_spinbox.allow_greater = false
		stat_spinbox.allow_lesser = false
		stat_spinbox.custom_minimum_size = Vector2(110.0, 0.0)
		stat_spinbox.value_changed.connect(_on_a_stat_spinbox_value_changed.bind(stat_key))
		row.add_child(stat_spinbox)

		spinboxes_by_stat[stat_key] = stat_spinbox
		a_stats_container.add_child(row)

	for stat_definition in B_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		var row := PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 6)
		row.add_child(margin)

		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 12)
		margin.add_child(content)

		var stat_label := Label.new()
		stat_label.text = str(stat_definition["label"])
		stat_label.custom_minimum_size = Vector2(150.0, 0.0)
		stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(stat_label)

		var value_label := Label.new()
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.custom_minimum_size = Vector2(110.0, 0.0)
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(value_label)

		b_value_labels[stat_key] = value_label
		_mark_b_stat_hover_target(row, stat_key, SOURCE_CONTEXT_STEP_6)
		b_stats_container.add_child(row)

func _mark_b_stat_hover_target(target_control: Control, stat_key: String, source_context: String) -> void:
	target_control.mouse_filter = Control.MOUSE_FILTER_STOP
	target_control.set_meta(HOVER_META_STAT_ID, stat_key)
	target_control.set_meta(HOVER_META_SOURCE_CONTEXT, source_context)
	target_control.mouse_entered.connect(_on_marked_b_stat_mouse_entered.bind(target_control))
	target_control.mouse_exited.connect(_on_marked_b_stat_mouse_exited.bind(target_control))


func _show_step(step: int) -> void:
	current_step = step
	_hide_hover_detail()
	step_1_page.visible = step == 1
	step_2_page.visible = step == 2
	step_3_page.visible = step == 3
	step_4_page.visible = step == 4
	step_5_page.visible = step == 5
	step_6_page.visible = step == 6
	confirm_page.visible = step == 7

	match step:
		1:
			_refresh_step_1_page()
			class_scroll.scroll_horizontal = 0
		2:
			_refresh_step_2_page()
		3:
			_refresh_step_3_page()
		4:
			_refresh_step_4_page()
		5:
			_refresh_step_5_page()
		6:
			_refresh_attribute_page()
		7:
			_refresh_confirmation_page()


func _refresh_all_pages() -> void:
	_refresh_step_1_page()
	_refresh_step_2_page()
	_refresh_step_3_page()
	_refresh_step_4_page()
	_refresh_step_5_page()
	_refresh_attribute_page()
	_refresh_confirmation_page()


func _refresh_step_1_page() -> void:
	step_1_next_button.disabled = selected_background_id == ""
	for past_life_id in past_life_button_by_id.keys():
		var button: Button = past_life_button_by_id[past_life_id]
		var config := CharacterCreationRegistry.get_past_life(str(past_life_id))
		var display_name := str(config.get("display_name", past_life_id))
		button.text = "已选择%s" % display_name if str(past_life_id) == selected_background_id else "选择%s" % display_name
	if selected_background_id == "":
		class_status_label.text = "当前未选择前世职业。请选择 1 个前世职业后再进入下一步。"
	else:
		var config := CharacterCreationRegistry.get_past_life(selected_background_id)
		class_status_label.text = "当前前世职业：%s\n%s" % [str(config.get("display_name", selected_background_id)), str(config.get("description", ""))]


func _refresh_step_2_page() -> void:
	step_2_next_button.disabled = selected_trait_ids.size() != 2
	_clear_scrollable_content(step_2_content_stack)
	_build_step_2_layout()
	if step_2_status_label == null:
		return
	var status_lines: Array[String] = []
	status_lines.append("已选择特性：%d / 2" % selected_trait_ids.size())
	if selected_background_id == "":
		status_lines.append("请先回到上一步选择前世职业。")
	elif not removed_trait_notice.is_empty():
		status_lines.append(removed_trait_notice)
	else:
		status_lines.append("当前职业相关特性已按前世职业刷新。")
	step_2_status_label.text = "\n".join(status_lines)


func _refresh_step_3_page() -> void:
	step_3_next_button.disabled = not _is_step_3_valid()
	_clear_scrollable_content(step_3_content_stack)
	_build_step_3_layout()
	if step_3_status_label != null:
		step_3_status_label.text = "当前特长：%s | 当前缺点：%s" % [_display_name_or_default(CharacterCreationRegistry.get_strength(selected_strength_id), "未选择"), _display_name_or_default(CharacterCreationRegistry.get_weakness(selected_weakness_id), "未选择")]


func _refresh_step_4_page() -> void:
	step_4_next_button.disabled = selected_personality_id == ""
	_clear_scrollable_content(step_4_content_stack)
	_build_step_4_layout()
	if step_4_status_label != null:
		step_4_status_label.text = "当前性格：%s" % _display_name_or_default(CharacterCreationRegistry.get_personality(selected_personality_id), "未选择")


func _refresh_step_5_page() -> void:
	step_5_next_button.disabled = selected_class_id == ""
	_clear_scrollable_content(step_5_content_stack)
	_build_step_5_layout()
	if step_5_status_label != null:
		step_5_status_label.text = "当前重生职业：%s\n当前技能：%s" % [_display_name_or_default(CharacterCreationRegistry.get_reborn_job(selected_class_id), "未选择"), _build_skill_preview_text(selected_class_id)]


func _refresh_attribute_page() -> void:
	var job_config := CharacterCreationRegistry.get_reborn_job(selected_class_id)
	selected_class_name_label.text = str(job_config.get("display_name", "未选择重生职业"))
	selected_class_description_label.text = str(job_config.get("description", "请先完成前面的正式创建步骤。"))
	portrait_name_label.text = str(job_config.get("display_name", "未选择"))
	level_label.text = "等级：%d" % current_level
	points_value_label.text = str(remaining_bonus_points)
	_update_total_characters_label()

	for stat_definition in A_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		var stat_spinbox: SpinBox = spinboxes_by_stat[stat_key]
		var base_value := int(base_a_stats.get(stat_key, 1))
		var current_value := int(current_a_stats.get(stat_key, base_value))
		stat_spinbox.min_value = base_value
		stat_spinbox.max_value = base_value + CharacterCreationRegistry.get_reborn_job_bonus_points(selected_class_id)
		stat_spinbox.set_block_signals(true)
		stat_spinbox.value = current_value
		stat_spinbox.set_block_signals(false)

	_update_b_stats_display()


func _refresh_confirmation_page() -> void:
	var summary := CharacterCreationRegistry.build_preview_summary(_build_selection_state())
	confirm_summary_label.text = "前世职业：%s | 重生职业：%s | 等级：%d | 剩余点数：%d" % [str(summary.get("past_life_name", "未选择")), str(summary.get("reborn_job_name", "未选择")), current_level, remaining_bonus_points]
	if confirm_identity_labels.has("past_life"):
		confirm_identity_labels["past_life"].text = str(summary.get("past_life_name", "未选择"))
		confirm_identity_labels["traits"].text = ", ".join(summary.get("trait_names", [])) if not (summary.get("trait_names", []) as Array).is_empty() else "未选择"
		confirm_identity_labels["strength"].text = str(summary.get("strength_name", "未选择"))
		confirm_identity_labels["weakness"].text = str(summary.get("weakness_name", "未选择"))
		confirm_identity_labels["personality"].text = str(summary.get("personality_name", "未选择"))
	if confirm_job_labels.has("reborn_job"):
		confirm_job_labels["reborn_job"].text = str(summary.get("reborn_job_name", "未选择"))
		confirm_job_labels["level"].text = str(current_level)
	if confirm_skill_list_label != null:
		confirm_skill_list_label.text = _build_skill_preview_text(selected_class_id)
	_refresh_readonly_a_labels(confirm_a_value_labels)
	_refresh_readonly_b_labels(confirm_b_value_labels, _get_current_b_stats())


func _refresh_readonly_a_labels(target_labels: Dictionary) -> void:
	for stat_definition in A_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		if target_labels.has(stat_key):
			target_labels[stat_key].text = str(int(current_a_stats.get(stat_key, 0)))


func _refresh_readonly_b_labels(target_labels: Dictionary, b_stats: Dictionary) -> void:
	for stat_definition in B_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		if target_labels.has(stat_key):
			target_labels[stat_key].text = _format_b_stat_value(stat_key, float(b_stats.get(stat_key, 0.0)))


func _update_b_stats_display() -> void:
	var b_stats: Dictionary = _get_current_b_stats()
	for stat_definition in B_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		var value_label: Label = b_value_labels[stat_key]
		value_label.text = _format_b_stat_value(stat_key, float(b_stats.get(stat_key, 0.0)))


func _get_current_b_stats() -> Dictionary:
	return CharacterStats.calculate_b_stats(current_a_stats)


func _format_b_stat_value(stat_key: String, stat_value: float) -> String:
	return CharacterStats.format_b_stat_value(stat_key, stat_value)


func _recalculate_creation_state() -> void:
	var selected_job_id := selected_class_id
	if CharacterCreationRegistry.get_reborn_job(selected_job_id).is_empty():
		selected_job_id = CharacterCreationRegistry.get_default_reborn_job_id()
	selected_class_id = selected_job_id
	var rebuilt_base := CharacterCreationRegistry.get_reborn_job_base_a(selected_job_id)
	var selection_modifiers := CharacterCreationRegistry.build_selection_a_modifiers(_build_selection_state())
	for stat_definition in A_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		rebuilt_base[stat_key] = max(1, int(rebuilt_base.get(stat_key, 1)) + int(selection_modifiers.get(stat_key, 0)))
	base_a_stats = rebuilt_base

	var point_budget: int = CharacterCreationRegistry.get_reborn_job_bonus_points(selected_job_id)
	var adjusted_allocations: Dictionary = {}
	var spent_points: int = 0
	for stat_definition in A_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		var allocation_value: int = max(0, int(allocated_bonus_by_stat.get(stat_key, 0)))
		var remaining_budget: int = max(0, point_budget - spent_points)
		var applied_value: int = min(allocation_value, remaining_budget)
		adjusted_allocations[stat_key] = applied_value
		spent_points += applied_value
	allocated_bonus_by_stat = adjusted_allocations
	remaining_bonus_points = max(0, point_budget - spent_points)

	current_a_stats.clear()
	for stat_definition in A_STAT_ORDER:
		var stat_key := str(stat_definition["key"])
		current_a_stats[stat_key] = int(base_a_stats.get(stat_key, 1)) + int(allocated_bonus_by_stat.get(stat_key, 0))


func _sanitize_selected_traits() -> Array[String]:
	var removed_traits: Array[String] = []
	var sanitized_slots: Array[String] = ["", ""]
	var insert_index := 0
	for trait_id in selected_trait_slots:
		if trait_id.is_empty():
			continue
		if CharacterCreationRegistry.is_trait_available_for_past_life(trait_id, selected_background_id):
			if insert_index < sanitized_slots.size():
				sanitized_slots[insert_index] = trait_id
				insert_index += 1
		else:
			removed_traits.append(trait_id)
	selected_trait_slots = sanitized_slots
	_sync_selected_trait_ids_from_slots()
	return removed_traits


func _sync_selected_trait_ids_from_slots() -> void:
	selected_trait_ids.clear()
	for trait_id in selected_trait_slots:
		if not trait_id.is_empty() and not selected_trait_ids.has(trait_id):
			selected_trait_ids.append(trait_id)


func _assign_trait_to_slot(trait_id: String, requested_slot_index: int = -1) -> bool:
	if trait_id.is_empty():
		return false
	if not CharacterCreationRegistry.is_trait_available_for_past_life(trait_id, selected_background_id):
		return false
	var working_slots := selected_trait_slots.duplicate()
	var existing_slot := working_slots.find(trait_id)
	if requested_slot_index < 0:
		requested_slot_index = working_slots.find("")
	if requested_slot_index < 0 or requested_slot_index >= working_slots.size():
		return false
	if existing_slot == requested_slot_index:
		return true
	if not str(working_slots[requested_slot_index]).is_empty() and existing_slot == -1:
		return false
	if existing_slot != -1:
		working_slots[existing_slot] = ""
	working_slots[requested_slot_index] = trait_id
	selected_trait_slots = working_slots
	_sync_selected_trait_ids_from_slots()
	return true


func _remove_trait_from_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= selected_trait_slots.size():
		return false
	if str(selected_trait_slots[slot_index]).is_empty():
		return false
	selected_trait_slots[slot_index] = ""
	var compacted_slots: Array[String] = ["", ""]
	var insert_index := 0
	for trait_id in selected_trait_slots:
		if trait_id.is_empty():
			continue
		compacted_slots[insert_index] = trait_id
		insert_index += 1
	selected_trait_slots = compacted_slots
	_sync_selected_trait_ids_from_slots()
	return true


func _remove_trait_from_slot_by_id(trait_id: String) -> bool:
	var slot_index := selected_trait_slots.find(trait_id)
	if slot_index == -1:
		return false
	return _remove_trait_from_slot(slot_index)

func _build_selection_state() -> Dictionary:
	return {
		"past_life_id": selected_background_id,
		"trait_ids": selected_trait_ids.duplicate(),
		"strength_id": selected_strength_id,
		"weakness_id": selected_weakness_id,
		"personality_id": selected_personality_id,
		"reborn_job_id": selected_class_id,
	}


func _build_created_character_data() -> Dictionary:
	var past_life_config := CharacterCreationRegistry.get_past_life(selected_background_id)
	var reborn_job_config := CharacterCreationRegistry.get_reborn_job(selected_class_id)
	var selection_state := _build_selection_state()
	var starting_skill_ids: Array[String] = []
	for skill_entry in CharacterCreationRegistry.get_reborn_job_starting_skills(selected_class_id):
		var skill_id := str((skill_entry as Dictionary).get("id", (skill_entry as Dictionary).get("skill_id", "")))
		if skill_id.is_empty() or starting_skill_ids.has(skill_id):
			continue
		starting_skill_ids.append(skill_id)
	return {
		"past_life_id": selected_background_id,
		"past_life_name": str(past_life_config.get("display_name", "")),
		"background_id": selected_background_id,
		"background_name": str(past_life_config.get("display_name", "")),
		"trait_ids": selected_trait_ids.duplicate(),
		"trait_names": _collect_names_from_ids(selected_trait_ids, "trait"),
		"strength_id": selected_strength_id,
		"strength_name": _display_name_or_default(CharacterCreationRegistry.get_strength(selected_strength_id), ""),
		"weakness_id": selected_weakness_id,
		"weakness_name": _display_name_or_default(CharacterCreationRegistry.get_weakness(selected_weakness_id), ""),
		"personality_id": selected_personality_id,
		"personality_name": _display_name_or_default(CharacterCreationRegistry.get_personality(selected_personality_id), ""),
		"reborn_job_id": selected_class_id,
		"reborn_job_name": str(reborn_job_config.get("display_name", "")),
		"class_id": selected_class_id,
		"class_name": str(reborn_job_config.get("display_name", "")),
		"profile_tags": CharacterCreationRegistry.build_profile_tags(selection_state),
		"level": current_level,
		"a_stats": current_a_stats.duplicate(true),
		"b_stats": _get_current_b_stats(),
		"owned_skill_ids": starting_skill_ids.duplicate(),
		"equipped_skill_ids": [starting_skill_ids[0]] if not starting_skill_ids.is_empty() else [],
		"skill_state_overrides": {},
	}


func _build_skill_preview_text(job_id: String) -> String:
	var skill_entries := CharacterCreationRegistry.get_reborn_job_starting_skills(job_id)
	if skill_entries.is_empty():
		return "未配置"
	var lines: Array[String] = []
	for skill_entry in skill_entries:
		lines.append("%s：%s" % [str(skill_entry.get("display_name", skill_entry.get("id", ""))), str(skill_entry.get("summary", ""))])
	return "\n".join(lines)


func _collect_names_from_ids(ids: Array[String], entry_type: String) -> Array[String]:
	var names: Array[String] = []
	for entry_id in ids:
		var config := _get_registry_entry(entry_type, entry_id)
		if not config.is_empty():
			names.append(str(config.get("display_name", entry_id)))
	return names


func _get_registry_entry(entry_type: String, entry_id: String) -> Dictionary:
	match entry_type:
		"trait":
			return CharacterCreationRegistry.get_trait(entry_id)
		"strength":
			return CharacterCreationRegistry.get_strength(entry_id)
		"weakness":
			return CharacterCreationRegistry.get_weakness(entry_id)
		"personality":
			return CharacterCreationRegistry.get_personality(entry_id)
	return {}


func _display_name_or_default(config: Dictionary, fallback: String) -> String:
	if config.is_empty():
		return fallback
	return str(config.get("display_name", fallback))


func _update_total_characters_label() -> void:
	total_characters_label.text = "已创建人物：%d" % player_characters.size()


func _insert_before_child(parent: Control, child: Control, before_child: Control) -> void:
	parent.add_child(child)
	parent.move_child(child, before_child.get_index())


func _clear_container_before_footer(container: VBoxContainer, footer: Control, preserved_nodes: Array) -> void:
	for child in container.get_children():
		if child == footer:
			continue
		if preserved_nodes.has(child):
			continue
		child.queue_free()


func _ensure_title_label(container: VBoxContainer, anchor_label: Label, title_text: String) -> Label:
	var title_label: Label = null
	for child in container.get_children():
		if child is Label and str(child.name) == "%sTitleLabel" % str(anchor_label.name):
			title_label = child
			break
	if title_label == null:
		title_label = Label.new()
		title_label.name = "%sTitleLabel" % str(anchor_label.name)
		title_label.add_theme_font_size_override("font_size", 30)
		_insert_before_child(container, title_label, anchor_label)
	title_label.text = title_text
	return title_label


func _hide_hover_detail() -> void:
	if hover_detail_manager != null:
		hover_detail_manager.hide_immediately()


func _on_marked_b_stat_mouse_entered(target_control: Control) -> void:
	if hover_detail_manager == null:
		return
	var stat_key := str(target_control.get_meta(HOVER_META_STAT_ID, ""))
	var source_context := str(target_control.get_meta(HOVER_META_SOURCE_CONTEXT, ""))
	if stat_key == "" or source_context == "":
		return
	hover_detail_manager.request_hover("attribute_b_entry", "%s:%s" % [source_context, stat_key], target_control, Callable(self, "_build_creation_b_stat_hover_context").bind(stat_key, source_context), "target")


func _on_marked_b_stat_mouse_exited(target_control: Control) -> void:
	if hover_detail_manager == null:
		return
	var stat_key := str(target_control.get_meta(HOVER_META_STAT_ID, ""))
	var source_context := str(target_control.get_meta(HOVER_META_SOURCE_CONTEXT, ""))
	if stat_key == "" or source_context == "":
		return
	hover_detail_manager.clear_hover("%s:%s" % [source_context, stat_key])


func _build_creation_b_stat_hover_context(stat_key: String, source_context: String) -> Dictionary:
	return {
		"stat_key": stat_key,
		"current_b_stats": _get_current_b_stats(),
		"effective_a_stats": current_a_stats.duplicate(true),
		"source_context": source_context,
	}


func _on_warrior_card_button_pressed() -> void:
	select_past_life(CharacterCreationRegistry.get_past_life_ids().front())


func _on_a_stat_spinbox_value_changed(value: float, stat_key: String) -> void:
	var base_value: int = int(base_a_stats.get(stat_key, 1))
	var requested_value: int = max(base_value, int(round(value)))
	var previous_allocation: int = int(allocated_bonus_by_stat.get(stat_key, 0))
	var new_allocation: int = requested_value - base_value
	var point_budget: int = CharacterCreationRegistry.get_reborn_job_bonus_points(selected_class_id)
	var total_allocated: int = 0
	for key in allocated_bonus_by_stat.keys():
		if str(key) == stat_key:
			total_allocated += new_allocation
		else:
			total_allocated += int(allocated_bonus_by_stat[key])
	if total_allocated > point_budget:
		var stat_spinbox: SpinBox = spinboxes_by_stat[stat_key]
		stat_spinbox.set_block_signals(true)
		stat_spinbox.value = base_value + previous_allocation
		stat_spinbox.set_block_signals(false)
		return
	allocated_bonus_by_stat[stat_key] = new_allocation
	_recalculate_creation_state()
	_refresh_all_pages()


func _can_submit_creation() -> bool:
	return _is_step_1_valid() and _is_step_2_valid() and _is_step_3_valid() and _is_step_4_valid() and _is_step_5_valid()


func _is_step_1_valid() -> bool:
	return selected_background_id != ""


func _is_step_2_valid() -> bool:
	return selected_trait_ids.size() == 2


func _is_step_3_valid() -> bool:
	return selected_strength_id != "" and selected_weakness_id != ""


func _is_step_4_valid() -> bool:
	return selected_personality_id != ""


func _is_step_5_valid() -> bool:
	return selected_class_id != ""


func _on_past_life_button_pressed(past_life_id: String) -> void:
	select_past_life(past_life_id)


func _on_trait_checkbox_toggled(button_pressed: bool, trait_id: String) -> void:
	if button_pressed and selected_trait_ids.size() >= 2 and not selected_trait_ids.has(trait_id):
		var checkbox: CheckBox = trait_checkbox_by_id.get(trait_id)
		if checkbox != null:
			checkbox.set_pressed_no_signal(false)
		return
	toggle_trait(trait_id)


func _on_strength_button_pressed(strength_id: String) -> void:
	select_strength(strength_id)


func _on_weakness_button_pressed(weakness_id: String) -> void:
	select_weakness(weakness_id)


func _on_personality_button_pressed(personality_id: String) -> void:
	select_personality(personality_id)


func _on_reborn_job_button_pressed(job_id: String) -> void:
	select_reborn_job(job_id)


func _on_step_1_back_button_pressed() -> void:
	emit_signal("back_requested")


func _on_step_1_next_button_pressed() -> void:
	if not _is_step_1_valid():
		_refresh_step_1_page()
		return
	_show_step(2)


func _on_step_2_back_button_pressed() -> void:
	_show_step(1)


func _on_step_2_next_button_pressed() -> void:
	if not _is_step_2_valid():
		_refresh_step_2_page()
		return
	_show_step(3)


func _on_step_3_back_button_pressed() -> void:
	_show_step(2)


func _on_step_3_next_button_pressed() -> void:
	if not _is_step_3_valid():
		_refresh_step_3_page()
		return
	_show_step(4)


func _on_step_4_back_button_pressed() -> void:
	_show_step(3)


func _on_step_4_next_button_pressed() -> void:
	if not _is_step_4_valid():
		_refresh_step_4_page()
		return
	_show_step(5)


func _on_step_5_back_button_pressed() -> void:
	_show_step(4)


func _on_step_5_next_button_pressed() -> void:
	if not _is_step_5_valid():
		_refresh_step_5_page()
		return
	_show_step(6)


func _on_step_6_back_button_pressed() -> void:
	_show_step(5)


func _on_step_6_next_button_pressed() -> void:
	_show_step(7)


func _on_confirm_back_button_pressed() -> void:
	_show_step(6)


func _on_confirm_create_button_pressed() -> void:
	create_character_now()
