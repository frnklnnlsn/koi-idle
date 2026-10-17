# ui_palette.gd
# The UI's colours, in one place. Edit ui_palette.tres in the Inspector, then
# press "Rebuild theme" there: that regenerates ui_theme.tres (the project's
# GUI theme, set in Project Settings > GUI > Theme > Custom), which colours
# every panel, button, label and chart frame. Colours drawn by code (keep /
# trash lights, selection, chart dots and bars) read the palette directly, so
# they change on the next run.
#
# Fish rarity colours (card backgrounds) are separate: FishStats.TIERS.
@tool
class_name UIPalette
extends Resource

const PATH := "res://game_parts/user_interface/theme/ui_palette.tres"
const THEME_PATH := "res://game_parts/user_interface/theme/ui_theme.tres"

@export_group("Surfaces")
## Behind everything (also the project's clear colour).
@export var background := Color("0e112d")
## Bars, terminal, buttons.
@export var panel := Color("161a3f")
## Chart and card backgrounds, a step darker than panels.
@export var inset := Color("0b0d24")
@export var border := Color("2c3270")

@export_group("Text")
@export var text := Color("e4f2d8")
@export var text_dim := Color("8a90bd")

@export_group("Highlights")
## Cursor, hover, the selected fish in charts, the typed prompt, the money box.
@export var accent := Color("b39d25")
## Box-selected fish (cards and charts).
@export var picked := Color("9afd60")
## Keep zone / light.
@export var keep := Color("12a43e")
## Trash (recycle) zone / light.
@export var trash := Color("a43e10")

@export_group("Charts")
## Dots and bars that aren't highlighted.
@export var chart_mark := Color("5d6bb5")
## Growth curves that aren't highlighted.
@export var chart_line := Color(0.42, 0.47, 0.75, 0.5)

@export_tool_button("Rebuild theme") var _rebuild_button = rebuild_theme

static var _cached: UIPalette


## The game's palette (ui_palette.tres).
static func get_palette() -> UIPalette:
	if _cached == null:
		_cached = load(PATH) if ResourceLoader.exists(PATH) else UIPalette.new()
	return _cached


## Regenerates ui_theme.tres from these colours.
func rebuild_theme() -> void:
	var err := ResourceSaver.save(make_theme(), THEME_PATH)
	if err != OK:
		push_error("UIPalette: couldn't save %s (%s)" % [THEME_PATH, error_string(err)])
		return
	ProjectSettings.set_setting("rendering/environment/defaults/default_clear_color", background)
	if Engine.is_editor_hint():
		ProjectSettings.save()
	print("UIPalette: rebuilt ", THEME_PATH)


func make_theme() -> Theme:
	var t := Theme.new()

	# Panels
	var panel_box := _box(panel, border, 1)
	for type in ["PanelContainer", "Panel"]:
		t.set_stylebox("panel", type, panel_box)

	# Text
	for type in ["Label", "Button", "LineEdit", "CheckBox", "OptionButton", "ItemList", "Tree"]:
		t.set_color("font_color", type, text)
	t.set_color("font_hover_color", "Button", text)
	t.set_color("font_pressed_color", "Button", accent)
	t.set_color("font_hover_pressed_color", "Button", accent)
	t.set_color("font_focus_color", "Button", text)
	t.set_color("font_disabled_color", "Button", text_dim)

	# Buttons: icons are white, tinted here.
	t.set_stylebox("normal", "Button", _box(panel, border, 1, 3, 4))
	t.set_stylebox("hover", "Button", _box(panel.lerp(accent, 0.15), accent, 1, 3, 4))
	t.set_stylebox("pressed", "Button", _box(panel.lerp(accent, 0.3), accent, 1, 3, 4))
	t.set_stylebox("hover_pressed", "Button", _box(panel.lerp(accent, 0.35), accent, 1, 3, 4))
	t.set_stylebox("disabled", "Button", _box(panel, border.darkened(0.3), 1, 3, 4))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("icon_normal_color", "Button", text)
	t.set_color("icon_hover_color", "Button", accent)
	t.set_color("icon_pressed_color", "Button", accent)
	t.set_color("icon_hover_pressed_color", "Button", accent)
	t.set_color("icon_focus_color", "Button", text)

	# Text boxes
	t.set_stylebox("normal", "LineEdit", _box(inset, border, 1, 3, 4))
	t.set_stylebox("focus", "LineEdit", _box(inset, accent, 1, 3, 4))
	t.set_color("caret_color", "LineEdit", accent)
	t.set_color("font_placeholder_color", "LineEdit", text_dim)
	t.set_color("selection_color", "LineEdit", Color(accent, 0.35))

	# Tooltips
	t.set_stylebox("panel", "TooltipPanel", _box(inset, accent, 1, 3, 6))
	t.set_color("font_color", "TooltipLabel", text)

	# Charts (TauPlot): darker frame, dim axes
	t.set_type_variation("TauPlot", "PanelContainer")
	t.set_stylebox("panel", "TauPlot", _box(inset, border, 1, 3, 4))
	t.set_color("xy_axis_color", "TauPlot", text_dim)
	t.set_color("font_color", "TauPlot", text_dim)
	t.set_type_variation("TauPlotTitle", "Label")
	t.set_color("font_color", "TauPlotTitle", text)

	# Named looks used by the main UI scenes (theme_type_variation):
	# Terminal      the command line panel along the bottom
	t.set_type_variation("Terminal", "PanelContainer")
	var term := _box(inset, border, 0, 0)
	term.border_width_top = 1
	term.content_margin_left = 10
	term.content_margin_right = 10
	term.content_margin_top = 6
	term.content_margin_bottom = 4
	t.set_stylebox("panel", "Terminal", term)
	# Prompt        what's been typed in the terminal
	t.set_type_variation("Prompt", "Label")
	t.set_color("font_color", "Prompt", accent)
	# DimLabel      secondary text (terminal status)
	t.set_type_variation("DimLabel", "Label")
	t.set_color("font_color", "DimLabel", text_dim)
	# MoneyBox      the money counter in the top bar
	t.set_type_variation("MoneyBox", "Label")
	var money := _box(inset, accent, 1, 4)
	money.content_margin_left = 8
	money.content_margin_right = 8
	t.set_stylebox("normal", "MoneyBox", money)
	t.set_color("font_color", "MoneyBox", text)
	# FishCardButton  the frame of a fish card in the shop
	t.set_type_variation("FishCardButton", "Button")
	t.set_stylebox("normal", "FishCardButton", _box(Color(0, 0, 0, 0), border.lightened(0.25), 2, 2))
	t.set_stylebox("hover", "FishCardButton", _box(Color(accent, 0.25), accent, 2, 2))
	t.set_stylebox("pressed", "FishCardButton", _box(Color(accent, 0.35), accent, 2, 2))
	t.set_stylebox("hover_pressed", "FishCardButton", _box(Color(accent, 0.35), accent, 2, 2))
	t.set_stylebox("focus", "FishCardButton", StyleBoxEmpty.new())
	return t


static func _box(bg: Color, edge: Color, width := 1, radius := 0, margin := -1) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = edge
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	if margin >= 0:
		b.set_content_margin_all(margin)
	return b
