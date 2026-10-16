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
## Shop-only bar down the right edge: buy buttons, keep / trash lights.
@onready var _shop_bar: Control = %ShopBar
@onready var _keep_light: TextureRect = %KeepLight
@onready var _trash_light: TextureRect = %TrashLight

## Light colours while a card is dragged into a zone; OFF otherwise.
@export var keep_on := Color(0.3, 0.9, 0.4)
@export var trash_on := Color(1.0, 0.3, 0.3)
@export var light_off := Color(0.45, 0.47, 0.52, 0.7)

## Panels that Esc closes (shop, list, fishing). For a new pop-up, add its
## node to this group (Node tab > Groups in the editor, or add_to_group).
const ESC_CLOSES := "esc_closes"

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Keys drive the shop while it's open.
	command_line.target_provider = func(): return shop_ui if shop_ui.visible else null
	command_line.resized.connect(_fit_above_terminal)
	# S opens / closes the shop from anywhere.
	command_line.global_keys["s"] = _on_shop_pressed
	# Esc closes the open panel (once nothing is half typed in the terminal).
	command_line.global_keys["escape"] = close_open_panel
	for panel in [shop_ui, list_ui, fishing_ui]:
		panel.add_to_group(ESC_CLOSES)
	shop_ui.visibility_changed.connect(_on_shop_visibility)
	shop_ui.drag_zone_changed.connect(_on_drag_zone)
	shop_ui.action_message.connect(command_line.say)
	_on_shop_visibility()
	_on_drag_zone("")
	_fit_above_terminal()


## Stop the main column and the sidebar at the top of the terminal, however
## tall it is, and start the main column right of the sidebar.
func _fit_above_terminal() -> void:
	var h := command_line.size.y if command_line.visible else 0.0
	_main_column.offset_bottom = -h
	_sidebar.offset_bottom = -h
	_shop_bar.offset_bottom = -h
	_main_column.offset_left = _sidebar.size.x
	_main_column.offset_right = -_shop_bar.size.x if _shop_bar.visible else 0.0


## Hides the first visible panel in the ESC_CLOSES group. Returns true if
## one was closed.
func close_open_panel() -> bool:
	for panel in get_tree().get_nodes_in_group(ESC_CLOSES):
		if panel is CanvasItem and panel.is_visible_in_tree():
			panel.visible = false
			return true
	return false


func _on_shop_visibility() -> void:
	_shop_bar.visible = shop_ui.visible
	_fit_above_terminal()


func _on_drag_zone(zone: String) -> void:
	_keep_light.modulate = keep_on if zone == "keep" else light_off
	_trash_light.modulate = trash_on if zone == "trash" else light_off


func _on_buy_pressed() -> void:
	command_line.say(shop_ui.buy_one())


func _on_buy_max_pressed() -> void:
	command_line.say(shop_ui.fill_pool())


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
