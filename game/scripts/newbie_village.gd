extends Node2D

const GameLayers = preload("res://game/scripts/game_layers.gd")
const CharacterStats = preload("res://game/scripts/character_stats.gd")
const ItemSystem = preload("res://game/scripts/item_system.gd")
const PlayerMenuSceneScript = preload("res://game/scripts/player_menu_ui_v2.gd")
const ChestMenuScript = preload("res://game/scripts/chest_menu_ui_v2.gd")
const HoverDetailManagerScript = preload("res://game/scripts/hover_detail_manager.gd")

signal stage_clear_placeholder_triggered

const METERS_TO_PIXELS := 16.0
const CORRIDOR_HEIGHT_METERS := 5.0
const ROOM_WALL_THICKNESS_METERS := 1.0
const ENEMY_SCENE_PATH := "res://game/scenes/enemy_actor.tscn"
const PROJECTILE_SCENE_PATH := "res://game/scenes/enemy_projectile.tscn"
const CHEST_SCENE_PATH := "res://game/scenes/chest_interactable_v2.tscn"
const NPC_DIALOGUE_SCENE_PATH := "res://game/scenes/npc_dialogue_interactor.tscn"
const MAIN_MENU_SCENE_PATH := "res://main_menu/scenes/main_menu.tscn"
const BLOCK_DAMAGE_MULTIPLIER := 0.5
const FLOATING_TEXT_LIFETIME := 0.75
const A_STAT_DISPLAY_ORDER := CharacterStats.A_STAT_ORDER
const B_STAT_DISPLAY_ORDER := CharacterStats.B_STAT_ORDER
const ROOM_DEFINITIONS := [
	{
		"id": "spawn",
		"name": "\u51fa\u751f\u623f",
		"center_meters": Vector2(14.0, 20.0),
		"size_meters": Vector2(18.0, 14.0),
		"theme_color": Color(0.16, 0.28, 0.18, 1.0),
		"enemies": [],
	},
	{
		"id": "trial_room_1",
		"name": "\u6218\u6597\u623f1 \u8fd1\u6218\u8bd5\u70bc",
		"center_meters": Vector2(40.0, 20.0),
		"size_meters": Vector2(18.0, 14.0),
		"theme_color": Color(0.28, 0.23, 0.18, 1.0),
		"enemies": [
			{"template_id": "melee_grunt", "ai_id": "enemy_melee_grunt_001", "faction_id": "enemy", "offset_meters": Vector2(0.0, 0.0)},
		],
	},
	{
		"id": "trial_room_2",
		"name": "\u6218\u6597\u623f2 \u6df7\u5408\u8bd5\u70bc",
		"center_meters": Vector2(66.0, 20.0),
		"size_meters": Vector2(18.0, 14.0),
		"theme_color": Color(0.19, 0.24, 0.34, 1.0),
		"enemies": [
			{"template_id": "melee_grunt", "ai_id": "enemy_melee_grunt_001", "faction_id": "enemy", "offset_meters": Vector2(-3.0, 1.5)},
			{"template_id": "ranged_grunt", "ai_id": "enemy_archer_001", "faction_id": "enemy", "offset_meters": Vector2(3.5, -1.5)},
		],
	},
	{
		"id": "boss_room",
		"name": "Boss \u623f",
		"center_meters": Vector2(96.0, 20.0),
		"size_meters": Vector2(24.0, 18.0),
		"theme_color": Color(0.33, 0.16, 0.16, 1.0),
		"enemies": [
			{"template_id": "boss_guardian", "ai_id": "boss_guardian_phase1", "faction_id": "enemy", "offset_meters": Vector2(0.0, 0.0)},
		],
	},
]
const ENEMY_TEMPLATES := {
	"melee_grunt": {
		"name": "\u8fd1\u6218\u5c0f\u5175",
		"role": "melee",
		"max_health": 70,
		"move_speed": 1.65,
		"attack_range": 0.95,
		"attack_cooldown": 1.35,
		"windup": 0.3,
		"recovery": 0.25,
		"size_meters": Vector2(0.45, 0.45),
		"display_color": Color(0.76, 0.67, 0.36, 1.0),
		"label_font_size": 9,
		"skill": {
			"type": "sector",
			"name": "\u5c0f\u5175\u65a9\u51fb",
			"range_meters": 0.95,
			"arc_degrees": 110.0,
			"damage": 14,
			"flash_duration": 0.18,
			"effect_color": Color(1.0, 0.76, 0.42, 0.72),
		},
		"phase_two": {
			"cooldown_multiplier": 1.0,
			"damage_multiplier": 1.0,
			"range_bonus": 0.0,
		},
	},
	"ranged_grunt": {
		"name": "\u8fdc\u7a0b\u5c0f\u5175",
		"role": "ranged",
		"max_health": 55,
		"move_speed": 1.25,
		"attack_range": 6.0,
		"attack_cooldown": 1.8,
		"ranged_attack_cooldown": 1.8,
		"fallback_attack_cooldown": 1.25,
		"windup": 0.45,
		"recovery": 0.25,
		"fallback_windup": 0.34,
		"fallback_recovery": 0.22,
		"fallback_attack_damage_ratio": 0.55,
		"fallback_attack_range": 1.5,
		"fallback_attack_arc_degrees": 100.0,
		"fallback_attack_name": "\u8fd1\u8eab\u53cd\u51fb",
		"size_meters": Vector2(0.42, 0.42),
		"display_color": Color(0.50, 0.72, 0.86, 1.0),
		"label_font_size": 9,
		"skill": {
			"type": "projectile",
			"name": "\u80fd\u91cf\u5f39",
			"range_meters": 6.0,
			"arc_degrees": 60.0,
			"damage": 11,
			"flash_duration": 0.14,
			"effect_color": Color(0.72, 0.88, 1.0, 0.92),
			"projectile_speed_mps": 5.0,
			"projectile_range_meters": 8.0,
			"projectile_size_meters": Vector2(0.2, 0.2),
		},
		"phase_two": {
			"cooldown_multiplier": 1.0,
			"damage_multiplier": 1.0,
			"range_bonus": 0.0,
		},
	},
	"boss_guardian": {
		"name": "Boss",
		"role": "boss",
		"max_health": 320,
		"move_speed": 1.35,
		"attack_range": 2.4,
		"attack_cooldown": 2.5,
		"windup": 0.6,
		"recovery": 0.55,
		"size_meters": Vector2(0.9, 0.9),
		"display_color": Color(0.76, 0.32, 0.32, 1.0),
		"label_font_size": 10,
		"skill": {
			"type": "sector",
			"name": "\u5f3a\u5316\u65a9\u51fb",
			"range_meters": 2.4,
			"arc_degrees": 140.0,
			"damage": 28,
			"flash_duration": 0.24,
			"effect_color": Color(1.0, 0.44, 0.44, 0.82),
		},
		"phase_two": {
			"cooldown_multiplier": 0.72,
			"damage_multiplier": 1.3,
			"range_bonus": 0.4,
		},
	},
}
const GODDESS_ACTOR_CONFIG := {
	"actor_kind": "npc",
	"name": "复活女神",
	"role": "npc",
	"max_health": 999,
	"move_speed": 0.0,
	"attack_range": 0.0,
	"attack_cooldown": 0.0,
	"windup": 0.0,
	"recovery": 0.0,
	"size_meters": Vector2(0.7, 1.1),
	"display_color": Color(0.90, 0.84, 0.56, 1.0),
	"label_font_size": 10,
	"show_name_label": true,
	"show_health_label": false,
}

var enemy_registry: Dictionary = {}
var room_bounds_by_id: Dictionary = {}
var walkable_regions_pixels: Array = []
var wall_collision_rects_pixels: Array = []
var current_room_name: String = ""
var is_skill_panel_hovered: bool = false
var hover_detail_manager: Control
var battle_result_locked: bool = false
var current_result_type: String = ""
var stage_clear_placeholder_active: bool = false
var death_panel: PanelContainer
var death_summary_label: Label
var restart_button: Button
var exit_button: Button
var boss_clear_panel: PanelContainer
var boss_description_label: Label
var a_stats_container: VBoxContainer
var b_stats_container: VBoxContainer
var next_level_button: Button
var player_menu: PanelContainer
var chest_menu: PanelContainer
var active_overlay_control: Control
var chest_layer: Node2D
var dialogue_context_active: bool = false
var last_dialogue_action_request: Dictionary = {}

@onready var ground: ColorRect = $Ground
@onready var grid_overlay: Polygon2D = $GridOverlay
@onready var room_floor_layer: Node2D = $WorldLayers/RoomFloorLayer
@onready var entities_layer: Node2D = $WorldLayers/Entities
@onready var player: Node2D = $WorldLayers/Entities/Player
@onready var enemies_layer: Node2D = $WorldLayers/Entities/Enemies
@onready var foreground_wall_layer: Node2D = $WorldLayers/ForegroundWallLayer
@onready var effect_layer: Node2D = $WorldLayers/EffectLayer
@onready var village_info_label: Label = %VillageInfoLabel
@onready var player_info_label: Label = %PlayerInfoLabel
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var skill_bar_panel: PanelContainer = $CanvasLayer/SkillBarPanel
@onready var skill_label: Label = $CanvasLayer/SkillBarPanel/SkillBarContent/SkillLabel


func _ready() -> void:
	_configure_display_layers()
	_ensure_interactable_layer()
	_build_room_layout()
	player.configure_world(METERS_TO_PIXELS)
	player.position = Vector2(14.0, 20.0) * METERS_TO_PIXELS
	_setup_skill_ui()
	_setup_hover_detail_manager()
	_setup_result_panels()
	_setup_player_menu()
	_setup_chest_menu()
	_spawn_interactables()
	player.death_requested.connect(request_player_death)
	_spawn_room_enemies()
	_register_dialogue_scene_adapter()
	_update_ui()


func _process(_delta: float) -> void:
	_update_ui()
	_update_skill_ui()


func _exit_tree() -> void:
	var dialogue_manager: Node = get_node_or_null("/root/DialogueManager")
	if dialogue_manager != null and dialogue_manager.has_method("unregister_scene_adapter"):
		dialogue_manager.unregister_scene_adapter(self)


func get_player_node() -> Node2D:
	return player


func get_player_global_position() -> Vector2:
	return player.global_position


func is_player_alive() -> bool:
	return player.is_alive()


func is_result_showing() -> bool:
	return battle_result_locked


func is_overlay_open() -> bool:
	return active_overlay_control != null and is_instance_valid(active_overlay_control) and (active_overlay_control.visible or dialogue_context_active)


func is_dialogue_active() -> bool:
	return dialogue_context_active


func request_open_overlay(overlay_control: Control) -> bool:
	if battle_result_locked or is_overlay_open():
		return false
	active_overlay_control = overlay_control
	is_skill_panel_hovered = false
	if hover_detail_manager != null:
		hover_detail_manager.hide_immediately()
	get_tree().paused = true
	return true


func close_overlay(overlay_control: Control) -> void:
	if overlay_control != active_overlay_control:
		return
	active_overlay_control = null
	if not battle_result_locked:
		get_tree().paused = false


func begin_dialogue_context(overlay_control: Control, _context: Dictionary = {}) -> bool:
	if battle_result_locked or is_overlay_open():
		return false
	active_overlay_control = overlay_control
	dialogue_context_active = true
	is_skill_panel_hovered = false
	if hover_detail_manager != null:
		hover_detail_manager.hide_immediately()
	if player != null and player.has_method("lock_gameplay"):
		player.lock_gameplay()
	return true


func end_dialogue_context(overlay_control: Control, _context: Dictionary = {}) -> void:
	if overlay_control != active_overlay_control:
		return
	dialogue_context_active = false
	active_overlay_control = null
	if hover_detail_manager != null:
		hover_detail_manager.hide_immediately()
	if not battle_result_locked and player != null and player.has_method("unlock_gameplay"):
		player.unlock_gameplay()


func open_dialogue_for_interaction(npc_node: Node, dialogue_id: String) -> bool:
	var dialogue_manager: Node = get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null or not dialogue_manager.has_method("start_dialogue"):
		return false
	return dialogue_manager.start_dialogue(dialogue_id, npc_node, {})


func handle_dialogue_action(action_type: String, payload: Dictionary, _manager: Node) -> bool:
	last_dialogue_action_request = {
		"action_type": action_type,
		"payload": payload.duplicate(true),
	}

	match action_type:
		"open_shop":
			_show_floating_text(player.global_position, "鍟嗗簵鍏ュ彛棰勭暀", Color(0.86, 0.92, 1.0, 1.0), 16)
			return true
		"open_training":
			_show_floating_text(player.global_position, "璁粌鍏ュ彛棰勭暀", Color(0.76, 1.0, 0.84, 1.0), 16)
			return true
		"start_hostile":
			var source_node: Node = payload.get("source_node")
			if source_node != null and is_instance_valid(source_node):
				if source_node.has_method("apply_combat_profile"):
					source_node.apply_combat_profile(payload.get("combat_profile", {}))
				else:
					if source_node.has_method("switch_faction") and payload.has("faction_id"):
						source_node.switch_faction(str(payload.get("faction_id", "enemy")))
					if source_node.has_method("switch_ai") and payload.has("ai_id"):
						source_node.switch_ai(str(payload.get("ai_id", "")), bool(payload.get("preserve_attack_cooldown", false)))
			_show_floating_text(player.global_position, "鏁屽鍏ュ彛棰勭暀", Color(1.0, 0.74, 0.74, 1.0), 16)
			return true
		"call_hook":
			_show_floating_text(player.global_position, "鍓ф儏閽╁瓙锛?s" % str(payload.get("hook_id", "")), Color(1.0, 0.92, 0.72, 1.0), 16)
			return true
		_:
			return false


func get_last_dialogue_action_request() -> Dictionary:
	return last_dialogue_action_request.duplicate(true)


func open_chest_for_interaction(chest_node: Node) -> void:
	if chest_menu == null:
		return
	if not request_open_overlay(chest_menu):
		return
	chest_menu.open_for_chest(chest_node)


func find_enemies_in_radius(center_position: Vector2, radius_pixels: float) -> Array:
	if battle_result_locked:
		return []

	var results: Array = []

	for enemy_id in enemy_registry.keys():
		var enemy: Node2D = enemy_registry[enemy_id]["node"]
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if enemy.has_method("is_hostile_to_player") and not enemy.is_hostile_to_player():
			continue

		var half_size_pixels: Vector2 = enemy_registry[enemy_id]["half_size_pixels"] as Vector2
		if _rectangle_overlaps_circle(enemy.global_position, half_size_pixels, center_position, radius_pixels):
			results.append(enemy)

	return results


func apply_player_slash_attack(center_position: Vector2, direction: Vector2, radius_pixels: float, damage: float) -> void:
	if battle_result_locked:
		return

	for enemy in find_enemies_in_radius(center_position, radius_pixels):
		var enemy_id: int = enemy.get_instance_id()
		var half_size_pixels: Vector2 = enemy_registry[enemy_id]["half_size_pixels"] as Vector2
		if _rectangle_overlaps_sector(enemy.global_position, half_size_pixels, center_position, direction, radius_pixels, 180.0):
			_resolve_player_attack(enemy, damage)


func apply_enemy_sector_attack(attacker_name: String, center_position: Vector2, direction: Vector2, radius_pixels: float, arc_degrees: float, damage: int, attack_profile: Dictionary = {}) -> void:
	if battle_result_locked or dialogue_context_active:
		return

	if not player.is_alive():
		return

	if _rectangle_overlaps_sector(player.global_position, player.get_hitbox_half_size_pixels(), center_position, direction, radius_pixels, arc_degrees):
		_resolve_enemy_attack(attacker_name, damage, attack_profile, player.global_position)


func spawn_enemy_projectile(attacker_name: String, origin: Vector2, direction: Vector2, projectile_config: Dictionary, attack_profile: Dictionary = {}) -> void:
	if battle_result_locked:
		return

	var projectile_scene: PackedScene = load(PROJECTILE_SCENE_PATH)
	var projectile: Node2D = projectile_scene.instantiate()
	effect_layer.add_child(projectile)
	projectile.setup_projectile(projectile_config, self, origin, direction, METERS_TO_PIXELS, attacker_name, attack_profile)


func projectile_hits_player(projectile_center: Vector2, projectile_half_size: Vector2, damage: int, attacker_name: String, attack_profile: Dictionary = {}) -> bool:
	if battle_result_locked or dialogue_context_active:
		return false

	if not player.is_alive():
		return false

	if _rectangles_overlap(projectile_center, projectile_half_size, player.global_position, player.get_hitbox_half_size_pixels()):
		_resolve_enemy_attack(attacker_name, damage, attack_profile, player.global_position)
		return true

	return false


func _resolve_player_attack(enemy: Node2D, base_damage: float) -> void:
	if battle_result_locked or enemy == null or not is_instance_valid(enemy):
		return

	if not enemy.has_method("is_alive") or not enemy.is_alive():
		return

	if not _roll_percent(player.get_hit_rate()):
		_show_floating_text(enemy.global_position, "MISS", Color(0.92, 0.92, 0.92, 1.0), 18)
		return

	var final_damage: int = max(int(round(base_damage)), 1)
	var is_critical: bool = _roll_percent(player.get_crit_rate())
	if is_critical:
		final_damage = max(int(round(float(final_damage) * player.get_crit_damage_multiplier())), 1)

	enemy.take_damage(final_damage)
	_update_enemy_registry_health(enemy)

	var damage_text: String = str(final_damage)
	var damage_color: Color = Color(1.0, 0.92, 0.62, 1.0)
	var font_size: int = 18
	if is_critical:
		damage_text += "!"
		damage_color = Color(1.0, 0.32, 0.32, 1.0)
		font_size = 22

	_show_floating_text(enemy.global_position, damage_text, damage_color, font_size)


func _resolve_enemy_attack(attacker_name: String, base_damage: int, attack_profile: Dictionary, hit_position: Vector2) -> void:
	if battle_result_locked or not player.is_alive():
		return

	var hit_rate: float = float(attack_profile.get("hit_rate", 100.0))
	var crit_rate: float = float(attack_profile.get("crit_rate", 0.0))
	var crit_damage: float = maxf(float(attack_profile.get("crit_damage", 1.5)), 1.0)

	if not _roll_percent(hit_rate):
		_show_floating_text(hit_position, "MISS", Color(0.92, 0.92, 0.92, 1.0), 18)
		return

	if _roll_percent(player.get_dodge_rate()):
		_show_floating_text(hit_position, "MISS", Color(0.92, 0.92, 0.92, 1.0), 18)
		return

	var final_damage: int = max(base_damage, 1)
	if _roll_percent(player.get_block_rate()):
		final_damage = max(int(round(float(final_damage) * BLOCK_DAMAGE_MULTIPLIER)), 1)

	var is_critical: bool = _roll_percent(crit_rate)
	if is_critical:
		final_damage = max(int(round(float(final_damage) * crit_damage)), 1)

	player.take_damage(final_damage, attacker_name)

	var damage_text: String = str(final_damage)
	var damage_color: Color = Color(1.0, 0.95, 0.95, 1.0)
	var font_size: int = 18
	if is_critical:
		damage_text += "!"
		damage_color = Color(1.0, 0.32, 0.32, 1.0)
		font_size = 22

	_show_floating_text(hit_position, damage_text, damage_color, font_size)


func _update_enemy_registry_health(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return

	var enemy_id: int = enemy.get_instance_id()
	if enemy_registry.has(enemy_id):
		enemy_registry[enemy_id]["health"] = enemy.get_enemy_data()["health"]


func _roll_percent(chance_percent: float) -> bool:
	var clamped_chance: float = clampf(chance_percent, 0.0, 100.0)
	return randf() * 100.0 < clamped_chance


func _show_floating_text(world_position: Vector2, text: String, color: Color, font_size: int = 18) -> void:
	if effect_layer == null:
		return

	var floating_label := Label.new()
	floating_label.text = text
	floating_label.position = world_position + Vector2(-18.0, -28.0)
	floating_label.modulate = color
	floating_label.z_as_relative = false
	floating_label.z_index = GameLayers.Z_EFFECTS
	floating_label.add_theme_font_size_override("font_size", font_size)
	effect_layer.add_child(floating_label)

	var tween: Tween = create_tween()
	tween.tween_property(floating_label, "position", floating_label.position + Vector2(0.0, -18.0), FLOATING_TEXT_LIFETIME)
	tween.parallel().tween_property(floating_label, "modulate:a", 0.0, FLOATING_TEXT_LIFETIME)
	tween.tween_callback(func() -> void:
		if is_instance_valid(floating_label):
			floating_label.queue_free()
	)


func _on_enemy_died(enemy: Node2D) -> void:
	var was_boss: bool = enemy.has_method("is_boss") and enemy.is_boss()
	if was_boss and not battle_result_locked:
		_show_boss_clear_result()

	enemy_registry.erase(enemy.get_instance_id())
	enemy.queue_free()


func _update_ui() -> void:
	current_room_name = _get_current_room_name()
	var game_state: Node = get_node_or_null("/root/GameState")
	var current_character: Dictionary = {}
	if game_state != null and "current_character" in game_state:
		current_character = game_state.current_character
	var created_class_name: String = str(current_character.get("class_name", "\u6218\u58eb"))
	village_info_label.text = "\u51fa\u751f\u533a\u57df  |  \u5f53\u524d\u623f\u95f4\uff1a%s  |  \u804c\u4e1a\uff1a%s  |  \u5b58\u6d3b\u654c\u4eba\uff1a%d" % [
		current_room_name,
		created_class_name,
		_count_hostile_enemies(),
	]
	player_info_label.text = "\u73a9\u5bb6\u5750\u6807 %.1f, %.1f  |  \u7f51\u683c %.0f, %.0f  |  HP %d/%d" % [
		player.position.x / METERS_TO_PIXELS,
		player.position.y / METERS_TO_PIXELS,
		player.get_grid_position().x,
		player.get_grid_position().y,
		player.get_current_health(),
		player.get_max_health(),
	]


func _setup_skill_ui() -> void:
	skill_bar_panel.custom_minimum_size = Vector2(220.0, 86.0)
	skill_bar_panel.offset_right = skill_bar_panel.offset_left + 220.0
	skill_bar_panel.offset_bottom = skill_bar_panel.offset_top + 86.0
	skill_bar_panel.mouse_entered.connect(_on_skill_bar_panel_mouse_entered)
	skill_bar_panel.mouse_exited.connect(_on_skill_bar_panel_mouse_exited)

func _setup_hover_detail_manager() -> void:
	hover_detail_manager = Control.new()
	hover_detail_manager.set_script(HoverDetailManagerScript)
	canvas_layer.add_child(hover_detail_manager)


func get_hover_detail_manager() -> Control:
	return hover_detail_manager


func _register_dialogue_scene_adapter() -> void:
	var dialogue_manager: Node = get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null or not dialogue_manager.has_method("register_scene_adapter"):
		return
	dialogue_manager.register_scene_adapter(self, player, canvas_layer, hover_detail_manager)


func _force_close_active_dialogue(reason: String) -> void:
	var dialogue_manager: Node = get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null or not dialogue_manager.has_method("is_dialogue_active") or not dialogue_manager.has_method("close_dialogue"):
		return
	if not dialogue_manager.is_dialogue_active():
		return
	dialogue_manager.close_dialogue(reason)


func _setup_result_panels() -> void:
	death_panel = PanelContainer.new()
	death_panel.name = "DeathPanel"
	death_panel.visible = false
	death_panel.offset_left = 280.0
	death_panel.offset_top = 110.0
	death_panel.offset_right = 860.0
	death_panel.offset_bottom = 520.0
	canvas_layer.add_child(death_panel)

	var death_margin := MarginContainer.new()
	death_margin.add_theme_constant_override("margin_left", 24)
	death_margin.add_theme_constant_override("margin_top", 24)
	death_margin.add_theme_constant_override("margin_right", 24)
	death_margin.add_theme_constant_override("margin_bottom", 24)
	death_panel.add_child(death_margin)

	var death_stack := VBoxContainer.new()
	death_stack.name = "Content"
	death_stack.add_theme_constant_override("separation", 16)
	death_margin.add_child(death_stack)

	var death_title := Label.new()
	death_title.name = "TitleLabel"
	death_title.text = "\u4f60\u5df2\u6b7b\u4ea1"
	death_title.add_theme_font_size_override("font_size", 30)
	death_stack.add_child(death_title)

	death_summary_label = Label.new()
	death_summary_label.name = "SummaryLabel"
	death_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	death_summary_label.text = ""
	death_stack.add_child(death_summary_label)

	var death_buttons := HBoxContainer.new()
	death_buttons.add_theme_constant_override("separation", 14)
	death_stack.add_child(death_buttons)

	restart_button = Button.new()
	restart_button.name = "RestartButton"
	restart_button.text = "\u91cd\u65b0\u5f00\u59cb"
	restart_button.custom_minimum_size = Vector2(140.0, 48.0)
	restart_button.pressed.connect(_on_restart_button_pressed)
	death_buttons.add_child(restart_button)

	exit_button = Button.new()
	exit_button.name = "ExitButton"
	exit_button.text = "\u8fd4\u56de\u4e3b\u83dc\u5355"
	exit_button.custom_minimum_size = Vector2(160.0, 48.0)
	exit_button.pressed.connect(_on_exit_button_pressed)
	death_buttons.add_child(exit_button)

	boss_clear_panel = PanelContainer.new()
	boss_clear_panel.name = "BossClearPanel"
	boss_clear_panel.visible = false
	boss_clear_panel.offset_left = 220.0
	boss_clear_panel.offset_top = 72.0
	boss_clear_panel.offset_right = 920.0
	boss_clear_panel.offset_bottom = 600.0
	canvas_layer.add_child(boss_clear_panel)

	var clear_margin := MarginContainer.new()
	clear_margin.add_theme_constant_override("margin_left", 24)
	clear_margin.add_theme_constant_override("margin_top", 24)
	clear_margin.add_theme_constant_override("margin_right", 24)
	clear_margin.add_theme_constant_override("margin_bottom", 24)
	boss_clear_panel.add_child(clear_margin)

	var clear_stack := VBoxContainer.new()
	clear_stack.add_theme_constant_override("separation", 16)
	clear_margin.add_child(clear_stack)

	var clear_title := Label.new()
	clear_title.name = "TitleLabel"
	clear_title.text = "\u6210\u529f\u8fc7\u5173"
	clear_title.add_theme_font_size_override("font_size", 30)
	clear_stack.add_child(clear_title)

	var a_title := Label.new()
	a_title.text = "A\u7c7b\u5c5e\u6027"
	a_title.add_theme_font_size_override("font_size", 22)
	clear_stack.add_child(a_title)

	a_stats_container = VBoxContainer.new()
	a_stats_container.name = "AStatsContainer"
	a_stats_container.add_theme_constant_override("separation", 8)
	clear_stack.add_child(a_stats_container)

	var b_title := Label.new()
	b_title.text = "B\u7c7b\u5c5e\u6027"
	b_title.add_theme_font_size_override("font_size", 22)
	clear_stack.add_child(b_title)

	b_stats_container = VBoxContainer.new()
	b_stats_container.name = "BStatsContainer"
	b_stats_container.add_theme_constant_override("separation", 8)
	clear_stack.add_child(b_stats_container)

	boss_description_label = Label.new()
	boss_description_label.name = "DescriptionLabel"
	boss_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_description_label.text = "Boss \u5df2\u88ab\u51fb\u8d25\u3002\u4e0b\u4e00\u5173\u6309\u94ae\u5f53\u524d\u4e3a\u5360\u4f4d\u529f\u80fd\u3002"
	clear_stack.add_child(boss_description_label)

	next_level_button = Button.new()
	next_level_button.name = "NextLevelButton"
	next_level_button.text = "\u4e0b\u4e00\u5173"
	next_level_button.custom_minimum_size = Vector2(140.0, 48.0)
	next_level_button.pressed.connect(_on_next_level_button_pressed)
	clear_stack.add_child(next_level_button)

	_set_subtree_process_mode(death_panel, Node.PROCESS_MODE_WHEN_PAUSED)
	_set_subtree_process_mode(boss_clear_panel, Node.PROCESS_MODE_WHEN_PAUSED)
	_hide_result_panels()


func _setup_player_menu() -> void:
	player_menu = PanelContainer.new()
	player_menu.set_script(PlayerMenuSceneScript)
	canvas_layer.add_child(player_menu)
	_set_subtree_process_mode(player_menu, Node.PROCESS_MODE_ALWAYS)
	player_menu.configure(player, self)


func _setup_chest_menu() -> void:
	chest_menu = PanelContainer.new()
	chest_menu.set_script(ChestMenuScript)
	canvas_layer.add_child(chest_menu)
	_set_subtree_process_mode(chest_menu, Node.PROCESS_MODE_ALWAYS)
	chest_menu.configure(player, self)


func _ensure_interactable_layer() -> void:
	chest_layer = Node2D.new()
	chest_layer.name = "Interactables"
	entities_layer.add_child(chest_layer)


func _spawn_interactables() -> void:
	var chest_scene: PackedScene = load(CHEST_SCENE_PATH)
	var chest: Node2D = chest_scene.instantiate()
	chest_layer.add_child(chest)
	chest.configure(self, player, Vector2(10.5, 20.0), METERS_TO_PIXELS, [
		ItemSystem.make_stack("iron_sword", 1),
	])

	var actor_scene: PackedScene = load(ENEMY_SCENE_PATH)
	var npc_scene: PackedScene = load(NPC_DIALOGUE_SCENE_PATH)
	var goddess: Node2D = actor_scene.instantiate()
	chest_layer.add_child(goddess)
	goddess.setup_actor(GODDESS_ACTOR_CONFIG, self, Vector2(17.4, 19.8), METERS_TO_PIXELS, "npc_guard_friendly_idle", "friendly")

	var goddess_dialogue: Node2D = npc_scene.instantiate()
	goddess_dialogue.name = "DialogueInteractor"
	goddess.add_child(goddess_dialogue)
	goddess_dialogue.configure_on_host(self, player, goddess, METERS_TO_PIXELS, "spawn_goddess_intro", "复活女神")


func _set_subtree_process_mode(root: Node, mode: int) -> void:
	root.process_mode = mode
	for child in root.get_children():
		_set_subtree_process_mode(child, mode)


func _hide_result_panels() -> void:
	death_panel.visible = false
	boss_clear_panel.visible = false


func _update_skill_ui() -> void:
	if battle_result_locked:
		return

	var skill_id: String = player.get_equipped_skill_id(0) if player.has_method("get_equipped_skill_id") else ""
	if skill_id.is_empty():
		skill_label.text = "\u6280\u80fd\u680f\uff1a\u672a\u914d\u7f6e\n\u51b7\u5374\uff1a--\n\u8bf7\u5728\u7edf\u5408\u83dc\u5355\u7684\u6280\u80fd\u9875\u4e2d\u914d\u7f6e"
		return

	var skill_data: Dictionary = player.get_skill_data(skill_id) if player.has_method("get_skill_data") else player.get_slash_skill_data()
	var cooldown_remaining: float = float(skill_data.get("cooldown_remaining", 0.0))
	var cooldown_status := "\u5c31\u7eea"
	if cooldown_remaining > 0.01:
		cooldown_status = "%.2f\u79d2" % cooldown_remaining

	var trigger_label := "\u81ea\u52a8\u89e6\u53d1" if str(skill_data.get("skill_type", "active")) == "passive" else "\u4e3b\u52a8\u89e6\u53d1"
	skill_label.text = "\u6280\u80fd\u680f\uff1a%s\n\u51b7\u5374\uff1a%s\n%s" % [str(skill_data.get("display_name", skill_id)), cooldown_status, trigger_label]


func _on_skill_bar_panel_mouse_entered() -> void:
	is_skill_panel_hovered = true
	var skill_id: String = player.get_equipped_skill_id(0) if player.has_method("get_equipped_skill_id") else ""
	if hover_detail_manager != null and not skill_id.is_empty():
		hover_detail_manager.request_hover("skill_entry", skill_id, skill_bar_panel, Callable(self, "_build_skill_bar_hover_context").bind(skill_id), "mouse")


func _on_skill_bar_panel_mouse_exited() -> void:
	is_skill_panel_hovered = false
	var skill_id: String = player.get_equipped_skill_id(0) if player.has_method("get_equipped_skill_id") else ""
	if hover_detail_manager != null and not skill_id.is_empty():
		hover_detail_manager.clear_hover(skill_id)


func _build_skill_bar_hover_context(skill_id: String) -> Dictionary:
	return {
		"player": player,
		"skill_id": skill_id,
		"room_id": current_room_name,
		"battle_locked": battle_result_locked,
	}


func _configure_display_layers() -> void:
	ground.z_index = GameLayers.Z_BACKGROUND
	grid_overlay.z_index = GameLayers.Z_BACKGROUND + 1
	room_floor_layer.z_index = GameLayers.Z_ROOM_FLOOR
	entities_layer.z_index = GameLayers.Z_ENTITIES
	foreground_wall_layer.z_index = GameLayers.Z_WALL_FOREGROUND
	effect_layer.z_index = GameLayers.Z_EFFECTS
	canvas_layer.layer = GameLayers.Z_UI


func request_player_death() -> void:
	if battle_result_locked:
		return

	_show_death_result()


func _show_death_result() -> void:
	_begin_battle_result("death")
	_hide_result_panels()
	var summary: Dictionary = player.get_combat_summary()
	death_summary_label.text = "\u804c\u4e1a\uff1a%s\n\u5f53\u524d\u751f\u547d\uff1a%d / %d\n\u65a9\u51fb\u5b9e\u9645\u4f24\u5bb3\uff1a%.1f\n\u5f53\u524d\u51b7\u5374\uff1a%.2f \u79d2" % [
		str(summary["class_name"]),
		int(summary["current_hp"]),
		int(summary["max_hp"]),
		float(summary["slash_damage"]),
		float(summary["slash_cooldown"]),
	]
	death_panel.visible = true


func _show_boss_clear_result() -> void:
	_begin_battle_result("boss_clear")
	stage_clear_placeholder_active = true
	emit_signal("stage_clear_placeholder_triggered")
	_hide_result_panels()
	_refresh_boss_clear_stats()
	boss_description_label.text = "Boss \u5df2\u88ab\u51fb\u8d25\u3002\u8fc7\u5173\u626d\u673a\u5360\u4f4d\u7b26\u5df2\u6fc0\u6d3b\uff0c\u4e0b\u4e00\u5173\u6309\u94ae\u5f53\u524d\u4ec5\u4f5c\u5c55\u793a\u3002"
	boss_clear_panel.visible = true


func _begin_battle_result(result_type: String) -> void:
	if battle_result_locked:
		return
	_force_close_active_dialogue("battle_result")

	battle_result_locked = true
	current_result_type = result_type
	player.lock_gameplay()
	is_skill_panel_hovered = false
	if hover_detail_manager != null:
		hover_detail_manager.hide_immediately()
	get_tree().paused = true


func _refresh_boss_clear_stats() -> void:
	for child in a_stats_container.get_children():
		child.queue_free()
	for child in b_stats_container.get_children():
		child.queue_free()

	var a_stats: Dictionary = player.get_character_a_stats()
	var b_stats: Dictionary = player.get_character_b_stats()

	for stat_definition in A_STAT_DISPLAY_ORDER:
		var stat_key: String = str(stat_definition["key"])
		var label := Label.new()
		label.text = "%s\uff1a%s" % [str(stat_definition["label"]), str(a_stats.get(stat_key, 0))]
		a_stats_container.add_child(label)

	for stat_definition in B_STAT_DISPLAY_ORDER:
		var stat_key: String = str(stat_definition["key"])
		var label := Label.new()
		label.text = "%s\uff1a%s" % [str(stat_definition["label"]), _format_b_stat_value(stat_key, float(b_stats.get(stat_key, 0.0)))]
		b_stats_container.add_child(label)


func _format_b_stat_value(stat_key: String, stat_value: float) -> String:
	return CharacterStats.format_b_stat_value(stat_key, stat_value)


func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_exit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_next_level_button_pressed() -> void:
	boss_description_label.text = "\u4e0b\u4e00\u5173\u6309\u94ae\u5df2\u70b9\u51fb\u3002\u5f53\u524d\u4ecd\u4e3a\u5360\u4f4d\u903b\u8f91\uff0c\u4e0d\u4f1a\u5207\u56fe\uff0c\u4e5f\u4e0d\u4f1a\u6062\u590d\u6e38\u620f\u3002"


func _build_room_layout() -> void:
	room_bounds_by_id.clear()
	walkable_regions_pixels.clear()
	wall_collision_rects_pixels.clear()
	var world_bounds: Rect2 = _compute_world_bounds_pixels()
	ground.color = Color(0.08, 0.10, 0.09, 1.0)
	ground.offset_left = world_bounds.position.x
	ground.offset_top = world_bounds.position.y
	ground.offset_right = world_bounds.position.x + world_bounds.size.x
	ground.offset_bottom = world_bounds.position.y + world_bounds.size.y
	grid_overlay.polygon = PackedVector2Array([
		world_bounds.position,
		Vector2(world_bounds.position.x + world_bounds.size.x, world_bounds.position.y),
		world_bounds.position + world_bounds.size,
		Vector2(world_bounds.position.x, world_bounds.position.y + world_bounds.size.y),
	])

	for child in room_floor_layer.get_children():
		child.queue_free()

	for child in foreground_wall_layer.get_children():
		child.queue_free()

	for index in range(ROOM_DEFINITIONS.size()):
		var room_definition: Dictionary = ROOM_DEFINITIONS[index] as Dictionary
		var has_left_door: bool = index > 0
		var has_right_door: bool = index < ROOM_DEFINITIONS.size() - 1
		_create_room_visual(room_definition)
		_create_room_walls(room_definition, has_left_door, has_right_door)
		room_bounds_by_id[str(room_definition["id"])] = Rect2(
			(room_definition["center_meters"] as Vector2) - (room_definition["size_meters"] as Vector2) * 0.5,
			room_definition["size_meters"] as Vector2
		)
		walkable_regions_pixels.append(Rect2(
			((room_definition["center_meters"] as Vector2) - (room_definition["size_meters"] as Vector2) * 0.5) * METERS_TO_PIXELS,
			(room_definition["size_meters"] as Vector2) * METERS_TO_PIXELS
		))

	for index in range(ROOM_DEFINITIONS.size() - 1):
		_create_corridor_visual(ROOM_DEFINITIONS[index] as Dictionary, ROOM_DEFINITIONS[index + 1] as Dictionary)


func _compute_world_bounds_pixels() -> Rect2:
	var min_x: float = 999999.0
	var min_y: float = 999999.0
	var max_x: float = -999999.0
	var max_y: float = -999999.0

	for room_definition in ROOM_DEFINITIONS:
		var center_meters: Vector2 = room_definition["center_meters"] as Vector2
		var size_meters: Vector2 = room_definition["size_meters"] as Vector2
		min_x = minf(min_x, center_meters.x - size_meters.x * 0.5 - 6.0)
		max_x = maxf(max_x, center_meters.x + size_meters.x * 0.5 + 6.0)
		min_y = minf(min_y, center_meters.y - size_meters.y * 0.5 - 6.0)
		max_y = maxf(max_y, center_meters.y + size_meters.y * 0.5 + 6.0)

	return Rect2(Vector2(min_x, min_y) * METERS_TO_PIXELS, Vector2(max_x - min_x, max_y - min_y) * METERS_TO_PIXELS)


func _create_room_visual(room_definition: Dictionary) -> void:
	var center_pixels: Vector2 = (room_definition["center_meters"] as Vector2) * METERS_TO_PIXELS
	var size_pixels: Vector2 = (room_definition["size_meters"] as Vector2) * METERS_TO_PIXELS
	var floor_polygon: Polygon2D = Polygon2D.new()
	floor_polygon.position = center_pixels
	floor_polygon.color = room_definition["theme_color"] as Color
	floor_polygon.polygon = PackedVector2Array([
		Vector2(-size_pixels.x * 0.5, -size_pixels.y * 0.5),
		Vector2(size_pixels.x * 0.5, -size_pixels.y * 0.5),
		Vector2(size_pixels.x * 0.5, size_pixels.y * 0.5),
		Vector2(-size_pixels.x * 0.5, size_pixels.y * 0.5),
	])
	room_floor_layer.add_child(floor_polygon)

	var outline: Line2D = Line2D.new()
	outline.width = 3.0
	outline.default_color = Color(0.85, 0.9, 0.82, 0.65)
	outline.position = center_pixels
	outline.points = PackedVector2Array([
		Vector2(-size_pixels.x * 0.5, -size_pixels.y * 0.5),
		Vector2(size_pixels.x * 0.5, -size_pixels.y * 0.5),
		Vector2(size_pixels.x * 0.5, size_pixels.y * 0.5),
		Vector2(-size_pixels.x * 0.5, size_pixels.y * 0.5),
		Vector2(-size_pixels.x * 0.5, -size_pixels.y * 0.5),
	])
	room_floor_layer.add_child(outline)


func _create_room_walls(room_definition: Dictionary, has_left_door: bool, has_right_door: bool) -> void:
	var center_meters: Vector2 = room_definition["center_meters"] as Vector2
	var size_meters: Vector2 = room_definition["size_meters"] as Vector2
	var half_size_meters: Vector2 = size_meters * 0.5
	var left: float = center_meters.x - half_size_meters.x
	var right: float = center_meters.x + half_size_meters.x
	var top: float = center_meters.y - half_size_meters.y
	var bottom: float = center_meters.y + half_size_meters.y
	var door_half_height: float = CORRIDOR_HEIGHT_METERS * 0.5
	var door_top: float = center_meters.y - door_half_height
	var door_bottom: float = center_meters.y + door_half_height
	var wall_color: Color = Color(0.74, 0.74, 0.68, 1.0)

	_add_wall_section(Rect2(Vector2(left - ROOM_WALL_THICKNESS_METERS, top - ROOM_WALL_THICKNESS_METERS), Vector2(size_meters.x + ROOM_WALL_THICKNESS_METERS * 2.0, ROOM_WALL_THICKNESS_METERS)), wall_color)
	_add_wall_section(Rect2(Vector2(left - ROOM_WALL_THICKNESS_METERS, bottom), Vector2(size_meters.x + ROOM_WALL_THICKNESS_METERS * 2.0, ROOM_WALL_THICKNESS_METERS)), wall_color)

	if has_left_door:
		_add_wall_section(Rect2(Vector2(left - ROOM_WALL_THICKNESS_METERS, top), Vector2(ROOM_WALL_THICKNESS_METERS, door_top - top)), wall_color)
		_add_wall_section(Rect2(Vector2(left - ROOM_WALL_THICKNESS_METERS, door_bottom), Vector2(ROOM_WALL_THICKNESS_METERS, bottom - door_bottom)), wall_color)
	else:
		_add_wall_section(Rect2(Vector2(left - ROOM_WALL_THICKNESS_METERS, top), Vector2(ROOM_WALL_THICKNESS_METERS, size_meters.y)), wall_color)

	if has_right_door:
		_add_wall_section(Rect2(Vector2(right, top), Vector2(ROOM_WALL_THICKNESS_METERS, door_top - top)), wall_color)
		_add_wall_section(Rect2(Vector2(right, door_bottom), Vector2(ROOM_WALL_THICKNESS_METERS, bottom - door_bottom)), wall_color)
	else:
		_add_wall_section(Rect2(Vector2(right, top), Vector2(ROOM_WALL_THICKNESS_METERS, size_meters.y)), wall_color)


func _create_corridor_visual(room_a: Dictionary, room_b: Dictionary) -> void:
	var center_a: Vector2 = room_a["center_meters"] as Vector2
	var center_b: Vector2 = room_b["center_meters"] as Vector2
	var size_a: Vector2 = room_a["size_meters"] as Vector2
	var size_b: Vector2 = room_b["size_meters"] as Vector2
	var corridor_start_x: float = center_a.x + size_a.x * 0.5
	var corridor_end_x: float = center_b.x - size_b.x * 0.5
	var corridor_center: Vector2 = Vector2((corridor_start_x + corridor_end_x) * 0.5, center_a.y)
	var corridor_size: Vector2 = Vector2(corridor_end_x - corridor_start_x, CORRIDOR_HEIGHT_METERS)
	var corridor_polygon: Polygon2D = Polygon2D.new()
	corridor_polygon.position = corridor_center * METERS_TO_PIXELS
	corridor_polygon.color = Color(0.26, 0.33, 0.26, 1.0)
	corridor_polygon.polygon = PackedVector2Array([
		Vector2(-corridor_size.x * 0.5, -corridor_size.y * 0.5) * METERS_TO_PIXELS,
		Vector2(corridor_size.x * 0.5, -corridor_size.y * 0.5) * METERS_TO_PIXELS,
		Vector2(corridor_size.x * 0.5, corridor_size.y * 0.5) * METERS_TO_PIXELS,
		Vector2(-corridor_size.x * 0.5, corridor_size.y * 0.5) * METERS_TO_PIXELS,
	])
	room_floor_layer.add_child(corridor_polygon)

	var corridor_rect_pixels := Rect2(
		Vector2(corridor_start_x - ROOM_WALL_THICKNESS_METERS * 0.5, center_a.y - CORRIDOR_HEIGHT_METERS * 0.5) * METERS_TO_PIXELS,
		Vector2((corridor_end_x - corridor_start_x) + ROOM_WALL_THICKNESS_METERS, CORRIDOR_HEIGHT_METERS) * METERS_TO_PIXELS
	)
	walkable_regions_pixels.append(corridor_rect_pixels)

	var wall_color: Color = Color(0.70, 0.70, 0.66, 1.0)
	_add_wall_section(Rect2(Vector2(corridor_start_x, center_a.y - CORRIDOR_HEIGHT_METERS * 0.5 - ROOM_WALL_THICKNESS_METERS), Vector2(corridor_end_x - corridor_start_x, ROOM_WALL_THICKNESS_METERS)), wall_color)
	_add_wall_section(Rect2(Vector2(corridor_start_x, center_a.y + CORRIDOR_HEIGHT_METERS * 0.5), Vector2(corridor_end_x - corridor_start_x, ROOM_WALL_THICKNESS_METERS)), wall_color)


func _add_wall_section(rect_meters: Rect2, wall_color: Color) -> void:
	_register_wall_collision_rect(rect_meters)
	var wall_polygon: Polygon2D = Polygon2D.new()
	wall_polygon.position = rect_meters.position * METERS_TO_PIXELS
	wall_polygon.color = wall_color
	wall_polygon.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(rect_meters.size.x, 0.0) * METERS_TO_PIXELS,
		rect_meters.size * METERS_TO_PIXELS,
		Vector2(0.0, rect_meters.size.y) * METERS_TO_PIXELS,
	])
	foreground_wall_layer.add_child(wall_polygon)


func _register_wall_collision_rect(rect_meters: Rect2) -> void:
	wall_collision_rects_pixels.append(Rect2(
		rect_meters.position * METERS_TO_PIXELS,
		rect_meters.size * METERS_TO_PIXELS
	))


func _spawn_room_enemies() -> void:
	var enemy_scene: PackedScene = load(ENEMY_SCENE_PATH)

	for room_definition in ROOM_DEFINITIONS:
		var room_center: Vector2 = room_definition["center_meters"] as Vector2
		var room_id: String = str(room_definition["id"])
		var enemy_spawn_definitions: Array = room_definition["enemies"] as Array

		for spawn_definition in enemy_spawn_definitions:
			var template_id: String = str(spawn_definition["template_id"])
			var ai_id: String = str(spawn_definition.get("ai_id", ""))
			var faction_id: String = str(spawn_definition.get("faction_id", "enemy"))
			var spawn_position_meters: Vector2 = room_center + (spawn_definition["offset_meters"] as Vector2)
			var enemy: Node2D = enemy_scene.instantiate()
			enemy.add_to_group("enemy")
			enemies_layer.add_child(enemy)
			enemy.setup_enemy(ENEMY_TEMPLATES[template_id] as Dictionary, self, spawn_position_meters, METERS_TO_PIXELS, ai_id, faction_id)
			enemy.enemy_died.connect(_on_enemy_died)
			enemy_registry[enemy.get_instance_id()] = {
				"node": enemy,
				"health": int((ENEMY_TEMPLATES[template_id] as Dictionary)["max_health"]),
				"half_size_pixels": enemy.get_hitbox_half_size_pixels(),
				"room_id": room_id,
				"template_id": template_id,
			}


func _get_current_room_name() -> String:
	var player_position_meters: Vector2 = player.position / METERS_TO_PIXELS

	for room_definition in ROOM_DEFINITIONS:
		var room_id: String = str(room_definition["id"])
		var room_bounds: Rect2 = room_bounds_by_id[room_id] as Rect2
		if room_bounds.has_point(player_position_meters):
			return str(room_definition["name"])

	return "\u8d70\u5eca"


func _count_hostile_enemies() -> int:
	var hostile_count: int = 0

	for enemy_id in enemy_registry.keys():
		var enemy: Node2D = enemy_registry[enemy_id]["node"]
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if enemy.has_method("is_hostile_to_player") and not enemy.is_hostile_to_player():
			continue
		hostile_count += 1

	return hostile_count


func resolve_world_movement(current_position: Vector2, motion: Vector2, half_size_pixels: Vector2) -> Vector2:
	var resolved_position: Vector2 = current_position
	resolved_position = _resolve_axis_movement(resolved_position, Vector2(motion.x, 0.0), half_size_pixels)
	resolved_position = _resolve_axis_movement(resolved_position, Vector2(0.0, motion.y), half_size_pixels)
	return resolved_position


func _resolve_axis_movement(current_position: Vector2, motion: Vector2, half_size_pixels: Vector2) -> Vector2:
	if motion == Vector2.ZERO:
		return current_position

	var proposed_position: Vector2 = current_position + motion
	var actor_rect := Rect2(proposed_position - half_size_pixels, half_size_pixels * 2.0)

	if _is_rect_inside_walkable_region(actor_rect) and not _is_rect_blocked_by_wall(actor_rect):
		return proposed_position

	return current_position


func _is_rect_inside_walkable_region(actor_rect: Rect2) -> bool:
	for region in walkable_regions_pixels:
		var walkable_region: Rect2 = region as Rect2
		if walkable_region.encloses(actor_rect):
			return true

	return false


func _is_rect_blocked_by_wall(actor_rect: Rect2) -> bool:
	for rect_value in wall_collision_rects_pixels:
		var wall_rect: Rect2 = rect_value as Rect2
		if wall_rect.intersects(actor_rect):
			return true

	return false


func _rectangle_overlaps_circle(rect_center: Vector2, rect_half_size: Vector2, circle_center: Vector2, radius_pixels: float) -> bool:
	var closest_point: Vector2 = Vector2(
		clampf(circle_center.x, rect_center.x - rect_half_size.x, rect_center.x + rect_half_size.x),
		clampf(circle_center.y, rect_center.y - rect_half_size.y, rect_center.y + rect_half_size.y)
	)
	return closest_point.distance_to(circle_center) <= radius_pixels


func _rectangle_overlaps_sector(rect_center: Vector2, rect_half_size: Vector2, attack_center: Vector2, direction: Vector2, radius_pixels: float, arc_degrees: float) -> bool:
	var normalized_direction: Vector2 = direction.normalized()
	if normalized_direction == Vector2.ZERO:
		normalized_direction = Vector2.RIGHT

	var cosine_threshold: float = cos(deg_to_rad(arc_degrees * 0.5))
	for point in _get_rectangle_candidate_points(rect_center, rect_half_size):
		var offset: Vector2 = point - attack_center
		if offset.length() > radius_pixels:
			continue

		var candidate_direction: Vector2 = normalized_direction
		if offset != Vector2.ZERO:
			candidate_direction = offset.normalized()

		if normalized_direction.dot(candidate_direction) >= cosine_threshold:
			return true

	if not _rectangle_overlaps_circle(rect_center, rect_half_size, attack_center, radius_pixels):
		return false

	var closest_point: Vector2 = Vector2(
		clampf(attack_center.x, rect_center.x - rect_half_size.x, rect_center.x + rect_half_size.x),
		clampf(attack_center.y, rect_center.y - rect_half_size.y, rect_center.y + rect_half_size.y)
	)
	var closest_offset: Vector2 = closest_point - attack_center
	if closest_offset == Vector2.ZERO:
		return true

	return normalized_direction.dot(closest_offset.normalized()) >= cosine_threshold


func _rectangles_overlap(center_a: Vector2, half_a: Vector2, center_b: Vector2, half_b: Vector2) -> bool:
	return absf(center_a.x - center_b.x) <= (half_a.x + half_b.x) and absf(center_a.y - center_b.y) <= (half_a.y + half_b.y)


func _get_rectangle_candidate_points(rect_center: Vector2, rect_half_size: Vector2) -> Array:
	return [
		rect_center,
		Vector2(rect_center.x - rect_half_size.x, rect_center.y - rect_half_size.y),
		Vector2(rect_center.x + rect_half_size.x, rect_center.y - rect_half_size.y),
		Vector2(rect_center.x - rect_half_size.x, rect_center.y + rect_half_size.y),
		Vector2(rect_center.x + rect_half_size.x, rect_center.y + rect_half_size.y),
		Vector2(rect_center.x, rect_center.y - rect_half_size.y),
		Vector2(rect_center.x, rect_center.y + rect_half_size.y),
		Vector2(rect_center.x - rect_half_size.x, rect_center.y),
		Vector2(rect_center.x + rect_half_size.x, rect_center.y),
	]
