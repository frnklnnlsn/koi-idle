extends Node

### signals
signal new_fish(fish_array:Array)


### this signleton upon request of say a button, will call a function, asking for number and rank, and create that many
### fish which will be passed to the save_data manager, where the fish will be saved in a nested fish_list_array
### this singleton will also call upon Economy to update its values of net_worth, income, on a per fish bought basis
@onready var fish_res:fish_conf = preload("res://themes/base_fish.tres")


var selected_pallet: PackedColorArray = PackedColorArray([
	Color(1.0, 0.0, 0.0),    # Red
	Color(0.0, 0.0, 0.0),    # Black
	Color(1.0, 1.0, 1.0),    # White
	Color(1.0, 0.5, 0.0),    # Orange
	Color(0.96, 0.96, 0.86)  # Beige
])

var fish_cost_array = [1,10,100] # the cost of the different ranks

var fish_base_value = .1
var fish_base_mass = .5
var fish_base_income = 1
var groth_rate 
#signal build_fish()

### the variables that are getting passed in right now are number of fish to be purchased, 1,2,3,4,5... 
### and the rank of fish, this is what seperates the range of fish stats that will be give
### rarity will just be a measure of distribution



func generate_fish(num,rank):
	
	#var save_data = SaveManager.load_saved_data() #should return the save data resource
	var fish_res_Array = []
	
	for i in range(num):
		var fish_value = provide_values_based_on_rank(rank)
		var new_fish = new_fish_res_get(fish_value,rank) ### generates new stats for a res
		visual_params_new_set(new_fish) ### generates and sets the new visual stuff
		
		fish_res_Array.append(new_fish)
		
	#take the array of new fish res, and send it where it needs to be sent
	#save_data.list_of_shop_fish.append(fish_res_Array)### saves new generated fish to the shop list, that is the array to hold purchased fish, before sendiong
	#SaveManager.save_current_data(save_data) ### adds the new_fish to the save_data resource 
	#Economy.update_income(fish_res_Array) ### move this to the Economy, casue I am already sending signal
	new_fish.emit(fish_res_Array) #fish interface is listening


 


###start_value: int, end_value: int, peak_position: int, decay_rate: float = 0.1
###    0                1				2					3			
var rank_1_Array = [
	1, #start value
	100, #end value
	10, #peakposition
	0.8, #decay_rate
]

var rank_2_Array = [
	100, #start value
	200, #end value
	110, #peakposition
	0.8, #decay_rate
]

var rank_3_Array = [
	200, #start value
	300, #end value
	310, #peakposition
	0.8, #decay_rate
]

func provide_values_based_on_rank(rank):
	#for each rank make an array with the valid ranges
	#this is the array of all rank ranges
	var range_array= [
		rank_1_Array, #rank 0
		rank_2_Array, #rank 1
		rank_3_Array, #rank 2
	]
	
	# put the correspounding array for the given rank in the get list of numbers funtion
	# returns the range_hold which is the distribution of possible outcomes of this rank
	var range_hold = create_right_skewed_array(range_array[rank])
	var size = range_hold.size() # get the size of the array
	var picker = randi_range(0,size) # grab a random number from within the size limit
	var value = range_hold[picker] # set that number as the value
	return value 



func new_fish_res_get(value:float,rank:int) -> fish_conf: #returns resource with the given stats
	var new_res = fish_res.duplicate(true)
	
	new_res.ID = generate_id(15)
	new_res.rank = rank
	new_res.value = value * fish_base_value
	var new_mass =  value * fish_base_mass
	new_res.mass = new_mass
	new_res.income = value * fish_base_income
	
	new_res.cost = fish_cost_array[rank]
	
	var new_growth_rate = growth_rate_get()
	new_res.growth_rate = new_growth_rate
	new_res.carrying_capacity = carrying_capacity_get(new_mass)
	new_res.x_start = x_start_get(new_growth_rate)
	new_res.y_start = new_mass
	new_res.mid_point = mid_point_get()
	return new_res
 

	
func create_right_skewed_array(My_Array:Array) -> Array:
	var weighted_array = []
	### compreses to save time
	var start_value = My_Array[0]
	var end_value = My_Array[1]
	var peak_position = My_Array[2]
	var decay_rate = My_Array[3]
	
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


### growth rate stuffff ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

func growth_rate_get() -> float:
	var growth_rate = randf_range(.75,5)
	return growth_rate

func mid_point_get() -> float:
	var mid_point = randf_range(.75,5)
	return mid_point
func carrying_capacity_get(mass) -> int:
	var y_start = mass*randi_range(1,100)
	return y_start


func x_start_get(G_R) -> float:
	var x_start
	if G_R <=1:
		x_start = randf_range(6,10)
		return x_start
	elif G_R <= 1.5:
		x_start = randf_range(5,10)
		return x_start
	elif G_R <= 2:
		x_start = randf_range(3,10)
		return x_start
	elif G_R <= 3:
		x_start = randf_range(2.5,10)
		return x_start
	else:
		x_start = randf_range(2,10)
		return x_start


### visual stuffff ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

func visual_params_new_set(new_res:fish_conf):
	var number_of_color = generate_number_of_color()
	var pallet = generate_unique_colors(number_of_color,selected_pallet)
	new_res.colors = generate_colors(number_of_color,pallet)
	new_res.offsets = generate_offsets(number_of_color)
	new_res.seed = generate_seed()
	new_res.frequency = generate_frequency()
	new_res.noise_type_index = 0 



func generate_seed() -> int:
	var seed  =  randi_range(-99,99)
	return seed



func generate_frequency() -> float:
	var frequency = randf_range(0.0001,0.003)
	return frequency


func generate_name(number)-> String:
	var fish_name:String = "fish_" + str(number)
	return fish_name


func generate_number_of_color()-> int:
	var number  =  randi_range(1,5)
	return number


func generate_offsets(number_of_color) -> PackedFloat32Array:
	var offsets:PackedFloat32Array = []
	for color in number_of_color:
		var offset = randf_range(0,1)
		offsets.append(offset)
	return offsets


func generate_unique_colors(number_of_color: int, pallet: PackedColorArray) -> PackedColorArray:
	# Step 1: Convert to normal Array
	var array_colors := []
	for color in pallet:
		array_colors.append(color)

	# Step 2: Shuffle
	array_colors.shuffle()

	# Step 3: Convert back to PackedColorArray
	var packed_colors := PackedColorArray()
	for i in range(min(number_of_color, array_colors.size())):
		packed_colors.append(array_colors[i])

	return packed_colors


func generate_colors(number_of_color: int, pallet: PackedColorArray) -> PackedColorArray:
	var colors := PackedColorArray()
	for i in range(number_of_color):
		var index = randi_range(0, pallet.size() - 1)  # Use full range of palette
		colors.append(pallet[index])
	return colors


func generate_id(length: int = 15) -> String:
	var characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var id = ""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in length:
		var random_index = rng.randi() % characters.length()
		id += characters[random_index]
	
	return id
