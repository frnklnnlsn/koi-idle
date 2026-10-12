# SaveData.gd
extends Resource
class_name SaveData

## Bump when the save layout changes, so old saves can be upgraded on load.
const CURRENT_VERSION := 1

@export var save_version: int = CURRENT_VERSION
@export var list_of_work_fish: Array
@export var list_of_retired_fish: Array
@export var list_of_shop_fish: Array
@export var income: float
@export var net_worth: float
