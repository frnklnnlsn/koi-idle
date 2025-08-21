extends Node2D


# Called when the node enters the scene tree for the first time.

var start = 200
var end = 300
var peak = 210
var decay = 0.8

func _ready() -> void:
	var weighted_arrray = create_right_skewed_array(start,end,peak,decay)
	#print(weighted_arrray)
	#print(weighted_arrray.size())
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func create_right_skewed_array(start_value: int, end_value: int, peak_position: int, decay_rate: float = 0.1) -> Array:
	var weighted_array = []
	
	for i in range(start_value, end_value + 1):
		var weight: int
		
		if i <= peak_position:
			# Left side: steep drop-off
			var distance_left = peak_position - i
			weight = int(100 * exp(-pow(distance_left, 2) / 10.0))
		else:
			# Right side: gradual exponential decay (long tail)
			var distance_right = i - peak_position
			weight = int(100 * exp(-decay_rate * distance_right))
		
		weight = max(weight, 1)
		
		for j in range(weight):
			weighted_array.append(i)
	
	return weighted_array
	

func smooth_s_curve(x: float, max_value: float, slow_duration: float, exp_start: float, plateau_start: float, steepness: float = 1.0) -> float:
	# Transform x to fit our custom phases
	var total_duration = plateau_start + (plateau_start - exp_start)  # Estimate total curve length
	
	# Create custom transformation
	var transformed_x: float
	if x <= slow_duration:
		# Slow phase: compress x
		transformed_x = (x / slow_duration) * 0.2 * total_duration
	elif x <= exp_start:
		# Transition phase
		var transition_progress = (x - slow_duration) / (exp_start - slow_duration)
		transformed_x = 0.2 * total_duration + transition_progress * 0.1 * total_duration
	elif x <= plateau_start:
		# Exponential phase: normal progression
		var exp_progress = (x - exp_start) / (plateau_start - exp_start)
		transformed_x = 0.3 * total_duration + exp_progress * 0.4 * total_duration
	else:
		# Plateau phase: stretch x
		var plateau_progress = x - plateau_start
		transformed_x = 0.7 * total_duration + plateau_progress * 0.3
	
	# Apply sigmoid to transformed x
	var midpoint = total_duration * 0.5
	return max_value / (1.0 + exp(-steepness * 0.1 * (transformed_x - midpoint)))
