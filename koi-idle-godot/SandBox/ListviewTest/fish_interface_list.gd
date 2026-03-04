# fish_interface_list.gd
# Main controller for the fish list UI panel.
# Mirrors the shop interface pattern:
#   FishListManager    ←→  FishCardManager
#   FishViewportRenderer   (reused as-is)
#   FishLabelDisplay       (reused as-is)
#   ShopGraphManager       (reused as-is)
extends Control

# ── Scene references ──────────────────────────────────────────────────────────
# List container
@onready var fish_list_vbox: VBoxContainer = %FishListVBox

# Detail label panel (same nodes as the shop, wired to FishLabelDisplay)
@onready var name_label:   Label = %fish_name
@onready var rank_label:   Label = %fish_rank
@onready var income_label: Label = %fish_income
@onready var cost_label:   Label = %fish_cost    # add if present in your scene
@onready var sell_label:   Label = %fish_sell    # add if present in your scene

# Graphs (same references the shop uses)
@onready var distribution_graph = %bellcurve   # adjust unique names
@onready var growth_curve       = %Growth_curve
@onready var histogram_graph    = %Histogram

# Optional: a larger "selected fish" viewport, same as the shop's big preview
@onready var preview_viewport: SubViewport = %PreviewViewport  # null-safe below

# ── Internal managers ─────────────────────────────────────────────────────────
var _list_manager:    FishListManager
var _renderer:        FishViewportRenderer
var _label_display:   FishLabelDisplay
var _graph_manager:   ShopGraphManager

# Tracks the currently selected row so we can deselect it when another is picked.
var _selected_row: Control = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	print("name_label: ", name_label)
	print("rank_label: ", rank_label)
	print("income_label: ", income_label)
	print("cost_label: ", cost_label)
	print("sell_label: ", sell_label)
	assert(fish_list_vbox != null, "FishListVBox node not found — check the %FishListVBox unique name in the scene")

	_renderer = FishViewportRenderer.new()
	add_child(_renderer)

	_list_manager = FishListManager.new(fish_list_vbox)
	add_child(_list_manager)

	_label_display = FishLabelDisplay.new(
		name_label, rank_label, cost_label, income_label, sell_label
	)

	print("distribution_graph: ", distribution_graph)
	print("growth_curve: ", growth_curve)
	print("histogram_graph: ", histogram_graph)

	_graph_manager = ShopGraphManager.new(
		distribution_graph, growth_curve, histogram_graph
	)
	add_child(_graph_manager)

	_list_manager.row_hovered.connect(_on_row_hovered)
	_list_manager.row_clicked.connect(_on_row_clicked)

	var save_data = SaveManager.load_saved_data()
	var list_of_fish = save_data.list_of_work_fish
	if list_of_fish != null:
		populate_list(list_of_fish)
# ── Public API ────────────────────────────────────────────────────────────────

## Call this with your array of fish_conf resources to build the list.
func populate_list(fish_array: Array) -> void:
	_list_manager.populate(fish_array, _renderer)
	_graph_manager.refresh_histogram(fish_array)
	_clear_detail_panel()

## Clear everything — list rows, graphs, labels.
func clear_list() -> void:
	_list_manager.clear_all()
	_graph_manager.clear_all()
	_clear_detail_panel()
	_selected_row = null

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_row_hovered(fish: fish_conf) -> void:
	# Update graphs and detail labels on hover, matching shop behaviour.
	_graph_manager.update_for_fish(fish)
	_label_display.show(fish)

func _on_row_clicked(fish: fish_conf) -> void:
	# Deselect the previously selected row.
	if _selected_row and _selected_row != _get_row_for_fish(fish):
		_selected_row.deselect()

	_selected_row = _get_row_for_fish(fish)

	# Push fish into the big preview viewport if one exists.
	if preview_viewport:
		_renderer.place_fish_in_viewport(preview_viewport, fish)

	# Graphs / labels already updated by hover; re-affirm on click too.
	_graph_manager.update_for_fish(fish)
	_label_display.show(fish)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_row_for_fish(fish: fish_conf) -> Control:
	for child in fish_list_vbox.get_children():
		if child.get("fish_resource") == fish:
			return child
	return null

func _clear_detail_panel() -> void:
	# Reset labels to empty; graphs clear themselves via ShopGraphManager.
	if name_label:   name_label.text   = ""
	if rank_label:   rank_label.text   = ""
	if income_label: income_label.text = ""
	if cost_label:   cost_label.text   = ""
	if sell_label:   sell_label.text   = ""
	if preview_viewport:
		_renderer.clear_viewport(preview_viewport)
