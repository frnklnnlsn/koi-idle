# school_manager.gd
# Forms schools of fish and keeps them swimming together. Put one in a view
# (the pond has one: PondViewport/Schools) and point fish_container at the
# node that holds its fish. Tune everything in the Inspector.
#
# How a school works:
#   - Every few seconds a free fish may start a school. It becomes the leader
#     and keeps wandering as usual (its own steering and wall avoidance), at
#     the school's speed (slow or fast). Nearby free fish join as followers.
#   - Each follower has a loose spot around and behind the leader (sunflower
#     pattern, so they spread evenly). Every frame it steers toward its spot,
#     turns to match the leader, and speeds up / slows down to keep pace. A
#     push away from close neighbours keeps them from piling up (a little
#     overlap is allowed).
#   - The school breaks up after a while, or when the leader is gone (caught,
#     sold). A follower left far behind drops out. Fish that leave rest a few
#     seconds before they can join another school.
class_name SchoolManager
extends Node2D

## The node whose children are the fish (the pond: FishContainerPond).
@export var fish_container: Node2D
## Turn schooling on / off for this view.
@export var enabled: bool = true
## Draw lines from leaders to followers and their spots (for tuning).
@export var debug_draw: bool = false:
	set(v):
		debug_draw = v
		queue_redraw()

@export_group("Forming")
## Seconds between attempts to start a new school (random in this range).
@export var start_interval := Vector2(3.0, 7.0)
## Most schools at once.
@export_range(1, 10) var max_schools: int = 3
## Fish per school, leader included (random in this range). A school only
## forms if at least the smaller number of fish are free nearby.
@export var school_size := Vector2i(4, 12)
## How close (pond pixels) a fish must be to the leader to join.
@export var join_radius: float = 130.0
## How long a school lasts, in seconds (random in this range).
@export var duration := Vector2(15.0, 35.0)
## Seconds a fish rests after leaving a school before it can join another.
@export var rejoin_cooldown: float = 5.0

@export_group("Swimming")
## Chance a school swims fast (otherwise slow).
@export_range(0.0, 1.0, 0.05) var fast_chance: float = 0.35
## The leader swims a little under its usual speed so followers can catch up.
@export_range(0.3, 1.0, 0.05) var leader_pace: float = 0.85
## Spread of the follower spots, in body lengths.
@export_range(0.3, 4.0, 0.05) var spacing: float = 1.1
## Personal space, in body lengths: closer fish push apart (below 1 = some
## overlap is allowed).
@export_range(0.0, 2.0, 0.05) var personal_space: float = 0.7
@export var seek_weight: float = 1.0
@export var align_weight: float = 0.8
@export var separation_weight: float = 1.6
## Fastest a follower may go to catch up, as a multiple of the leader's pace.
@export_range(1.0, 5.0, 0.05) var max_catch_up: float = 3.0
## Slowest a follower goes when it's ahead of its spot, as a multiple of the
## leader's pace (it eases off instead of turning back).
@export_range(0.0, 1.0, 0.05) var min_pace: float = 0.25
## A follower this many seconds far behind its spot leaves the school.
@export var drop_after: float = 3.0


class School:
	var leader: Node
	var followers: Array = []
	var spots := {}     # follower -> Vector2(back, side) in leader body lengths
	var phase := {}     # follower -> drift phase, so spots sway a little
	var lag := {}       # follower -> seconds spent far behind
	var speed: float = 0.1   # the school's pace, as a speed for its smallest fish
	var formed_at: float = 0.0
	var ends_at: float = 0.0


var _schools: Array = []
var _time: float = 0.0
var _next_start: float = 2.0
var _resting := {}   # fish -> time it may join again


func _process(delta: float) -> void:
	_time += delta
	if not enabled or fish_container == null:
		return
	for s in _schools.duplicate():
		if not _alive(s):
			_disband(s)
		else:
			_update(s, delta)
	if _time >= _next_start:
		_next_start = _time + randf_range(start_interval.x, start_interval.y)
		if _schools.size() < max_schools:
			_try_start()
	if debug_draw:
		queue_redraw()


## Fish currently in a school (for tests / debug).
func schooling_count() -> int:
	var n := 0
	for s in _schools:
		n += 1 + s.followers.size()
	return n


func school_count() -> int:
	return _schools.size()


# ------------------------------------------------------------------ Forming

func _free_fish() -> Array:
	var out := []
	for f in fish_container.get_children():
		if f.has_method("can_join_school") and f.can_join_school() and _time >= _resting.get(f, 0.0):
			out.append(f)
	return out


func _try_start() -> void:
	for f in _resting.keys():   # forget rests that are over (or fish that are gone)
		if not is_instance_valid(f) or _time >= _resting[f]:
			_resting.erase(f)
	var free := _free_fish()
	if free.size() < school_size.x:
		return
	free.shuffle()
	# A few leaders to try: the first with enough free fish around wins.
	for leader in free.slice(0, 6):
		var lpos: Vector2 = leader.head_global()
		var near := free.filter(func(f): return f != leader and f.head_global().distance_to(lpos) <= join_radius)
		if near.size() + 1 < school_size.x:
			continue
		near.sort_custom(func(a, b): return a.head_global().distance_squared_to(lpos) < b.head_global().distance_squared_to(lpos))
		var want := randi_range(school_size.x, maxi(school_size.x, school_size.y)) - 1
		_form(leader, near.slice(0, want))
		return


func _form(leader: Node, followers: Array) -> void:
	var s := School.new()
	s.leader = leader
	s.speed = (leader.fast_speed if randf() < fast_chance else leader.slow_speed) * leader_pace
	s.formed_at = _time
	s.ends_at = _time + randf_range(duration.x, duration.y)
	leader.join_school(s)
	# Spots on a sunflower spiral behind the leader; nearest fish, nearest spot.
	for i in followers.size():
		var f: Node = followers[i]
		var r := spacing * sqrt(i + 1.0)
		var a := (i + 1) * 2.39996   # golden angle
		var back := 0.6 + r * (0.8 + 0.35 * cos(a)) + randf_range(-0.15, 0.15)
		var side := r * sin(a) * 1.1 + randf_range(-0.15, 0.15)
		s.spots[f] = Vector2(back, side)
		s.phase[f] = randf() * TAU
		s.lag[f] = 0.0
		s.followers.append(f)
		f.join_school(s)
	_schools.append(s)


# ------------------------------------------------------------------ Swimming

func _alive(s: School) -> bool:
	if not is_instance_valid(s.leader) or s.leader.school != s:
		return false
	s.followers = s.followers.filter(func(f): return is_instance_valid(f) and f.school == s)
	return not s.followers.is_empty() and _time < s.ends_at


func _update(s: School, delta: float) -> void:
	var leader: Node = s.leader
	var members: Array = [leader] + s.followers
	var centers := {}
	# Bigger fish cover more ground per stroke. Pace the school for its
	# smallest fish, and space the spots for its biggest, so everyone can keep
	# up and fit.
	var min_step := INF
	var L := 1.0
	for m in members:
		centers[m] = m.body_center_global()
		min_step = minf(min_step, m.step_length())
		L = maxf(L, m.body_length())
	leader.school_speed = s.speed * min_step / maxf(leader.step_length(), 0.001)
	var ldir: Vector2 = leader.current_direction
	var side_dir := ldir.rotated(PI / 2)
	var lhead: Vector2 = leader.head_global()
	var leader_px: float = leader.step_length() * leader.current_speed

	for f in s.followers.duplicate():
		var spot: Vector2 = s.spots[f]
		spot.y += 0.25 * sin(_time * 0.4 + s.phase[f])   # sway a little
		# Spots are in body lengths of the school's biggest fish (L).
		var target := lhead - ldir * spot.x * L + side_dir * spot.y * L
		# Keep the spot inside the water (a leader at the wall would otherwise
		# put spots beyond it, where nobody can reach them).
		var area: SwimArea = f.swim_area
		if area:
			var room: float = area.distance_from_edge(target)
			if room < L:
				target += area.direction_to_safety(target) * (L - room)
		var to_spot: Vector2 = target - f.head_global()
		var dist := to_spot.length()

		# Personal space: push away from members that are too close.
		var push := Vector2.ZERO
		var fl: float = f.body_length()
		for m in members:
			if m == f:
				continue
			var d: Vector2 = centers[f] - centers[m]
			var r: float = personal_space * (fl + m.body_length()) * 0.5
			var dl := d.length()
			if dl < r and dl > 0.001:
				push += d / dl * (1.0 - dl / r)

		# Head for the spot. If it's only a little behind (an overshoot), don't
		# turn back: slide sideways toward it and let the pace below fall back.
		# Well behind (the leader turned round): turn and swim back to it.
		var along := to_spot.dot(ldir)
		var overshoot := along < 0.0 and along > -1.5 * L
		var toward := to_spot - ldir * along if overshoot else to_spot
		var tl := toward.length()
		var seek := toward / maxf(tl, 0.001) * clampf(tl / (0.5 * L), 0.0, 2.0)
		var desired := ldir * align_weight + seek * seek_weight + push * separation_weight
		f.set_follow_direction(desired.normalized() if desired.length() > 0.001 else ldir)

		# Pace: faster when the spot is ahead, slower when it's behind. When
		# turning back, slow while turning, faster once facing the spot.
		var ahead := along if along > -1.5 * L else maxf(to_spot.dot(f.current_direction), 0.0)
		var factor := clampf(1.0 + ahead / L, min_pace, max_catch_up)
		f.school_speed = clampf(leader_px * factor / maxf(f.step_length(), 0.001), 0.01, f.fast_speed * 2.0)

		# Left far behind: drop out.
		if dist > L * 6.0 + join_radius:
			s.lag[f] += delta
			if s.lag[f] > drop_after:
				_release(f)
				s.followers.erase(f)
		else:
			s.lag[f] = 0.0


func _disband(s: School) -> void:
	if is_instance_valid(s.leader) and s.leader.school == s:
		_release(s.leader)
	for f in s.followers:
		if is_instance_valid(f) and f.school == s:
			_release(f)
	_schools.erase(s)


func _release(f: Node) -> void:
	f.leave_school()
	_resting[f] = _time + rejoin_cooldown


# ------------------------------------------------------------------ Debug

func _draw() -> void:
	if not debug_draw:
		return
	for s in _schools:
		if not is_instance_valid(s.leader):
			continue
		var lp := to_local(s.leader.head_global())
		draw_circle(lp, 3.0, Color(1, 0.8, 0.2))
		for f in s.followers:
			if is_instance_valid(f):
				draw_line(lp, to_local(f.head_global()), Color(1, 0.8, 0.2, 0.35), 1.0)
