# settings_menu.gd
# The settings window (menu button, top left, or Esc with nothing open).
# Its frame (dim backdrop, panel, title, tabs, buttons) is settings_menu.tscn;
# restyle it there. The rows are built from Settings.SPEC, one tab per group,
# so a setting added there shows up here by itself.
# Changes apply and save straight away; there's no "apply" step.
class_name SettingsMenu
extends Control

## Width of the label column.
@export var label_width := 300
## Width of sliders and drop-downs.
@export var control_width := 220
@export var row_font_size := 15

@onready var _tabs: TabContainer = %Tabs
var _controls := {}   # key -> the control showing it


func _ready() -> void:
	visible = false
	%Close.pressed.connect(close)
	%Done.pressed.connect(close)
	%Reset.pressed.connect(Settings.reset_to_defaults)
	%Dim.gui_input.connect(_on_dim_input)
	Settings.changed.connect(_on_setting_changed)
	_build()


func open() -> void:
	visible = true
	_refresh_enabled()


func close() -> void:
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


# While open, the menu takes every key: Esc closes it, the rest are ignored
# so they don't drive the shop behind it.
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		close()


func _on_dim_input(event: InputEvent) -> void:
	# Clicking outside the window closes it.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


# --- Rows ---------------------------------------------------------------------

func _build() -> void:
	var grids := {}
	for s in Settings.SPEC:
		var group: String = s["key"].get_slice("/", 0)
		if group not in grids:
			grids[group] = _add_tab(Settings.TAB_NAMES.get(group, group.capitalize()))
		var grid: GridContainer = grids[group]
		var label := Label.new()
		label.text = s["label"]
		label.custom_minimum_size.x = label_width
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", row_font_size)
		grid.add_child(label)
		var control := _make_control(s)
		# Every control sits in a column of the same width, so the window
		# doesn't change size between tabs.
		var cell := HBoxContainer.new()
		cell.custom_minimum_size.x = control_width
		cell.add_child(control)
		grid.add_child(cell)
		_controls[s["key"]] = control


func _add_tab(title: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	margin.add_child(grid)
	scroll.add_child(margin)
	_tabs.add_child(scroll)
	return grid


func _make_control(s: Dictionary) -> Control:
	var key: String = s["key"]
	var value = Settings.get_value(key)
	match s["type"]:
		"slider":
			var row := HBoxContainer.new()
			var slider := HSlider.new()
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = 0.01
			slider.value = value
			# Slider + percent label together are control_width wide, like the rest.
			slider.custom_minimum_size.x = control_width - 48
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slider.focus_mode = Control.FOCUS_NONE
			var pct := Label.new()
			pct.name = "Percent"
			pct.custom_minimum_size.x = 44
			pct.text = "%d%%" % roundi(value * 100.0)
			slider.value_changed.connect(func(v):
				pct.text = "%d%%" % roundi(v * 100.0)
				Settings.set_value(key, v))
			row.add_child(slider)
			row.add_child(pct)
			return row
		"toggle":
			var check := CheckButton.new()
			check.button_pressed = value
			check.focus_mode = Control.FOCUS_NONE
			check.flat = true   # just the switch, no button box
			check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			check.toggled.connect(func(on): Settings.set_value(key, on))
			return check
		"choice":
			var pick := OptionButton.new()
			for o in s["options"]:
				pick.add_item(o)
			pick.selected = value
			pick.custom_minimum_size.x = control_width
			pick.focus_mode = Control.FOCUS_NONE
			pick.item_selected.connect(func(i): Settings.set_value(key, i))
			return pick
	return Control.new()


## Keeps the rows in step when a value changes from elsewhere (Reset).
func _on_setting_changed(key: String, value: Variant) -> void:
	var c: Control = _controls.get(key)
	if c is CheckButton:
		c.set_pressed_no_signal(value)
	elif c is OptionButton:
		c.selected = value
	elif c is HBoxContainer:
		(c.get_child(0) as HSlider).set_value_no_signal(value)
		(c.get_node("Percent") as Label).text = "%d%%" % roundi(value * 100.0)
	_refresh_enabled()


## Window size only matters when windowed.
func _refresh_enabled() -> void:
	var size_pick: OptionButton = _controls.get("display/window_size")
	if size_pick:
		size_pick.disabled = Settings.get_value("display/window_mode") == 1
