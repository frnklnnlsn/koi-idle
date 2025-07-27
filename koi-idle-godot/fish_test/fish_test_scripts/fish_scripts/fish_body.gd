extends Line2D

@onready var fish_res:fish_conf
@export var offsets:PackedFloat32Array
@export var colors:PackedColorArray
@export var frequency:float
@export var seed:int
@export var noise_type_index:int

@onready var CHECK:String = "This is a test"

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	update_colors(offsets,colors)
	update_seed(seed)
	update_frequency(frequency)
	update_noise_type(noise_type_index)

	
	pass


func update_colors(offsets:PackedFloat32Array, colors:PackedColorArray):
	var color_ramp = self.texture.color_ramp
	color_ramp.offsets = offsets
	color_ramp.colors = colors
	pass

func update_seed(seed):
	if seed:
		self.texture.noise.seed = seed
		#print(body.texture.noise.seed)

func update_frequency(freq)-> void:
	if freq:
		self.texture.noise.frequency = freq


func update_noise_type(index)-> void:
	if index:
		self.texture.noise.noise_type = index
	pass

func setup(seed: int, frequency: float, noise_type_index: int, offsets: PackedFloat32Array, colors: PackedColorArray) -> void:
	self.seed = seed
	self.frequency = frequency
	self.noise_type_index = noise_type_index
	self.offsets = offsets
	self.colors = colors
	#update_colors(offsets,colors)
	#update_seed(seed)
	#update_frequency(frequency)
	#update_noise_type(noise_type_index)

	#update_colors(offsets, new_colors)
