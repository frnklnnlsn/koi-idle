# debug_panel.gd
# Attach to the DebugPanel CanvasLayer node
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

# Fish movement tweaking
@onready var wave_amplitude_slider:   HSlider = %WaveAmplitudeSlider
@onready var wave_amplitude_label:    Label   = %WaveAmplitudeLabel
@onready var wave_frequency_slider:   HSlider = %WaveFrequencySlider
@onready var wave_frequency_label:    Label   = %WaveFrequencyLabel
@onready var wave_start_slider:       HSlider = %WaveStartSlider
@onready var wave_start_label:        Label   = %WaveStartLabel
@onready var wave_phase_slider:       HSlider = %WavePhaseSlider
@onready var wave_phase_label:        Label   = %WavePhaseLabel

# --- NEW: per-state editing UI ---
# Add these nodes to your scene (Labels + Button):
#   %EditingStateLabel   — shows which state is being edited
#   %PrintParamsButton   — dumps all state params to the Output panel
@onready var editing_state_label: Label  = %EditingStateLabel
@onready var print_params_button: Button = %PrintParamsButton

# Which state index is currently being edited (-1 = auto / no lock)
var _current_editing_state: int = -1

var _panel_visible: bool = true

# Maps state dropdown index → state display name (mirrors _setup_state_options order)
const STATE_NAMES := ["Very Slow", "Accelerating", "Slow Swim", "Fast Swim", "Decelerating", "Eating"]


func init(test_ground) -> void:
	ground = test_ground


func _ready() -> void:
	_setup_state_options()
	_set_defaults()
	_connect_signals()
	_update_editing_label()
	_set_wave_sliders_enabled(false)   # disabled until a state is locked


func _process(_delta: float) -> void:
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	if fish_count_label and ground:
		fish_count_label.text = "Fish: %d / 50" % ground._fish_nodes.size()


# ------------------------------------------------------------------ Setup

func _setup_state_options() -> void:
	if not state_option:
		return
	state_option.clear()
	# Index 0 — auto transitioning (no lock)
	state_option.add_item("Auto (transitioning)", -1)
	# Indices 1-6 — hard lock to each FishState
	state_option.add_item("Very Slow Swim",  0)
	state_option.add_item("Accelerating",    1)
	state_option.add_item("Slow Swim",       2)
	state_option.add_item("Fast Swim",       3)
	state_option.add_item("Decelerating",    4)
	state_option.add_item("Eating",          5)
	state_option.selected = 0


func _set_defaults() -> void:
	if spawn_count_slider:
		spawn_count_slider.min_value = 1
		spawn_count_slider.max_value = 50
		spawn_count_slider.value     = 1
		spawn_count_label.text       = "Spawn: 1"

	if boundary_slider:
		boundary_slider.min_value = 10
		boundary_slider.max_value = 500
		boundary_slider.value     = 20
		boundary_label.text       = "Boundary: 100"

	if zoom_slider:
		zoom_slider.min_value = 0.1
		zoom_slider.max_value = 4
		zoom_slider.step      = 0.1
		zoom_slider.value     = 1
		zoom_label.text       = "Zoom: 1"

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

	if wave_amplitude_slider:
		wave_amplitude_slider.min_value = 0.05
		wave_amplitude_slider.max_value = 20.0
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
	if spawn_button:          spawn_button.pressed.connect(_on_spawn_pressed)
	if clear_button:          clear_button.pressed.connect(_on_clear_pressed)
	if boundary_slider:       boundary_slider.value_changed.connect(_on_boundary_changed)
	if zoom_slider:           zoom_slider.value_changed.connect(_on_zoom_changed)
	if speed_slider:          speed_slider.value_changed.connect(_on_speed_changed)
	if state_option:          state_option.item_selected.connect(_on_state_selected)
	if shadow_toggle:         shadow_toggle.toggled.connect(_on_shadow_toggled)
	if shadow_scale_slider:   shadow_scale_slider.value_changed.connect(_on_shadow_scale_changed)
	if shadow_opacity_slider: shadow_opacity_slider.value_changed.connect(_on_shadow_opacity_changed)
	if spawn_count_slider:    spawn_count_slider.value_changed.connect(_on_spawn_count_changed)
	if toggle_button:         toggle_button.pressed.connect(_on_toggle_panel)
	if wave_amplitude_slider: wave_amplitude_slider.value_changed.connect(_on_wave_amplitude_changed)
	if wave_frequency_slider: wave_frequency_slider.value_changed.connect(_on_wave_frequency_changed)
	if wave_start_slider:     wave_start_slider.value_changed.connect(_on_wave_start_changed)
	if wave_phase_slider:     wave_phase_slider.value_changed.connect(_on_wave_phase_changed)
	if print_params_button:   print_params_button.pressed.connect(_on_print_params_pressed)


# ------------------------------------------------------------------ State selection

func _on_state_selected(index: int) -> void:
	if not ground:
		return

	# Dropdown index 0 = auto (-1), indices 1-6 = FishState 0-5
	var state = index - 1
	_current_editing_state = state

	if state < 0:
		# --- Auto mode: release lock, disable wave sliders ---
		ground.set_fish_state_lock(-1)
		_set_wave_sliders_enabled(false)
	else:
		# --- Locked mode: hard-lock fish, load that state's wave params ---
		ground.set_fish_state_lock(state)
		_set_wave_sliders_enabled(true)
		# Pull saved params for this state into the sliders
		var p = ground.get_state_wave_params(state)
		_load_wave_params_to_sliders(p)

	_update_editing_label()


# ------------------------------------------------------------------ Wave param helpers

## Push current slider values as the saved params for the active editing state.
func _save_current_wave_params() -> void:
	if not ground or _current_editing_state < 0:
		return
	ground.set_state_wave_params_for_all(
		_current_editing_state,
		wave_amplitude_slider.value,
		wave_frequency_slider.value,
		wave_start_slider.value,
		wave_phase_slider.value
	)


## Pull a params dict into all four wave sliders (suppresses save feedback loop).
func _load_wave_params_to_sliders(p: Dictionary) -> void:
	# Block signals so loading doesn't trigger another save
	if wave_amplitude_slider:
		wave_amplitude_slider.set_block_signals(true)
		wave_amplitude_slider.value = p.get("amp", 8.0)
		wave_amplitude_slider.set_block_signals(false)
		wave_amplitude_label.text = "Wave Amplitude: %.1f" % wave_amplitude_slider.value

	if wave_frequency_slider:
		wave_frequency_slider.set_block_signals(true)
		wave_frequency_slider.value = p.get("freq", 3.0)
		wave_frequency_slider.set_block_signals(false)
		wave_frequency_label.text = "Wave Frequency: %.1f" % wave_frequency_slider.value

	if wave_start_slider:
		wave_start_slider.set_block_signals(true)
		wave_start_slider.value = p.get("start", 0.4)
		wave_start_slider.set_block_signals(false)
		wave_start_label.text = "Wave Start: %.2f" % wave_start_slider.value

	if wave_phase_slider:
		wave_phase_slider.set_block_signals(true)
		wave_phase_slider.value = p.get("phase", 0.8)
		wave_phase_slider.set_block_signals(false)
		wave_phase_label.text = "Phase Step: %.2f" % wave_phase_slider.value


func _set_wave_sliders_enabled(enabled: bool) -> void:
	for slider in [wave_amplitude_slider, wave_frequency_slider, wave_start_slider, wave_phase_slider]:
		if slider:
			slider.editable = enabled
	# Visually dim the labels when disabled
	var alpha = 1.0 if enabled else 0.4
	for label in [wave_amplitude_label, wave_frequency_label, wave_start_label, wave_phase_label]:
		if label:
			label.modulate.a = alpha


func _update_editing_label() -> void:
	if not editing_state_label:
		return
	if _current_editing_state < 0:
		editing_state_label.text = "Auto mode — select a state to edit its wave params"
	else:
		editing_state_label.text = "Editing: %s wave params  (changes saved automatically)" \
			% STATE_NAMES[_current_editing_state]


# ------------------------------------------------------------------ Wave slider handlers
# Each one updates the label, then saves the full set of params for the locked state.

func _on_wave_amplitude_changed(value: float) -> void:
	wave_amplitude_label.text = "Wave Amplitude: %.1f" % value
	_save_current_wave_params()

func _on_wave_frequency_changed(value: float) -> void:
	wave_frequency_label.text = "Wave Frequency: %.1f" % value
	_save_current_wave_params()

func _on_wave_start_changed(value: float) -> void:
	wave_start_label.text = "Wave Start: %.2f" % value
	_save_current_wave_params()

func _on_wave_phase_changed(value: float) -> void:
	wave_phase_label.text = "Phase Step: %.2f" % value
	_save_current_wave_params()


# ------------------------------------------------------------------ Print params

func _on_print_params_pressed() -> void:
	if ground:
		ground.print_all_state_params()


# ------------------------------------------------------------------ Other handlers

func _on_spawn_pressed() -> void:
	if not ground:
		return
	var count = int(spawn_count_slider.value)
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

func _make_test_fish_conf() -> fish_conf:
	var conf       = fish_conf.new()
	conf.seed      = randi()
	conf.frequency = randf_range(0.1, 0.5)
	conf.noise_type_index = randi() % 4
	conf.offsets   = PackedFloat32Array([0.0, 1.0])
	conf.colors    = PackedColorArray([
		Color(randf(), randf(), randf()),
		Color(randf(), randf(), randf())
	])
	return conf
