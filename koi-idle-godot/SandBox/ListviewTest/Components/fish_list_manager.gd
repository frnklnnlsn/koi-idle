# fish_list_manager.gd
# Analogous to FishCardManager — manages fish rows inside a VBoxContainer.
# Rows are appended in order (no center-positioning needed for a vertical list).
class_name FishListManager
extends Node

signal row_hovered(fish: fish_conf)
signal row_clicked(fish: fish_conf)
signal rows_changed

var vbox: VBoxContainer
var row_scene = preload("res://SandBox/ListviewTest/scenes/fish_list_row.tscn")


# ── Init ──────────────────────────────────────────────────────────────────────

func _init(list_vbox: VBoxContainer) -> void:
	vbox = list_vbox

# ── Public API ────────────────────────────────────────────────────────────────

## Instantiate and populate a row for the given fish resource.
## Pass in a FishViewportRenderer so the viewport is filled the same way cards are.
func add_row(fish: fish_conf, renderer: FishViewportRenderer) -> Control:
	var row = row_scene.instantiate()
	assert(row is HBoxContainer and row.get_script() != null, 
		   "fish_list_row.tscn root node is missing fish_list_row.gd script")

	row.fish_resource = fish
	renderer.place_fish_in_viewport(row.get_node("%FishViewport"), fish)
	_populate_row_labels(row, fish)
	_connect_row_signals(row)
	vbox.add_child(row)
	rows_changed.emit()
	return row

## Populate the list from an array of fish_conf resources in one call.
func populate(fish_array: Array, renderer: FishViewportRenderer) -> void:
	clear_all()
	for fish in fish_array:
		add_row(fish, renderer)

## Remove rows whose fish_resource matches anything in fish_list.
func remove_rows(fish_list: Array) -> void:
	for fish in fish_list:
		for child in vbox.get_children():
			if child.get("fish_resource") == fish:
				child.queue_free()
	rows_changed.emit()

## Wipe every row out of the list.
func clear_all() -> void:
	if not vbox:
		push_error("FishListManager: vbox is null — was it passed correctly in _init()?")
		return
	for child in vbox.get_children():
		child.queue_free()
	rows_changed.emit()

# ── Private ───────────────────────────────────────────────────────────────────

## Fill the inline labels that live on the row itself (name, rank, income).
## The full detail panel is driven by FishLabelDisplay on hover/click.
func _populate_row_labels(row: Control, fish: fish_conf) -> void:
	var name_l   = row.get_node_or_null("%RowNameLabel")
	var rank_l   = row.get_node_or_null("%RowRankLabel")
	var income_l = row.get_node_or_null("%RowIncomeLabel")
	print("row labels: ", name_l, rank_l, income_l)
	if name_l:   name_l.text   = str(fish.ID)
	if rank_l:   rank_l.text   = str(fish.rank)
	if income_l: income_l.text = str(fish.income)

func _connect_row_signals(row: Control) -> void:
	if row.has_signal("row_hovered"):
		row.row_hovered.connect(_on_row_hovered)
	if row.has_signal("row_clicked"):
		row.row_clicked.connect(_on_row_clicked)

func _on_row_hovered(fish: fish_conf) -> void:
	row_hovered.emit(fish)

func _on_row_clicked(fish: fish_conf) -> void:
	row_clicked.emit(fish)
