extends Node

signal display_fish_toilet(list)
signal display_fish_pond(list)
signal flush_fish
signal fish_caught(fish: Array)
signal flush_completed

var is_flushing: bool = false
