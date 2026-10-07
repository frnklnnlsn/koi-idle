# fish_body_chain.gd
# Child Node of procedural_fish (add as $FishBodyChain).
# Owns the inverse-kinematics chain follow and the travelling wave overlay.
# Does not know about states, boundaries, or eating — pure geometry.
extends Node

# Set via init() — do not assign directly
var _fish_body: Line2D
var _skeleton:  Line2D

var num_points: int = 10
var seg_length: int = 15  # read by coordinator: _body_chain.seg_length


func init(fish_body: Line2D, skeleton: Line2D, points: int, segment_length: int) -> void:
	_fish_body  = fish_body
	_skeleton   = skeleton
	num_points  = points
	seg_length  = segment_length


## Move the head to new_head_local (local space) then drag the rest of the
## chain after it, overlaying a travelling sine wave.
## time is passed from the coordinator so all components share the same clock.
func update(new_head_local: Vector2, speed: float,
			wave_amplitude: float, wave_frequency: float,
			wave_start_point: float, wave_phase_step: float,
			time: float) -> void:

	_fish_body.set_point_position(0, new_head_local)
	_skeleton.set_point_position(0, new_head_local)

	for i in range(1, _fish_body.get_point_count()):
		var current_pos  = _fish_body.get_point_position(i)
		var ahead_pos    = _fish_body.get_point_position(i - 1)
		var dir_to_ahead = (ahead_pos - current_pos).normalized()

		# Chain follow: place segment exactly seg_length behind the one ahead
		var new_pos = ahead_pos - dir_to_ahead * seg_length

		# Travelling wave envelope — ramps up from wave_start_point toward the tail
		var t        = float(i) / float(num_points - 1)
		var envelope = max(0.0, (t - wave_start_point) / max(1.0 - wave_start_point, 0.001))
		var perp     = dir_to_ahead.rotated(PI / 2)
		var wave     = sin(time * wave_frequency + i * wave_phase_step) * wave_amplitude * envelope
		new_pos     += perp * wave

		# Smooth lerp so slow fish don't snap their tails
		new_pos = current_pos.lerp(new_pos, clamp(speed * 3.0, 0.1, 1.0))

		_fish_body.set_point_position(i, new_pos)
		_skeleton.set_point_position(i, new_pos)

	# Guard against runaway point accumulation (shouldn't happen, but belt-and-braces)
	if _fish_body.get_point_count() > num_points:
		_fish_body.remove_point(0)
	if _skeleton.get_point_count() > num_points:
		_skeleton.remove_point(0)
