extends Control
@onready var net_worth_label: Label               = %net_worth
@onready var capacity_label:  Label               = %capacity
@onready var list_ui:         Control             = %ListUI
@onready var shop_ui:         Control             = %ShopUI
@onready var toilet:          SubViewportContainer = %ToiletViewportContainer
@onready var pond:            SubViewportContainer = %PondViewportContainer
@onready var fishing_ui: Control = %FishingUI

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	capacity_label.text  = "capacity: " + str(FishHandler.total_fish) + "/20"
	net_worth_label.text = "$: "        + str(PassiveSystems.net_worth)
# ── Button handlers ───────────────────────────────────────────────────────────
func _on_shop_pressed() -> void:
	shop_ui.visible = not shop_ui.visible
	if shop_ui.visible:
		list_ui.visible = false
		fishing_ui.visible = false
func _on_list_pressed() -> void:
	list_ui.visible = not list_ui.visible
	if list_ui.visible:
		shop_ui.visible = false
		fishing_ui.visible = false
		list_ui.refresh(pond.visible)
func _on_view_pressed() -> void:
	pond.visible   = not pond.visible
	toilet.visible = not toilet.visible
	if list_ui.visible:
		list_ui.refresh(pond.visible)
func _on_flush_pressed() -> void:
	var save_data = SaveManager.load_saved_data()

	var retired_ids = save_data.list_of_retired_fish.map(func(f): return f.ID)

	for fish in save_data.list_of_work_fish:
		if fish.ID not in retired_ids:
			save_data.list_of_retired_fish.append(fish)

	save_data.list_of_work_fish.clear()
	SaveManager.save_current_data(save_data)
	DisplayManager.flush_fish.emit()
	DisplayManager.display_fish_pond.emit(save_data.list_of_retired_fish)


func _on_go_fishing_pressed() -> void:
	fishing_ui.visible = not fishing_ui.visible
	if fishing_ui.visible:
		shop_ui.visible = false
		list_ui.visible = false
