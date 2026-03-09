# debug_panel.gd
# Attach to the DebugPanel CanvasLayer node
# Wires all the UI controls back to fish_test_ground
extends CanvasLayer

# --- References set by parent ---
var ground  # fish_test_ground node, set via init()

# --- UI node refs ---
# Spawn controls
@onready var spawn_count_slider:  HSlider  = %SpawnCountSlider
@onready var spawn_count_label:   Label    = %SpawnCountLabel
@onready var spawn_button:        Button   = %SpawnButton
@onready var clear_button:        Button   = %ClearButton

# Boundary
@onready var boundary_slider:     HSlider  = %BoundarySlider
@onready var boundary_label:      Label    = %BoundaryLabel

# Camera zoom
@onready var zoom_slider:         HSlider  = %ZoomSlider
@onready var zoom_label:          Label    = %ZoomLabel

# Fish state override
@onready var state_option:        OptionButton = %StateOption

# Speed
@onready var speed_slider:        HSlider  = %SpeedSlider
@onready var speed_label:         Label    = %SpeedLabel

# Shadow
@onready var shadow_toggle:       CheckButton = %ShadowToggle
@onready var shadow_scale_slider: HSlider  = %ShadowScaleSlider
@onready var shadow_scale_label:  Label    = %ShadowScaleLabel
@onready var shadow_opacity_slider: HSlider = %ShadowOpacitySlider
@onready var shadow_opacity_label:  Label   = %ShadowOpacityLabel

# Stats
@onready var fish_count_label:    Label    = %FishCountLabel
@onready var fps_label:           Label    = %FpsLabel

# Panel toggle
@onready var toggle_button:       Button   = %TogglePanelButton
@onready var panel_body:          Control  = %PanelBody

#Fish movement tweaking
@onready var wave_amplitude_slider:   HSlider = %WaveAmplitudeSlider
@onready var wave_amplitude_label:    Label   = %WaveAmplitudeLabel
@onready var wave_frequency_slider:   HSlider = %WaveFrequencySlider
@onready var wave_frequency_label:    Label   = %WaveFrequencyLabel
@onready var wave_start_slider:       HSlider = %WaveStartSlider
@onready var wave_start_label:        Label   = %WaveStartLabel
@onready var wave_phase_slider:       HSlider = %WavePhaseSlider
@onready var wave_phase_label:        Label   = %WavePhaseLabel

var _panel_visible: bool = true


func init(test_ground) -> void:
	ground = test_ground


func _ready() -> void:
	_setup_state_options()
	_set_defaults()
	_connect_signals()


func _process(_delta: float) -> void:
	# Live stats
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	if fish_count_label and ground:
		fish_count_label.text = "Fish: %d / 50" % ground._fish_nodes.size()


# ------------------------------------------------------------------ Setup

func _setup_state_options() -> void:
	if not state_option:
		return
	state_option.clear()
	state_option.add_item("Auto (no override)", -1)
	state_option.add_item("Very Slow",   0)
	state_option.add_item("Accelerating",1)
	state_option.add_item("Slow Swim",   2)
	state_option.add_item("Fast Swim",   3)
	state_option.add_item("Decelerating",4)
	state_option.add_item("Eating",      5)
	state_option.selected = 0


func _set_defaults() -> void:
	if spawn_count_slider:
		spawn_count_slider.min_value = 1
		spawn_count_slider.max_value = 50
		spawn_count_slider.value     = 1
		spawn_count_label.text       = "Spawn: 1"

	if boundary_slider:
		boundary_slider.min_value = 100
		boundary_slider.max_value = 1200
		boundary_slider.value     = 700
		boundary_label.text       = "Boundary: 700"

	if zoom_slider:
		zoom_slider.min_value = 0.01
		zoom_slider.max_value = 0.2
		zoom_slider.step      = 0.005
		zoom_slider.value     = 0.075
		zoom_label.text       = "Zoom: 0.075"

	if speed_slider:
		speed_slider.min_value = 0.01
		speed_slider.max_value = 3.0
		speed_slider.step      = 0.005
		speed_slider.value     = 0.1
		speed_label.text       = "Speed x1.0"

	if shadow_scale_slider:
		shadow_scale_slider.min_value = 0.3
		shadow_scale_slider.max_value = 1.0
		shadow_scale_slider.step      = 0.05
		shadow_scale_slider.value     = 0.75
		shadow_scale_label.text       = "Shadow Scale: 0.75"

	if shadow_opacity_slider:
		shadow_opacity_slider.min_value = 0.0
		shadow_opacity_slider.max_value = 1.0
		shadow_opacity_slider.step      = 0.05
		shadow_opacity_slider.value     = 0.45
		shadow_opacity_label.text       = "Shadow Alpha: 0.45"

	if shadow_toggle:
		shadow_toggle.button_pressed = false

# ------------------------------------------------------------------ fish behavior tweaks

	if wave_amplitude_slider:
		wave_amplitude_slider.min_value = 0.05
		wave_amplitude_slider.max_value = 10.0
		wave_amplitude_slider.step      = 0.05
		wave_amplitude_slider.value     = 8.0
		wave_amplitude_label.text       = "Wave Amplitude: 8.0"

	if wave_frequency_slider:
		wave_frequency_slider.min_value = 0.5
		wave_frequency_slider.max_value = 10.0
		wave_frequency_slider.step      = 0.1
		wave_frequency_slider.value     = 3.0
		wave_frequency_label.text       = "Wave Frequency: 3.0"

	if wave_start_slider:
		wave_start_slider.min_value = 0.0
		wave_start_slider.max_value = 0.95
		wave_start_slider.step      = 0.05
		wave_start_slider.value     = 0.4
		wave_start_label.text       = "Wave Start: 0.40"

	if wave_phase_slider:
		wave_phase_slider.min_value = 0.1
		wave_phase_slider.max_value = 5.0
		wave_phase_slider.step      = 0.05
		wave_phase_slider.value     = 0.8
		wave_phase_label.text       = "Phase Step: 0.80"


func _connect_signals() -> void:
	if spawn_button:        spawn_button.pressed.connect(_on_spawn_pressed)
	if clear_button:        clear_button.pressed.connect(_on_clear_pressed)
	if boundary_slider:     boundary_slider.value_changed.connect(_on_boundary_changed)
	if zoom_slider:         zoom_slider.value_changed.connect(_on_zoom_changed)
	if speed_slider:        speed_slider.value_changed.connect(_on_speed_changed)
	if state_option:        state_option.item_selected.connect(_on_state_selected)
	if shadow_toggle:       shadow_toggle.toggled.connect(_on_shadow_toggled)
	if shadow_scale_slider: shadow_scale_slider.value_changed.connect(_on_shadow_scale_changed)
	if shadow_opacity_slider: shadow_opacity_slider.value_changed.connect(_on_shadow_opacity_changed)
	if spawn_count_slider:  spawn_count_slider.value_changed.connect(_on_spawn_count_changed)
	if toggle_button:       toggle_button.pressed.connect(_on_toggle_panel)
	if wave_amplitude_slider:  wave_amplitude_slider.value_changed.connect(_on_wave_amplitude_changed)
	if wave_frequency_slider:  wave_frequency_slider.value_changed.connect(_on_wave_frequency_changed)
	if wave_start_slider:      wave_start_slider.value_changed.connect(_on_wave_start_changed)
	if wave_phase_slider:      wave_phase_slider.value_changed.connect(_on_wave_phase_changed)


# ------------------------------------------------------------------ Handlers

func _on_wave_amplitude_changed(value: float) -> void:
	wave_amplitude_label.text = "Wave Amplitude: %.1f" % value
	if ground:
		ground.set_all_fish_wave_amplitude(value)

func _on_wave_frequency_changed(value: float) -> void:
	wave_frequency_label.text = "Wave Frequency: %.1f" % value
	if ground:
		ground.set_all_fish_wave_frequency(value)

func _on_wave_start_changed(value: float) -> void:
	wave_start_label.text = "Wave Start: %.2f" % value
	if ground:
		ground.set_all_fish_wave_start(value)

func _on_wave_phase_changed(value: float) -> void:
	wave_phase_label.text = "Phase Step: %.2f" % value
	if ground:
		ground.set_all_fish_wave_phase(value)

func _on_spawn_pressed() -> void:
	if not ground:
		return
	var count = int(spawn_count_slider.value)
	# Build dummy fish_conf resources for testing
	# In real use you'd pass in actual resources from FishHandler
	var test_array = []
	for i in count:
		test_array.append(_make_test_fish_conf())
	ground.spawn_fish(test_array)


func _on_clear_pressed() -> void:
	if ground:
		ground.clear_all_fish()


func _on_boundary_changed(value: float) -> void:
	boundary_label.text = "Boundary: %d" % int(value)
	if ground:
		ground.set_boundary_radius(value)


func _on_zoom_changed(value: float) -> void:
	zoom_label.text = "Zoom: %.2f" % value
	if ground:
		ground.set_camera_zoom(value)


func _on_speed_changed(value: float) -> void:
	speed_label.text = "Speed x%.2f" % value
	if ground:
		ground.set_all_fish_speed_multiplier(value)


func _on_state_selected(index: int) -> void:
	if not ground:
		return
	# index 0 = auto (-1), indices 1-6 = states 0-5
	var state = index - 1
	if state >= 0:
		ground.set_all_fish_state(state)


func _on_shadow_toggled(pressed: bool) -> void:
	if ground:
		ground.set_shadow_enabled(pressed)


func _on_shadow_scale_changed(value: float) -> void:
	shadow_scale_label.text = "Shadow Scale: %.2f" % value
	if ground:
		ground.set_shadow_scale(value)


func _on_shadow_opacity_changed(value: float) -> void:
	shadow_opacity_label.text = "Shadow Alpha: %.2f" % value
	if ground:
		ground.set_shadow_opacity(value)


func _on_spawn_count_changed(value: float) -> void:
	spawn_count_label.text = "Spawn: %d" % int(value)


func _on_toggle_panel() -> void:
	_panel_visible = !_panel_visible
	if panel_body:
		panel_body.visible = _panel_visible
	toggle_button.text = "◀ Panel" if _panel_visible else "▶ Panel"


# ------------------------------------------------------------------ Test helper

## Creates a minimal fish_conf for testing without needing saved resources
func _make_test_fish_conf() -> fish_conf:
	var conf       = fish_conf.new()
	conf.seed      = randi()
	conf.frequency = randf_range(0.1, 0.5)
	conf.noise_type_index = randi() % 4
	# Simple two-color gradient
	conf.offsets   = PackedFloat32Array([0.0, 1.0])
	conf.colors    = PackedColorArray([
		Color(randf(), randf(), randf()),
		Color(randf(), randf(), randf())
	])
	return conf
