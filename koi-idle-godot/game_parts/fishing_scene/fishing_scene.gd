# fishing_scene.gd
# What you see while fishing (it replaces the pond view behind the fishing
# panel): the pond zoomed in on one spot (the pond's own water floor and
# surface materials, so tweaks to those show here too), with no fish except
# the one you catch, and a red and white bobber on its line. fishing_ui
# drives it through main_ui:
#
#   open(pond_camera)   zoom the pond camera in on the spot, then fade in
#   close(pond_camera)  fade out while the pond camera zooms back out
#   cast()              the bobber is pulled out and cast again (splash)
#   set_waiting()       while the line is out it twitches now and then
#   hook(fish)          the bobber dunks, the fish rises from below and is
#                       pulled out of the water, dripping, and hangs by its
#                       mouth on the line
#   keep() / release()  the fish is pulled up and away / dropped back
#
# Positions and sizes are pond world units (a size-1 fish is ~27 long); the
# camera zoom makes them bigger on screen.
class_name FishingScene
extends SubViewportContainer

## The spot in the pond the scene shows (pond world coordinates); the bobber
## floats here.
@export var fishing_spot := Vector2(0, 0)
## How far in the scene is zoomed compared with the pond (whole numbers keep
## the pixels even).
@export_range(1.0, 8.0, 1.0) var zoom := 2.0
## Where on screen the bobber sits (share of the view, 0,0 = top left).
@export var bobber_anchor := Vector2(0.2, 0.32)
## Seconds the zoom-in / zoom-out takes when fishing opens / closes.
@export_range(0.0, 3.0, 0.05) var transition_seconds := 0.7

@export_group("Bobber")
@export var bobber_radius := 3.0
@export var bobber_top := Color(0.85, 0.12, 0.12)
@export var bobber_bottom := Color(0.95, 0.95, 0.92)
@export var line_color := Color(0.85, 0.88, 0.9, 0.8)
@export var ripple_color := Color(0.75, 0.95, 1.0)
## How high a caught fish is lifted above the water.
@export var lift_height := 34.0
## Where the line comes from (the rod, off the top of the view), relative to
## the bobber.
@export var rod_offset := Vector2(-30, -400)

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
var _fade: Tween
var _icons: FishIconRenderer
var _hooked: fish_conf
var _cast_from := Vector2.ZERO
var _cast_tip := Vector2.ZERO
var _pond_cam_home := {}  # pond camera position / zoom before the zoom-in

@onready var _view: SubViewport = $View
@onready var _camera: Camera2D = $View/Camera2D
@onready var _under: Node2D = $View/Under
@onready var _stage: Node2D = $View/Stage
@onready var _fish: Sprite2D = $View/Fish


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	_under.draw.connect(_draw_under)
	_icons = FishIconRenderer.new()
	add_child(_icons)
	_fish.visible = false
	_fish.centered = false
	_bob = _rest()


# --- Opening / closing ----------------------------------------------------------

## Where a camera looking at the pond must be, and how zoomed, to frame the
## spot the way this scene does.
func camera_target() -> Dictionary:
	var vp := Vector2(_view.size)
	return {"position": fishing_spot - (bobber_anchor - Vector2(0.5, 0.5)) * vp / zoom,
		"zoom": Vector2.ONE * zoom}


## Zooms `pond_camera` in on the spot, then fades this scene in over it.
func open(pond_camera: Camera2D = null) -> void:
	visible = true
	_kill(_fade)
	modulate.a = 0.0
	_fade = create_tween()
	if pond_camera and pond_camera.is_visible_in_tree() and transition_seconds > 0.0:
		if _pond_cam_home.is_empty():
			_pond_cam_home = {"position": pond_camera.position, "zoom": pond_camera.zoom}
		var target := camera_target()
		_fade.set_parallel(true)
		_fade.tween_property(pond_camera, "position", target["position"], transition_seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_fade.tween_property(pond_camera, "zoom", target["zoom"], transition_seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_fade.tween_property(self, "modulate:a", 1.0, transition_seconds * 0.4).set_delay(transition_seconds * 0.6)
	else:
		_fade.tween_property(self, "modulate:a", 1.0, 0.2)


## Fades out while `pond_camera` zooms back to where it was, then hides.
func close(pond_camera: Camera2D = null) -> void:
	_kill(_fade)
	_fade = create_tween()
	var home := _pond_cam_home
	_pond_cam_home = {}
	if pond_camera and not home.is_empty():
		if pond_camera.is_visible_in_tree() and transition_seconds > 0.0:
			_fade.set_parallel(true)
			_fade.tween_property(self, "modulate:a", 0.0, transition_seconds * 0.35)
			_fade.tween_property(pond_camera, "position", home["position"], transition_seconds) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			_fade.tween_property(pond_camera, "zoom", home["zoom"], transition_seconds) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			_fade.set_parallel(false)
		else:   # pond not showing (switched to the toilet): just put it back
			pond_camera.position = home["position"]
			pond_camera.zoom = home["zoom"]
			_fade.tween_property(self, "modulate:a", 0.0, 0.15)
	else:
		_fade.tween_property(self, "modulate:a", 0.0, 0.15)
	_fade.chain().tween_callback(func(): visible = false)


# --- Commands ---------------------------------------------------------------

func cast() -> void:
	_kill(_tween)
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
	p.y -= sin(t * PI) * 12.0
	_bob = p


func _cast_landed() -> void:
	_state = State.FLOAT
	_sub = 0.9
	_splash(_rest(), 3, 5.0)


func set_waiting(on: bool) -> void:
	_waiting = on


func hook(fish: fish_conf) -> void:
	_kill(_tween)
	_waiting = false
	_hooked = fish
	_fish.visible = false
	# Drawn like the fish in the pond: its pond pixel density, sized back to
	# pond world units.
	var density := Pond.icon_density(fish) if fish.y_start > 0.0 else 1.0
	_icons.request(fish, density, func(tex: Texture2D):
		if _hooked != fish:
			return
		_fish.texture = tex
		_fish.scale = Vector2.ONE / density
		# Pivot on the mouth: the picture faces right, so the head is the
		# right edge, halfway down.
		_fish.offset = Vector2(-tex.get_width() + 1.0, -tex.get_height() * 0.5))
	_state = State.BITE
	_lift = 0.0
	_rise = 0.0
	_tween = create_tween()
	# Dunk.
	_tween.tween_property(self, "_sub", 1.0, 0.12)
	_tween.tween_callback(func(): _splash(_rest(), 4, 7.0))
	_tween.tween_interval(0.35)
	# The fish comes up under the bobber...
	_tween.tween_callback(func():
		_state = State.LIFT
		_fish.visible = _fish.texture != null)
	_tween.tween_property(self, "_rise", 1.0, 0.35)
	_tween.tween_callback(func():
		_fish.visible = _fish.texture != null
		_splash(_rest(), 3, 6.0))
	# ...and is pulled out of the water.
	_tween.tween_property(self, "_lift", 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): _state = State.HANG)


func keep() -> void:
	if _state not in [State.HANG, State.LIFT, State.BITE]:
		return
	_kill(_tween)
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
	_kill(_tween)
	_state = State.RELEASE
	_fish_drop = _hang_point()
	_cast_from = _fish_drop
	_cast_tip = _rest() + Vector2(3.0, 2.0)
	_tween = create_tween()
	_tween.tween_method(_drop_step, 0.0, 1.0, 0.45)
	_tween.tween_callback(func():
		_fish.visible = false
		_hooked = null
		_splash(_cast_tip, 4, 8.0))
	_tween.tween_interval(0.3)
	_tween.tween_callback(func():
		cast()
		_waiting = false)


## Release: the fish falls back towards the water.
func _drop_step(t: float) -> void:
	_fish_drop = _cast_from.lerp(_cast_tip, t * t)


# --- Animation ----------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	var target := camera_target()
	_camera.position = target["position"]
	_camera.zoom = target["zoom"]
	var rest := _rest()
	match _state:
		State.FLOAT:
			_bob = rest + Vector2(0, sin(_time * 2.2) * 0.3)
			_ripple_in -= delta
			if _ripple_in <= 0.0:
				_ripple_in = 1.8
				_ripples.append([rest, 0.0, 3.5])
			if _waiting:
				_twitch_in -= delta
				if _twitch_in <= 0.0:
					_twitch_in = randf_range(0.6, 1.8)
					_twitch()
		State.BITE:
			_bob = rest
		State.LIFT, State.HANG, State.KEEP:
			var swing := sin(_time * 3.0) * 1.0 if _state == State.HANG else 0.0
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
		d[1].y += 60.0 * delta
		d[0] += d[1] * delta
		d[2] -= delta
		if d[0].y >= rest.y and d[1].y > 0.0:
			d[2] = 0.0
			_ripples.append([Vector2(d[0].x, rest.y), 0.6, 1.2])
	_drops = _drops.filter(func(d): return d[2] > 0.0)
	_place_fish()
	_stage.queue_redraw()
	_under.queue_redraw()


func _twitch() -> void:
	var t := create_tween()
	t.tween_property(self, "_sub", 0.6, 0.08)
	t.tween_property(self, "_sub", 0.35, 0.2)
	_ripples.append([_rest(), 0.0, 2.8])


func _splash(at: Vector2, rings: int, size: float) -> void:
	for i in rings:
		_ripples.append([at, -i * 0.18, size * (1.0 + i * 0.35)])
	for i in 6:
		_drops.append([at + Vector2(randf_range(-1, 1), -1), Vector2(randf_range(-12, 12), randf_range(-28, -14)), 1.0])


func _drip() -> void:
	var tail := _hang_point() + Vector2(randf_range(-0.8, 0.8), _fish_length())
	_drops.append([tail, Vector2(randf_range(-1.5, 1.5), 0.0), 1.0])


func _place_fish() -> void:
	if not _fish.visible:
		return
	# Hangs by its mouth: the sprite's pivot is the mouth, so swinging turns
	# it around the hook and it never leaves the line.
	_fish.rotation = -PI / 2.0
	_fish.z_index = 12   # above the surface once out of the water
	match _state:
		State.LIFT, State.BITE:
			# Rising from below: under the surface, dark and see-through
			# until it breaks out.
			_fish.position = _hang_point() + Vector2(0, 6.0 * (1.0 - _rise))
			_fish.z_index = 12 if _lift > 0.15 else 0
			var a := clampf(_rise * 0.8 + _lift, 0.0, 1.0)
			var dark := clampf(_rise * 0.6 + _lift * 2.0, 0.0, 1.0)
			_fish.modulate = Color(Color(0.2, 0.3, 0.45).lerp(Color.WHITE, dark), a)
		State.HANG, State.KEEP:
			_fish.position = _hang_point()
			_fish.rotation += sin(_time * 4.0) * 0.18
			_fish.modulate = Color.WHITE
		State.RELEASE:
			_fish.position = _fish_drop
			_fish.rotation += sin(_time * 14.0) * 0.3


## Where the hook (the fish's mouth) is: just under the bobber.
func _hang_point() -> Vector2:
	return _bob + Vector2(0, bobber_radius + 2.0)


func _fish_length() -> float:
	if _fish.texture == null:
		return 9.0
	return _fish.texture.get_width() * _fish.scale.x


func _rest() -> Vector2:
	return fishing_spot


func _kill(t: Tween) -> void:
	if t and t.is_valid():
		t.kill()


# --- Drawing ------------------------------------------------------------------
# Two layers: Under (below the pond's surface layer: the bobber's submerged
# half) and Stage (above it: ripples, line, the bobber above water, drops).
# Lines are drawn 1 pixel thin whatever the zoom (width -1).

func _draw_under() -> void:
	if _state in [State.FLOAT, State.BITE, State.CASTING]:
		_bobber_shape(_under, _bob.round(), true)


func _draw_stage() -> void:
	# Ripples: flat rings (seen at an angle) that grow and fade.
	for r in _ripples:
		var age: float = r[1]
		if age < 0.0:
			continue
		var t := age / 1.6
		var radius: float = r[2] * (0.3 + t)
		_stage.draw_set_transform(r[0], 0.0, Vector2(1.0, 0.4))
		_stage.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(ripple_color, 0.55 * (1.0 - t)), -1.0)
	_stage.draw_set_transform(Vector2.ZERO)
	# Line: from the rod (off the top) to the bobber, slack while floating.
	var top := _bob + Vector2(0, -bobber_radius - 1.5)
	var tip := _rest() + rod_offset
	var taut := _state in [State.BITE, State.LIFT, State.HANG, State.KEEP, State.RELEASE]
	var sag := 2.0 if taut else 9.0
	var pts := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		var p := tip.lerp(top, t)
		p.y += sin(t * PI) * sag
		pts.append(p)
	_stage.draw_polyline(pts, line_color, -1.0)
	# Line under the bobber to the hook, running on a little into the fish's
	# mouth (the fish is drawn over it) so it never looks unhooked.
	if _fish.visible and _state in [State.LIFT, State.HANG, State.KEEP, State.RELEASE]:
		var mouth := _fish.position
		var into := Vector2.DOWN.rotated(_fish.rotation + PI / 2.0) * 2.0
		_stage.draw_line(_bob, mouth + into, line_color, -1.0)
	_bobber_shape(_stage, _bob.round(), false)
	# Drops of water.
	for d in _drops:
		_stage.draw_rect(Rect2(d[0], Vector2.ONE * (1.0 / zoom)), Color(ripple_color, 0.85))


## The bobber: red top, white bottom, antenna. In the water, `submerged`
## draws only the part under the surface (dim, below the surface layer) and
## the other call only the part above it.
func _bobber_shape(canvas: CanvasItem, c: Vector2, submerged: bool) -> void:
	var r := bobber_radius
	var floating := _state in [State.FLOAT, State.BITE] or (_state == State.CASTING and _sub > 0.5)
	var line_y := c.y + r - r * 2.0 * _sub if floating else INF   # water surface
	if submerged and not floating:
		return
	var top_col := bobber_top
	var bottom_col := bobber_bottom
	if submerged:
		top_col = Color(bobber_top.darkened(0.4), 0.5)
		bottom_col = Color(bobber_bottom.darkened(0.4), 0.5)
	if not submerged:
		canvas.draw_line(c + Vector2(0, -r), c + Vector2(0, -r - 1.5), bobber_bottom, -1.0)
	# White: the whole circle (clipped at the surface); red: the top half.
	canvas.draw_colored_polygon(_disc(c, r, line_y, submerged, INF), bottom_col)
	canvas.draw_colored_polygon(_disc(c, r, line_y, submerged, c.y), top_col)
	if floating and not submerged:
		canvas.draw_line(Vector2(c.x - r - 0.5, line_y), Vector2(c.x + r + 0.5, line_y), Color(ripple_color, 0.6), -1.0)


## Circle points around `c`, cut at the water line: above it (or below it
## when `below`), and never lower than `max_y`.
func _disc(c: Vector2, r: float, line_y: float, below: bool, max_y: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var p := c + Vector2(cos(a), sin(a)) * r
		if below:
			p.y = maxf(p.y, minf(line_y, c.y + r))
		else:
			p.y = minf(p.y, line_y)
		p.y = minf(p.y, max_y)
		pts.append(p)
	return pts
