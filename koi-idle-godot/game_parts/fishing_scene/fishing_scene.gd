# fishing_scene.gd
# What you see while fishing (it replaces the pond view behind the fishing
# panel): a red and white bobber on its line, floating in the water with
# ripples. fishing_ui drives it through main_ui:
#
#   cast()          the bobber is pulled out and cast again (splash)
#   set_waiting()   while the line is out it twitches now and then, more as
#                   the bite gets near
#   hook(fish)      the bobber dunks, the fish rises from below and is pulled
#                   out of the water, dripping, and hangs on the line
#   keep()          the hanging fish is pulled up and away
#   release()       the hanging fish drops back into the water
#
# Everything is drawn at half resolution (stretch_shrink 2) like the pond, so
# it's chunky pixel art. Sizes below are in those half-size pixels.
class_name FishingScene
extends SubViewportContainer

## Where the bobber floats, as a share of the view (0,0 = top left).
@export var bobber_anchor := Vector2(0.2, 0.32)
## Bobber size (radius) and colours.
@export var bobber_radius := 5.0
@export var bobber_top := Color(0.85, 0.12, 0.12)
@export var bobber_bottom := Color(0.95, 0.95, 0.92)
@export var line_color := Color(0.85, 0.88, 0.9, 0.8)
@export var ripple_color := Color(0.75, 0.95, 1.0)
## Water near the bobber (also the water shader's main colour).
@export var water_color := Color(0.07, 0.20, 0.30)
## How high a caught fish is lifted above the water.
@export var lift_height := 70.0
## Where the line comes from (the rod, off the top of the view), relative to
## the bobber.
@export var rod_offset := Vector2(-80, -1000)

enum State { FLOAT, CASTING, BITE, LIFT, HANG, KEEP, RELEASE }

var _state := State.FLOAT
var _time := 0.0
var _waiting := false
var _twitch_in := 1.0
var _ripple_in := 0.0
var _sub := 0.35          # how deep the bobber sits (0 = on top, 1 = under)
var _bob := Vector2.ZERO  # bobber position
var _lift := 0.0          # 0 = fish under the water, 1 = hanging in the air
var _rise := 0.0          # fish coming up from below (0..1)
var _fish_drop := Vector2.ZERO
var _ripples: Array = []  # [pos, age, size]
var _drops: Array = []    # [pos, vel, life]
var _tween: Tween
var _icons: FishIconRenderer
var _hooked: fish_conf
var _cast_from := Vector2.ZERO
var _cast_tip := Vector2.ZERO

@onready var _view: SubViewport = $View
@onready var _water: ColorRect = $View/Water
@onready var _stage: Node2D = $View/Stage
@onready var _fish: Sprite2D = $View/Stage/Fish


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	if _water.material:
		_water.material.set_shader_parameter("water_color", water_color)
	_icons = FishIconRenderer.new()
	add_child(_icons)
	_fish.visible = false
	_bob = _rest()


# --- Commands ---------------------------------------------------------------

func cast() -> void:
	_kill_tween()
	_waiting = true
	_cast_from = _bob
	_cast_tip = _rest() + Vector2(rod_offset.x * 0.6, -lift_height * 1.6)
	_fish.visible = false   # a fish left on as bait goes under with the hook
	_state = State.CASTING
	_tween = create_tween()
	_tween.tween_method(_cast_pull, 0.0, 1.0, 0.25).set_ease(Tween.EASE_IN)
	_tween.tween_method(_cast_arc, 0.0, 1.0, 0.55)
	_tween.tween_callback(_cast_landed)
	_tween.tween_property(self, "_sub", 0.35, 0.4)


## Cast, part 1: the bobber is pulled out of the water up to the rod.
func _cast_pull(t: float) -> void:
	_bob = _cast_from.lerp(_cast_tip, t)


## Cast, part 2: it flies out in an arc to where it floats.
func _cast_arc(t: float) -> void:
	var p := _cast_tip.lerp(_rest(), t)
	p.y -= sin(t * PI) * 30.0
	_bob = p


func _cast_landed() -> void:
	_state = State.FLOAT
	_sub = 0.9
	_splash(_rest(), 3, 14.0)


func set_waiting(on: bool) -> void:
	_waiting = on


func hook(fish: fish_conf) -> void:
	_kill_tween()
	_waiting = false
	_hooked = fish
	_fish.visible = false
	var px := 1
	if fish.y_start > 0.0:
		px = mini(Pond.pixel_scale_of(fish), 3)
	_icons.request(fish, Pond.icon_density(fish) if fish.y_start > 0.0 else 1.0, func(tex):
		if _hooked != fish:
			return
		_fish.texture = tex
		_fish.scale = Vector2.ONE * px)
	_state = State.BITE
	_lift = 0.0
	_rise = 0.0
	_tween = create_tween()
	# Dunk.
	_tween.tween_property(self, "_sub", 1.0, 0.12)
	_tween.tween_callback(func(): _splash(_rest(), 4, 18.0))
	_tween.tween_interval(0.35)
	# The fish comes up under the bobber...
	_tween.tween_callback(func():
		_state = State.LIFT
		_fish.visible = _fish.texture != null)
	_tween.tween_property(self, "_rise", 1.0, 0.35)
	_tween.tween_callback(func():
		_fish.visible = _fish.texture != null
		_splash(_rest(), 3, 16.0))
	# ...and is pulled out of the water.
	_tween.tween_property(self, "_lift", 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): _state = State.HANG)


func keep() -> void:
	if _state not in [State.HANG, State.LIFT, State.BITE]:
		return
	_kill_tween()
	_state = State.KEEP
	_lift = 1.0
	_rise = 1.0
	_tween = create_tween()
	_tween.tween_property(self, "_lift", 4.0, 0.5).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		_fish.visible = false
		_hooked = null
		_bob = _rest() + Vector2(rod_offset.x * 0.6, -lift_height * 1.6)
		cast()
		_waiting = false)


func release() -> void:
	if _state not in [State.HANG, State.LIFT, State.BITE]:
		return
	_kill_tween()
	_state = State.RELEASE
	_fish_drop = _hang_point() + Vector2(0, 8)
	_cast_from = _fish_drop
	var water := Vector2(_rest().x + 6.0, _rest().y + 4.0)
	_cast_tip = water
	_tween = create_tween()
	_tween.tween_method(_drop_step, 0.0, 1.0, 0.45)
	_tween.tween_callback(func():
		_fish.visible = false
		_hooked = null
		_splash(water, 4, 20.0))
	_tween.tween_interval(0.3)
	_tween.tween_callback(func():
		cast()
		_waiting = false)


# --- Animation ----------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_water.size = Vector2(_view.size)
	var rest := _rest()
	match _state:
		State.FLOAT:
			_bob = rest + Vector2(0, sin(_time * 2.2) * 0.8)
			_ripple_in -= delta
			if _ripple_in <= 0.0:
				_ripple_in = 1.8
				_ripples.append([rest, 0.0, 9.0])
			if _waiting:
				_twitch_in -= delta
				if _twitch_in <= 0.0:
					_twitch_in = randf_range(0.6, 1.8)
					_twitch()
		State.BITE:
			_bob = rest
		State.LIFT, State.HANG, State.KEEP:
			var swing := sin(_time * 3.0) * 2.5 if _state == State.HANG else 0.0
			_bob = rest + Vector2(swing, -lift_height * _lift)
			if _lift > 0.05 and _lift < 1.2 and randf() < 0.5:
				_drip()
			elif _state == State.HANG and randf() < 0.05:
				_drip()
	# Ripples and drops.
	for r in _ripples:
		r[1] += delta
	_ripples = _ripples.filter(func(r): return r[1] < 1.6)
	for d in _drops:
		d[1].y += 160.0 * delta
		d[0] += d[1] * delta
		d[2] -= delta
		if d[0].y >= rest.y and d[1].y > 0.0:
			d[2] = 0.0
			_ripples.append([Vector2(d[0].x, rest.y), 0.6, 3.0])
	_drops = _drops.filter(func(d): return d[2] > 0.0)
	_place_fish()
	_stage.queue_redraw()


## Release: the fish falls back towards the water.
func _drop_step(t: float) -> void:
	_fish_drop = _cast_from.lerp(_cast_tip, t * t)


func _twitch() -> void:
	var t := create_tween()
	t.tween_property(self, "_sub", 0.6, 0.08)
	t.tween_property(self, "_sub", 0.35, 0.2)
	_ripples.append([_rest(), 0.0, 7.0])


func _splash(at: Vector2, rings: int, size: float) -> void:
	for i in rings:
		_ripples.append([at, -i * 0.18, size * (1.0 + i * 0.35)])
	for i in 6:
		_drops.append([at + Vector2(randf_range(-3, 3), -2), Vector2(randf_range(-30, 30), randf_range(-70, -35)), 1.0])


func _drip() -> void:
	var tail := _hang_point() + Vector2(randf_range(-2, 2), _fish_length())
	_drops.append([tail, Vector2(randf_range(-4, 4), 0.0), 1.0])


func _place_fish() -> void:
	if not _fish.visible:
		return
	var flen := _fish_length()
	_fish.rotation = -PI / 2.0   # the picture faces right: head up
	match _state:
		State.LIFT, State.BITE:
			# Rising from below: dark and see-through until it breaks the surface.
			var under := Vector2(0, 16.0 * (1.0 - _rise))
			_fish.position = _hang_point() + under + Vector2(0, flen * 0.5)
			var a := clampf(_rise * 0.8 + _lift, 0.0, 1.0)
			var dark := clampf(_rise * 0.6 + _lift * 2.0, 0.0, 1.0)
			_fish.modulate = Color(Color(0.2, 0.3, 0.45).lerp(Color.WHITE, dark), a)
		State.HANG, State.KEEP:
			_fish.position = _hang_point() + Vector2(0, flen * 0.5)
			_fish.rotation += sin(_time * 4.0) * 0.18
			_fish.modulate = Color.WHITE
		State.RELEASE:
			_fish.position = _fish_drop + Vector2(0, flen * 0.5)
			_fish.rotation += sin(_time * 14.0) * 0.3


## Where the fish's mouth hangs: just under the bobber.
func _hang_point() -> Vector2:
	return _bob + Vector2(0, bobber_radius + 4.0)


func _fish_length() -> float:
	if _fish.texture == null:
		return 20.0
	return _fish.texture.get_width() * _fish.scale.x


func _rest() -> Vector2:
	return Vector2(_view.size) * bobber_anchor


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


# --- Drawing ------------------------------------------------------------------

func _draw_stage() -> void:
	var rest := _rest()
	# Ripples: flat rings (seen at an angle) that grow and fade.
	for r in _ripples:
		var age: float = r[1]
		if age < 0.0:
			continue
		var t := age / 1.6
		var radius: float = r[2] * (0.3 + t)
		_stage.draw_set_transform(r[0], 0.0, Vector2(1.0, 0.4))
		_stage.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(ripple_color, 0.55 * (1.0 - t)), 1.0)
	_stage.draw_set_transform(Vector2.ZERO)
	# Line: from the rod (off the top) to the bobber, slack while floating.
	var top := _bob + Vector2(0, -bobber_radius - 3.0)
	var tip := rest + rod_offset
	var taut := _state in [State.BITE, State.LIFT, State.HANG, State.KEEP, State.RELEASE]
	var sag := 4.0 if taut else 22.0
	var pts := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		var p := tip.lerp(top, t)
		p.y += sin(t * PI) * sag
		pts.append(p)
	_stage.draw_polyline(pts, line_color, 1.0)
	# Line under the bobber to the hook / fish.
	if _state in [State.LIFT, State.HANG, State.KEEP]:
		_stage.draw_line(_bob, _hang_point(), line_color, 1.0)
	elif _state == State.RELEASE:
		_stage.draw_line(_bob, _bob + Vector2(0, 6), line_color, 1.0)
	_draw_bobber()
	# Drops of water.
	for d in _drops:
		_stage.draw_rect(Rect2(d[0].floor(), Vector2.ONE), Color(ripple_color, 0.8))


func _draw_bobber() -> void:
	var r := bobber_radius
	var c := _bob.round()
	# Antenna.
	_stage.draw_line(c + Vector2(0, -r), c + Vector2(0, -r - 3.0), bobber_bottom, 1.0)
	# Red top, white bottom.
	_stage.draw_circle(c, r, bobber_top)
	var half := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		half.append(c + Vector2(cos(a), sin(a)) * r)
	_stage.draw_colored_polygon(half, bobber_bottom)
	# In the water, the part below the surface is mostly hidden.
	var in_water := _state in [State.FLOAT, State.BITE] or (_state == State.CASTING and _sub > 0.5)
	if in_water:
		var depth := r * 2.0 * _sub
		_stage.draw_rect(Rect2(c.x - r - 1.0, c.y + r - depth, r * 2.0 + 2.0, depth + 1.0), Color(water_color, 0.85))
		_stage.draw_line(Vector2(c.x - r - 1.0, c.y + r - depth), Vector2(c.x + r + 1.0, c.y + r - depth), Color(ripple_color, 0.5), 1.0)
