extends Resource
class_name fish_conf

### stats
@export var value: float
@export var income: float
@export var mass: float
## How lucky each stat roll was (bell-curve z, 0 = average). FishStats turns
## these into rarity: FishStats.rarity_label(fish.income_z) -> "top 3%".
@export var income_z: float = 0.0
@export var mass_z: float = 0.0
## Growth potential (how big it can grow relative to its starting mass).
@export var size_z: float = 0.0
### fish rank decides the range of fish stats
@export var rank: int
@export var cost: float
@export var age: float

### growth_rate stuff
@export var growth_rate :float
@export var carrying_capacity :float
@export var mid_point:float = 0.0
@export var x_range:float = 10
@export var x_start:float
@export var y_start:float


### generated tag/ID, name can be displayed instead
@export var ID: String
### name is used to make file
@export var name: String
### vsual stuff
@export var offsets:PackedFloat32Array
@export var colors:PackedColorArray
@export var fin_color: Color
@export var noise_type_index: int
@export var frequency:float
@export var seed:float
