@tool
class_name RarityGraphTheme
extends Resource

# Curve properties
@export var curve_color: Color = Color.WHITE
@export var curve_width: float = 3.0

# Axis properties
@export var show_axes: bool = true
@export var axis_color: Color = Color.BLACK
@export var axis_width: float = 2.0

# Tick properties
@export var show_ticks: bool = true
@export var tick_length: float = 10.0
@export var num_x_ticks: int = 9
@export var tick_font_size: int = 16
@export var tick_text_color: Color = Color.BLACK

# Label properties
@export var show_labels: bool = true
@export var label_font_size: int = 24
@export var label_text_color: Color = Color.WHITE
@export var label_font: Font  # Custom font for labels

# Tick label properties (separate from region labels)
@export var tick_font: Font  # Custom font for axis tick labels

# Region properties
@export var show_regions: bool = true
@export var region_colors: Array[Color] = [
	Color(0.2, 0.8, 0.5, 0.8),  # Green - Common
	Color(0.3, 0.7, 1.0, 0.8),  # Light blue - Uncommon
	Color(0.4, 0.6, 1.0, 0.8),  # Blue - Rare
	Color(1.0, 0.6, 0.2, 0.8),  # Orange - Epic
	Color(1.0, 0.4, 0.4, 0.8)   # Red - Legendary
]

# Marker properties
@export var marker_color: Color = Color.RED
@export var marker_dot_radius: float = 6.0
@export var marker_outline_color: Color = Color.WHITE
@export var marker_outline_width: float = 0.0

# Marker line properties
@export var show_marker_line: bool = true
@export var marker_line_color: Color = Color.RED
@export var marker_line_width: float = 2.0
@export var dash_length: float = 10.0
@export var dash_gap: float = 5.0

# Convenience constructor
func _init():
	pass

# Create preset themes
static func create_dark_theme() -> RarityGraphTheme:
	var theme = RarityGraphTheme.new()
	theme.curve_color = Color(0.9, 0.9, 0.9)
	theme.axis_color = Color(0.7, 0.7, 0.7)
	theme.tick_text_color = Color(0.8, 0.8, 0.8)
	theme.label_text_color = Color(0.9, 0.9, 0.9)
	theme.marker_color = Color.CYAN
	theme.marker_line_color = Color.CYAN
	theme.marker_outline_color = Color.WHITE
	theme.marker_outline_width = 1.0
	
	# Load custom fonts from your assets folder
	theme.label_font = preload("res://assets/fonts/BitcountSingle-Regular.ttf")
	theme.tick_font = preload("res://assets/fonts/BitcountSingle-Regular.ttf")
	
	return theme

static func create_light_theme() -> RarityGraphTheme:
	var theme = RarityGraphTheme.new()
	theme.curve_color = Color.BLACK
	theme.axis_color = Color.BLACK
	theme.tick_text_color = Color.BLACK
	theme.label_text_color = Color.BLACK
	theme.marker_color = Color.RED
	theme.marker_line_color = Color.RED
	theme.marker_outline_color = Color.BLACK
	theme.marker_outline_width = 1.0
	
	# Use the same or different fonts for light theme
	theme.label_font = preload("res://assets/fonts/BitcountSingle-Regular.ttf")
	theme.tick_font = preload("res://assets/fonts/BitcountSingle-Regular.ttf")
	
	return theme

static func create_neon_theme() -> RarityGraphTheme:
	var theme = RarityGraphTheme.new()
	theme.curve_color = Color.MAGENTA
	theme.curve_width = 4.0
	theme.axis_color = Color.CYAN
	theme.tick_text_color = Color.YELLOW
	theme.label_text_color = Color.YELLOW
	theme.marker_color = Color.YELLOW
	theme.marker_line_color = Color.YELLOW
	theme.marker_outline_color = Color.MAGENTA
	theme.marker_outline_width = 2.0
	theme.dash_length = 8.0
	theme.dash_gap = 8.0
	return theme

static func create_minimal_theme() -> RarityGraphTheme:
	var theme = RarityGraphTheme.new()
	theme.curve_color = Color(0.3, 0.3, 0.3)
	theme.curve_width = 2.0
	theme.show_regions = false
	theme.show_labels = false
	theme.axis_color = Color(0.5, 0.5, 0.5)
	theme.axis_width = 1.0
	theme.tick_text_color = Color(0.6, 0.6, 0.6)
	theme.marker_color = Color.RED
	theme.marker_line_color = Color.RED
	theme.show_marker_line = false
	return theme
