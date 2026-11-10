# boss_cutscene.gd
# The boss cut scene (boss_cutscene.tscn), shown over everything when you
# challenge a level's boss. It can't be lost:
#
#   1. Reel-in: deep water, the line pulls, the boss rises out of the dark
#      (small and dim -> full size and bright) while the reel bar fills and
#      the boss's reel_lines appear one by one.
#   2. Catch: a flash, the boss's name and weight.
#   3. Conversation: the boss's dialogue, a line at a time (click, Space or
#      Enter goes on; lines starting with "you:" are yours).
#   4. A button starts the next level: emits `finished` (main_ui then calls
#      Prestige.advance()).
#
# Words and look live on the level's BossDef (levels.tres); timings and sizes
# are the exports below; layout, fonts and colours are in the scene.
class_name BossCutscene
extends CanvasLayer

## The player pressed "Begin level N".
signal finished

@export_group("Timing")
@export var fade_in_seconds := 1.2
## How long the reel-in lasts.
@export var reel_seconds := 14.0
## Pause on the catch before the conversation.
@export var reveal_seconds := 2.5
## Typing speed of the conversation, characters per second.
@export var type_speed := 40.0

@export_group("Boss")
## Screen size of the boss: BossDef.size × this.
@export var fish_screen_scale := 1.0
## How small (share of full size) and how dim the boss starts, deep down.
@export_range(0.05, 1.0, 0.05) var start_size := 0.3
@export_range(0.0, 1.0, 0.05) var start_brightness := 0.12
## Where the boss ends up, as a share of the screen (it turns side on there
## for the conversation).
@export var rest_point := Vector2(0.5, 0.45)
## How far it sways from side to side while fighting / resting, in degrees.
@export var fight_sway := 20.0
@export var rest_sway := 6.0
## How hard the screen shakes while reeling, in pixels.
@export var shake := 6.0

@onready var _root: Control = %Root
@onready var _water: ColorRect = %Water
@onready var _shaker: Node2D = %Shaker
@onready var _stage: Node2D = %Stage
@onready var _line: Line2D = %FishingLine
@onready var _flash: ColorRect = %Flash
@onready var _narration: RichTextLabel = %Narration
@onready var _reel: Control = %Reel
@onready var _reel_bar: ProgressBar = %ReelBar
@onready var _reveal: Control = %Reveal
@onready var _boss_name: Label = %BossName
@onready var _boss_weight: Label = %BossWeight
@onready var _dialogue: Control = %Dialogue
@onready var _speaker: Label = %Speaker
@onready var _line_text: RichTextLabel = %LineText
@onready var _next: Button = %NextLevel

var boss: BossDef
var _fish: Node2D
var _anchor := Vector2.ZERO        # where the boss's body is held
var _sway_time := 0.0
var _heading := -PI / 2.0          # straight up while it's reeled in
var _sway := 0.0                   # degrees, set from fight_sway / rest_sway
var _shaking := false
var _advance := false              # click / key pressed during the conversation


## Call before adding to the tree.
func setup(b: BossDef) -> void:
	boss = b


func _ready() -> void:
	_root.gui_input.connect(_on_root_input)
	_next.pressed.connect(_finish)
	for c in [_reel, _reveal, _dialogue, _next]:
		c.visible = false
	_narration.text = ""
	_flash.color.a = 0.0
	if boss == null:
		boss = BossDef.new()
	_spawn_fish()
	_play()


func _spawn_fish() -> void:
	var data := Prestige.make_boss_fish(boss)
	_fish = FishFactory.new().build(data)
	var steer = _fish.get_node("FishSteering")
	steer.lock_heading = true
	steer.locked_direction = Vector2.UP
	_fish.set_size_factor(boss.size * fish_screen_scale * start_size, 0.0)
	_fish.modulate = Color(start_brightness, start_brightness, start_brightness)
	_stage.add_child(_fish)
	# Held in a swim (no random stops or eating), so the body stays straight.
	_fish.force_state(_fish.FishState.SLOW_SWIM)
	var view := _root.size if _root.size != Vector2.ZERO else get_viewport().get_visible_rect().size
	_anchor = Vector2(view.x * 0.42, view.y * 0.95)
	_pin_fish()


func _process(delta: float) -> void:
	if _fish == null:
		return
	_sway_time += delta
	# A slow side-to-side sway, so it swims rather than slides.
	_fish.get_node("FishSteering").locked_direction = Vector2.RIGHT.rotated(_heading + sin(_sway_time * 0.9) * deg_to_rad(_sway))
	_pin_fish()
	var view := _root.size
	var top := Vector2(view.x * 0.5 + sin(_sway_time * 1.7) * 10.0, -10.0)
	_line.points = PackedVector2Array([top, _fish.head_global() - _shaker.position])
	_shaker.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) if _shaking else Vector2.ZERO


## Holds the boss's body at _anchor while it swims on the spot.
func _pin_fish() -> void:
	_fish.position += _anchor - (_fish.body_center_global() - _shaker.position)


# ------------------------------------------------------------------ Sequence

func _play() -> void:
	var view := _root.size
	# 1. Fade in, deep.
	_root.modulate.a = 0.0
	_set_depth(1.0)
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 1.0, fade_in_seconds)
	await t.finished

	# 2. Reel it up.
	_reel.visible = true
	_shaking = true
	_sway = fight_sway
	_fish.force_state(_fish.FishState.FAST_SWIM)   # thrashing
	var full := boss.size * fish_screen_scale
	_fish.set_size_factor(full, reel_seconds)
	t = create_tween().set_parallel()
	t.tween_property(_fish, "modulate", Color.WHITE, reel_seconds).set_ease(Tween.EASE_IN)
	t.tween_property(self, "_anchor", view * rest_point, reel_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_method(_set_depth, 1.0, 0.0, reel_seconds)
	t.tween_method(_set_reel, 0.0, 1.0, reel_seconds)
	var lines := boss.reel_lines
	for i in lines.size():
		_say(lines[i], i == lines.size() - 1)
		await get_tree().create_timer(reel_seconds / maxf(lines.size(), 1)).timeout
	if t.is_running():
		await t.finished
	_shaking = false

	# 3. The catch: it turns side on and calms down.
	_reel.visible = false
	var turn := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	turn.tween_property(self, "_heading", 0.0, 1.6)
	turn.tween_property(self, "_sway", rest_sway, 1.6)
	# Keep swimming hard through the turn so the body straightens out behind
	# the head, then settle to a slow swim.
	turn.chain().tween_interval(1.0)
	turn.chain().tween_callback(func(): _fish.force_state(_fish.FishState.SLOW_SWIM))
	create_tween().tween_property(_line, "modulate:a", 0.0, 1.0)
	_narration.text = ""
	_flash.color.a = 0.9
	create_tween().tween_property(_flash, "color:a", 0.0, 0.8)
	_boss_name.text = boss.boss_name
	_boss_weight.text = Prestige.mass_text(boss.weight_grams)
	_reveal.visible = true
	_reveal.modulate.a = 0.0
	create_tween().tween_property(_reveal, "modulate:a", 1.0, 0.6)
	await get_tree().create_timer(reveal_seconds).timeout

	# 4. Conversation.
	_dialogue.visible = true
	for entry in boss.dialogue:
		await _show_line(entry)

	# 5. On to the next level.
	var next := Prestige.level() + 1
	_next.text = "Begin %s" % Prestige.level_name(next)
	_next.visible = true


func _set_depth(d: float) -> void:
	var m := _water.material as ShaderMaterial
	if m:
		m.set_shader_parameter("depth", d)


func _set_reel(v: float) -> void:
	# A little tug-of-war wobble on top of the steady progress.
	_reel_bar.value = clampf(v + sin(v * 40.0) * 0.03 * (1.0 - v), 0.0, 1.0) * _reel_bar.max_value


func _say(text: String, big: bool) -> void:
	var fx := "[shake rate=25 level=10]%s[/shake]" if big else "[wave amp=25 freq=3]%s[/wave]"
	_narration.text = "[center]" + fx % text
	_narration.modulate.a = 0.0
	create_tween().tween_property(_narration, "modulate:a", 1.0, 0.4)


## Types out one line of the conversation and waits for a click / key.
func _show_line(entry: String) -> void:
	var mine := entry.strip_edges().to_lower().begins_with("you:")
	var text := entry.strip_edges().substr(4).strip_edges() if mine else entry.strip_edges()
	_speaker.text = "You" if mine else boss.boss_name
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mine else HORIZONTAL_ALIGNMENT_LEFT
	_line_text.text = ("[right]%s[/right]" if mine else "%s") % text
	_line_text.visible_ratio = 0.0
	_advance = false
	var t := create_tween()
	t.tween_property(_line_text, "visible_ratio", 1.0, text.length() / maxf(type_speed, 1.0))
	while t.is_running() and not _advance:
		await get_tree().process_frame
	# A click while typing shows the whole line; the next one goes on.
	t.kill()
	_line_text.visible_ratio = 1.0
	_advance = false
	while not _advance:
		await get_tree().process_frame


# ------------------------------------------------------------------ Input

var _done := false

func _finish() -> void:
	if _done:
		return
	_done = true
	_next.disabled = true
	finished.emit()


func _on_root_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance = true


## Every key stops here, so the game's keys (S, T, V...) don't act behind
## the scene. Space / Enter go on in the conversation.
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			if _next.visible:
				_finish()
			else:
				_advance = true
