extends Node

signal display_fish_toilet(list)
signal display_fish_pond(list)
signal flush_fish
signal fish_caught(fish: Array)
signal flush_completed
## Every toilet fish was sold (:sellall): the toilet removes its fish.
signal toilet_cleared

var is_flushing: bool = false
