extends Control

@onready var main_page_container: MarginContainer = $MarginContainer
@onready var status_label: Label = %StatusLabel
@onready var menu_stack: VBoxContainer = %MenuStack
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var character_creation: Control = %CharacterCreation
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value_label: Label = %VolumeValueLabel

const MIN_VOLUME_DB := -80.0


func _ready() -> void:
	_sync_volume_slider_with_audio()
	_hide_settings_panel()
	_hide_character_creation()
	main_page_container.visible = true
	_grab_default_focus()
	status_label.text = "\u4e3b\u754c\u9762\u5df2\u5c31\u7eea\u3002\u540e\u7eed\u7cfb\u7edf\u53ef\u4ee5\u4ece\u8fd9\u91cc\u63a5\u5165\u3002"


func _on_start_button_pressed() -> void:
	main_page_container.visible = false
	menu_stack.visible = false
	settings_panel.visible = false
	character_creation.visible = true
	character_creation.open_creation()


func _on_settings_button_pressed() -> void:
	_show_settings_panel()
	status_label.text = "\u5df2\u8fdb\u5165\u8bbe\u7f6e\u9875\u9762\u3002"


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _grab_default_focus() -> void:
	var start_button: Button = %StartButton
	start_button.grab_focus()


func _show_settings_panel() -> void:
	_hide_character_creation()
	main_page_container.visible = true
	menu_stack.visible = false
	settings_panel.visible = true
	volume_slider.grab_focus()


func _hide_settings_panel() -> void:
	menu_stack.visible = true
	settings_panel.visible = false


func _hide_character_creation() -> void:
	character_creation.visible = false


func _show_main_menu() -> void:
	_hide_character_creation()
	_hide_settings_panel()
	main_page_container.visible = true
	menu_stack.visible = true
	_grab_default_focus()


func _on_back_button_pressed() -> void:
	_show_main_menu()
	status_label.text = "\u5df2\u8fd4\u56de\u4e3b\u754c\u9762\u3002"


func _on_volume_slider_value_changed(value: float) -> void:
	apply_master_volume(value)


func apply_master_volume(volume_percent: float) -> void:
	var clamped_percent: float = clampf(volume_percent, 0.0, 100.0)
	var bus_index: int = AudioServer.get_bus_index("Master")

	if clamped_percent <= 0.0:
		AudioServer.set_bus_volume_db(bus_index, MIN_VOLUME_DB)
	else:
		var linear_volume: float = clamped_percent / 100.0
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_volume))

	volume_value_label.text = "%d" % int(round(clamped_percent))


func _sync_volume_slider_with_audio() -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	var current_db: float = AudioServer.get_bus_volume_db(bus_index)
	var volume_percent: float

	if current_db <= MIN_VOLUME_DB:
		volume_percent = 0.0
	else:
		volume_percent = clampf(db_to_linear(current_db) * 100.0, 0.0, 100.0)

	volume_slider.value = round(volume_percent)
	apply_master_volume(volume_slider.value)


func _on_character_creation_back_requested() -> void:
	_show_main_menu()
	status_label.text = "\u5df2\u4ece\u4eba\u7269\u9009\u62e9\u9875\u9762\u8fd4\u56de\u4e3b\u754c\u9762\u3002"


func _on_character_creation_character_created(character_data: Dictionary, total_count: int) -> void:
	GameState.set_current_character(character_data)
	get_tree().change_scene_to_file("res://game/scenes/newbie_village.tscn")
