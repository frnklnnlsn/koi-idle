extends Control

# References to your graph nodes
@onready var control: Control = $"."
@onready var rarity_graph: RarityGraph = %RarityGraphExample

@onready var v_box_container: VBoxContainer = $VBoxContainer
@onready var theme_buttons: HBoxContainer = $VBoxContainer/ThemeButtons
@onready var value_slider: HSlider = $VBoxContainer/ValueSlider
@onready var value_label: Label = $VBoxContainer/ValueLabel







# Example: Signal from your game system
signal item_rarity_calculated(rarity_value: float)

func _ready():
	setup_ui()
	connect_signals()
	
	# Example: Simulate receiving a rarity value from your game
	item_rarity_calculated.emit(3.5)

func setup_ui():
	# Setup theme buttons
	create_theme_button("Dark", RarityGraphTheme.create_dark_theme())
	create_theme_button("Light", RarityGraphTheme.create_light_theme())
	create_theme_button("Neon", RarityGraphTheme.create_neon_theme())
	create_theme_button("Minimal", RarityGraphTheme.create_minimal_theme())
	
	# Setup value slider
	value_slider.min_value = 0.0
	value_slider.max_value = 10.0
	value_slider.step = 0.1
	value_slider.value = 3.5

func create_theme_button(theme_name: String, theme: RarityGraphTheme):
	var button = Button.new()
	button.text = theme_name
	button.pressed.connect(func(): rarity_graph.set_graph_theme(theme))
	theme_buttons.add_child(button)

func connect_signals():
	# Connect your game's rarity calculation to the graph
	item_rarity_calculated.connect(_on_item_rarity_calculated)
	
	# Connect slider for testing
	value_slider.value_changed.connect(_on_value_slider_changed)
	
	# Connect graph's marker value changed signal (optional)
	rarity_graph.marker_value_changed.connect(_on_marker_value_changed)

func _on_item_rarity_calculated(rarity_value: float):
	# This is how you'd receive rarity values from your game systems
	rarity_graph.set_marker_value(rarity_value)
	value_label.text = "Rarity Value: %.2f" % rarity_value

func _on_value_slider_changed(value: float):
	# For testing purposes
	rarity_graph.set_marker_value(value)
	value_label.text = "Rarity Value: %.2f" % value

func _on_marker_value_changed(value: float):
	# Optional: React to marker changes
	print("Marker moved to: ", value)

# Example methods you might call from your game systems
func show_item_drop(item_rarity: float):
	rarity_graph.set_marker_value(item_rarity)

func clear_rarity_display():
	rarity_graph.clear_marker()

func set_graph_theme_by_name(theme_name: String):
	match theme_name.to_lower():
		"dark":
			rarity_graph.set_graph_theme(RarityGraphTheme.create_dark_theme())
		"light":
			rarity_graph.set_graph_theme(RarityGraphTheme.create_light_theme())
		"neon":
			rarity_graph.set_graph_theme(RarityGraphTheme.create_neon_theme())
		"minimal":
			rarity_graph.set_graph_theme(RarityGraphTheme.create_minimal_theme())
