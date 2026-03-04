# reset_save_button.gd
extends Button

func _on_pressed() -> void:
	SaveManager.reset_save_data()
	print("SaveManager: Save data reset.")
