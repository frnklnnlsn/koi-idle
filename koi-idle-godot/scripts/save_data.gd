#save_data.gd
extends Resource
class_name SaveData
### not sureif I should make this a resource so it can be saved?


### these are the three places that fish will be.
@export var list_of_work_fish:Array 
@export var lsit_of_retired_fish:Array
@export var list_of_shop_fish:Array

@export var income:float
@export var net_worth:float
