extends Control

signal fish_caught(fish: fish_conf)

@onready var fishing_status: RichTextLabel = %FishingStatus
@onready var fish_stats: Label = %FishStats
@onready var fishing_button: Button = %FishingButton
@onready var keep_button: Button = %KeepButton
@onready var release_button: Button = %ReleaseButton
@onready var leave_on_button: Button = %LeaveOnButton
@onready var fishing_timer: Timer = $FishingTimer

var current_fish: fish_conf = null

func _ready() -> void:
	fishing_status.bbcode_enabled = true
	fishing_status.visible_ratio = 1.0  # <-- add this, defaults to 0 in some cases
	fishing_timer.wait_time = 2.0
	fishing_timer.one_shot = true
	fishing_timer.timeout.connect(_on_fishing_timer_timeout)
	_set_action_buttons_disabled(true)



func _on_keep_pressed() -> void:
	if current_fish == null:
		return
	var save_data = SaveManager.load_saved_data()
	save_data.list_of_retired_fish.erase(current_fish)
	SaveManager.save_current_data(save_data)
	DisplayManager.fish_caught.emit([current_fish])
	_reset_ui()

func _on_release_pressed() -> void:
	_reset_ui()

func _on_leave_on_pressed() -> void:
	pass # Functionality to be added later

func _set_action_buttons_disabled(disabled: bool) -> void:
	keep_button.disabled = disabled
	release_button.disabled = disabled
	leave_on_button.disabled = disabled


func _on_fishing_button_pressed() -> void:
	var save_data = SaveManager.load_saved_data()
	if save_data.list_of_retired_fish.is_empty():
		fishing_status.text = "[center]No Fish Available!"
		return
	fishing_button.disabled = true
	_set_action_buttons_disabled(true)
	fish_stats.text = ""
	current_fish = null
	fishing_status.text = "[center][wave amp=20 freq=5 connected=1]Waiting...[/wave]"
	fishing_timer.start()

func _on_fishing_timer_timeout() -> void:
	var save_data = SaveManager.load_saved_data()
	if save_data.list_of_retired_fish.is_empty():
		fishing_status.parse_bbcode("No fish available!")
		fishing_button.disabled = false
		return
	var random_index = randi() % save_data.list_of_retired_fish.size()
	current_fish = save_data.list_of_retired_fish[random_index]
	fishing_status.text = "[center]Caught!"
	fish_stats.text = "Mass: " + str(current_fish.mass)
	fishing_button.disabled = false
	_set_action_buttons_disabled(false)

func _reset_ui() -> void:
	current_fish = null
	fishing_status.parse_bbcode("")
	fish_stats.text = ""
	_set_action_buttons_disabled(true)
