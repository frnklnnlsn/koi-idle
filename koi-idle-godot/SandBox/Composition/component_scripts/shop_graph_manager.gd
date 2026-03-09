class_name ShopGraphManager
extends Node

var distribution_graph
var growth_curve
var histogram_graph
var is_pond: bool = false  # ← ADD THIS

func _init(dist, growth, hist):
	distribution_graph = dist
	growth_curve = growth
	histogram_graph = hist

func update_for_fish(fish: fish_conf):
	if distribution_graph: distribution_graph.set_fish_value(fish.value)
	if growth_curve:
		growth_curve.set_fish_growth(fish)
		if is_pond:                             # ← ADD THIS
			growth_curve.set_progress_marker(fish)
	if histogram_graph: histogram_graph.set_fish_card_hover(fish)

func refresh_histogram(fish_array: Array):
	if histogram_graph: histogram_graph.set_fish_collection(fish_array)

func clear_hover():
	if histogram_graph: histogram_graph.clear_fish_card_hover()

func clear_all():
	if distribution_graph: distribution_graph.clear_fish_value()
	if growth_curve:        growth_curve.clear_fish_growth()
	if histogram_graph:     histogram_graph.clear_histogram()
