extends Control
@onready var net_worth_label: Label               = %net_worth
@onready var list_ui:         Control             = %ListUI
@onready var shop_ui:         Control             = %ShopUI
@onready var toilet:          SubViewportContainer = %ToiletViewportContainer
@onready var pond:            SubViewportContainer = %PondViewportContainer
@onready var fishing_ui: Control = %FishingUI

## The keyboard terminal along the bottom (command_line.tscn); style and size
## it in the editor. The rest of the UI is kept above it.
@onready var command_line: CommandLine = %CommandLine
@onready var _main_column: VBoxContainer = $VBoxContainer
## Icon buttons down the left edge (menu, flush, view, list, shop, fishing).
@onready var _sidebar: Control = %Sidebar

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Keys drive the shop while it's open.
	command_line.target_provider = func(): return shop_ui if shop_ui.visible else null
	command_line.resized.connect(_fit_above_terminal)
	_fit_above_terminal()


## Stop the main column and the sidebar at the top of the terminal, however
## tall it is, and start the main column right of the sidebar.
func _fit_above_terminal() -> void:
	var h := command_line.size.y if command_line.visible else 0.0
	_main_column.offset_bottom = -h
	_sidebar.offset_bottom = -h
	_main_column.offset_left = _sidebar.size.x


func _process(_delta: float) -> void:
	# Whole coins only, rounded down so it never shows money you don't have yet.
	net_worth_label.text = "$ " + _with_commas(floori(PassiveSystems.net_worth))
## 1234567 -> "1,234,567"
static func _with_commas(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(-3)
	return ("-" if n < 0 else "") + digits + out

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
			FishGrowthManager.enter_pond(fish)   # base mass frozen, growth clock starts
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
