extends Resource
class_name fish_conf


### name is used to make file
@export var name: String
### params for fish_res
@export var offsets:PackedFloat32Array
@export var colors:PackedColorArray
@export var noise_type_index: int
@export var frequency:float
@export var seed:float
