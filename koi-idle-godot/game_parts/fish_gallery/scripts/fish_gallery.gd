extends Node

@export var fish_res:fish_conf
@export var pallet_1:PackedColorArray 
@export var number_of_fish:int
@onready var viewport = %SubViewport

### gd scripts for the procedural fish
#@onready var procedural_fish = preload("res://fish_gallery/scripts/procedural_fish.gd")
#@onready var skeleton = preload("res://fish_gallery/scripts/procedural_skeleton.gd")
#@onready var body = preload("res://fish_gallery/scripts/procedural_body.gd")
### the selected pallet
@onready var selected_pallet = pallet_1



func _ready():
	generate_random_fish(25)

	pass


func _process(delta):
	pass


func generate_random_fish(number):
	for i in range(number):
		var new_res = new_generate_res(fish_res)
		new_generate_fish(new_res)
		



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


#func generate_new_fish(fish_res) -> Node2D:
	#var scene = preload("res://fish_gallery/scenes/procedural_fish.tscn").instantiate()
	#var line_skeleton = scene.get_node("skeleton")
	#var line_body = scene.get_node("body")
#
	## Generate data
	#var number_of_colors = generate_number_of_color()
	#var offsets = generate_offsets(number_of_colors)
	#var colors = generate_colors(number_of_colors, selected_pallet)
#
	#var instance = preload("res://fish_gallery/scripts/procedural_body.gd").new()
	#var script = instance.get_script()
	#
	#
	## Apply values to body
	#line_body.set_script(script)
	#line_body.CHECK = randi_range(0,20)
	##print(line_body.CHECK)
	##print_debug(line_body.get_script())
	#line_body.call("setup", fish_res.seed, fish_res.frequency, fish_res.noise_type_index, offsets, colors)
#
	## Apply skeleton logic
	#line_skeleton.set_script(preload("res://fish_gallery/scripts/procedural_skeleton.gd"))
#
	## Apply overall fish logic
	#scene.set_script(preload("res://fish_gallery/scripts/procedural_fish.gd"))
#
	#return scene

func new_generate_res(fish_res) -> fish_conf:
	var new_res = fish_res.duplicate(true)
	var number_of_color = generate_number_of_color()
	var pallet = generate_unique_colors(number_of_color,selected_pallet)
	new_res.colors = generate_colors(number_of_color,pallet)
	new_res.offsets = generate_offsets(number_of_color)
	new_res.seed = generate_seed()
	new_res.frequency = generate_frequency()
	new_res.noise_type_index = 0 ### this is simplex
	return new_res


func new_generate_fish(fish_res):
	var scene = preload("res://game_parts/fish_gallery/scenes/procedural_fish.tscn").instantiate()
	var line_body = scene.get_node("body")
	
	# Force duplicate the texture and its sub-resources BEFORE modifying
	if line_body.texture:
		line_body.texture = line_body.texture.duplicate(true)
		if line_body.texture.color_ramp:
			line_body.texture.color_ramp = line_body.texture.color_ramp.duplicate(true)
		if line_body.texture.noise:
			line_body.texture.noise = line_body.texture.noise.duplicate(true)
	
	var script = preload("res://game_parts/fish_gallery/scripts/procedural_body.gd")
	var instance = script.new()
	line_body.add_child(instance)
	instance.modify_parent(fish_res)
	viewport.add_child(scene)

#func new_generate_fish(fish_res):
	#var scene = preload("res://fish_gallery/scenes/procedural_fish.tscn").instantiate()
	#var line_body = scene.get_node("body")
	#var script = preload("res://fish_gallery/scripts/procedural_body.gd")
	#var instance = script.new()
	#line_body.add_child(instance)
	#instance.modify_parent(fish_res)
	#viewport.add_child(scene)

#func iterate(array:Array): ## of int x
	#for i in array:
		#var scene1 = preload("res://SandBox/seperated script test/scenes/Instnace_test.tscn").instantiate()
		#var MyClass = load("res://SandBox/seperated script test/scripts/myclass.gd")
		#var instance1 = MyClass.new()
		#scene1.add_child(instance1)
		#add_child(scene1)
		#var child_node = scene1.get_child(0)
		#child_node.change_parent_position(i)
