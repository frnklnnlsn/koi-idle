#list_ui.gd
extends Control

# ── Scene references ──────────────────────────────────────────────────────────
@onready var fish_list_vbox: VBoxContainer = %FishListVBox
@onready var name_label:     Label = get_node_or_null("%fish_name")
@onready var rank_label:     Label = get_node_or_null("%fish_rank")
@onready var cost_label:     Label = get_node_or_null("%fish_cost")
@onready var sell_label:     Label = get_node_or_null("%fish_sell")
@onready var distribution_graph   = get_node_or_null("%BellcurveList")
@onready var growth_curve         = %GrowthcurveList
@onready var histogram_graph      = %HistogramList
@onready var preview_viewport: SubViewport = get_node_or_null("%PreviewViewport")
@onready var v_separator_3: VSeparator = get_node_or_null("%VSeparator3")

# Headings — static text, toggled for visibility only, never written to.
# These (and the detail labels above) are optional: not every list layout has
# them, so they may be null.
@onready var income_heading: Label = get_node_or_null("%IncomeLabelHeading")
@onready var mass_heading:   Label = get_node_or_null("%MassLabelHeading")
@onready var rank_heading:   Label = get_node_or_null("%RankLabelHeading")
@onready var id_heading:     Label = get_node_or_null("%IDLabelHeading")

# ── Internal ──────────────────────────────────────────────────────────────────
var _list_manager:  FishListManager
var _renderer:      FishViewportRenderer
var _label_display: FishLabelDisplay
var _graph_manager: ShopGraphManager
var _selected_row:  Control   = null
var _selected_fish: fish_conf = null
var _showing_pond:  bool      = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	DisplayManager.fish_caught.connect(_on_fish_caught)
	var growth_manager = get_node("/root/FishGrowthManager")
	if growth_manager:
		growth_manager.growth_updated.connect(_on_growth_updated)

	_renderer = FishViewportRenderer.new()
	add_child(_renderer)

	_list_manager = FishListManager.new(fish_list_vbox)
	add_child(_list_manager)

	_label_display = FishLabelDisplay.new(
		name_label, rank_label, cost_label, null, sell_label
	)

	_graph_manager = ShopGraphManager.new(
		distribution_graph, growth_curve, histogram_graph
	)
	_graph_manager.is_pond = _showing_pond
	add_child(_graph_manager)

	_list_manager.row_hovered.connect(_on_row_hovered)
	_list_manager.row_clicked.connect(_on_row_clicked)
	_list_manager.row_unhovered.connect(_on_row_unhovered)
	# Clicking a curve on the growth chart selects that fish's row.
	if growth_curve and growth_curve.has_signal("fish_clicked"):
		growth_curve.fish_clicked.connect(_select_from_chart)
	FishHandler.keep_fish.connect(_on_fish_list_updated)
	_update_label_visibility()

	refresh(false)

# ── Public API ────────────────────────────────────────────────────────────────
func refresh(showing_pond: bool) -> void:
	_showing_pond = showing_pond
	_graph_manager.is_pond = _showing_pond
	_update_label_visibility()
	var save_data  = SaveManager.load_saved_data()
	var fish_array = save_data.list_of_retired_fish if showing_pond else save_data.list_of_work_fish
	populate_list(fish_array)

func _on_growth_updated() -> void:
	if not _showing_pond:
		return

	var save_data = SaveManager.load_saved_data()
	if not save_data:
		return

	for child in fish_list_vbox.get_children():
		if child.get("fish_resource") == null:
			continue
		var stale_id = child.fish_resource.ID
		for fish in save_data.list_of_retired_fish:
			if fish.ID == stale_id:
				child.fish_resource = fish
				break

	_refresh_row_display_mode()

func populate_list(fish_array: Array) -> void:
	_list_manager.populate(fish_array, _renderer)
	_graph_manager.refresh_histogram(fish_array)
	_clear_detail_panel()
	_refresh_row_display_mode()

func _refresh_row_display_mode() -> void:
	for child in fish_list_vbox.get_children():
		if child.has_method("update_display"):
			child.update_display(_showing_pond)

func clear_list() -> void:
	_list_manager.clear_all()
	_graph_manager.clear_all()
	_clear_detail_panel()
	_selected_row  = null
	_selected_fish = null

# ── Signal handlers ───────────────────────────────────────────────────────────
func _on_row_hovered(fish: fish_conf) -> void:
	_graph_manager.update_for_fish(fish)
	_label_display.show(fish)
	_update_label_visibility()

## Moving off a row: the charts and details go back to the selected fish.
func _on_row_unhovered(_fish: fish_conf) -> void:
	if _selected_fish:
		_graph_manager.update_for_fish(_selected_fish)
		_label_display.show(_selected_fish)


func _select_from_chart(fish: fish_conf) -> void:
	if fish == _selected_fish:
		return
	_on_row_clicked(fish)
	if _selected_row:
		_selected_row.select()


func _on_row_clicked(fish: fish_conf) -> void:
	if _selected_fish == fish:
		_selected_fish = null
		_selected_row  = null
		return

	if _selected_row:
		_selected_row.deselect()

	_selected_fish = fish
	_selected_row  = _get_row_for_fish(fish)
	_graph_manager.update_for_fish(fish)
	_label_display.show(fish)
	_update_label_visibility()

func _on_fish_list_updated(fish_array: Array) -> void:
	if _showing_pond:
		return

	_list_manager.merge(fish_array, _renderer)

	var all_fish: Array = []
	for child in fish_list_vbox.get_children():
		if child.get("fish_resource") != null:
			all_fish.append(child.fish_resource)

	_graph_manager.refresh_histogram(all_fish)

	if _selected_fish == null:
		_clear_detail_panel()
	_refresh_row_display_mode()

# ── Helpers ───────────────────────────────────────────────────────────────────
func _update_label_visibility() -> void:
	if income_heading:
		income_heading.visible = not _showing_pond
	if mass_heading:
		mass_heading.visible = _showing_pond

func _get_row_for_fish(fish: fish_conf) -> Control:
	for child in fish_list_vbox.get_children():
		if child.get("fish_resource") != null and child.fish_resource.ID == fish.ID:
			return child
	return null

func _clear_detail_panel() -> void:
	if name_label: name_label.text = ""
	if rank_label: rank_label.text = ""
	if cost_label: cost_label.text = ""
	if sell_label: sell_label.text = ""
	if preview_viewport:
		_renderer.clear_viewport(preview_viewport)


func _on_fish_caught(fish_list: Array) -> void:
	if not _showing_pond:
		return
	for fish in fish_list:
		var row = _get_row_for_fish(fish)
		if row:
			if _selected_fish == fish:
				_selected_fish = null
				_selected_row  = null
				_clear_detail_panel()
			row.queue_free()
	var all_fish: Array = []
	for child in fish_list_vbox.get_children():
		if child.get("fish_resource") != null:
			all_fish.append(child.fish_resource)
	_graph_manager.refresh_histogram(all_fish)
