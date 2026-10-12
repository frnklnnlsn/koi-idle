# koi_chart.gd
# Base for koi-idle's charts. Holds the TauPlot reference and fixes one
# TauPlot quirk: a plot measures itself when it is built, so a chart built
# while hidden (the shop and list start hidden) is laid out at the wrong size
# and shows squashed or blank until something rebuilds it. Re-measuring
# whenever the chart becomes visible fixes that.
class_name KoiChart
extends MarginContainer

@onready var plot: TauPlot = $Plot


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and plot:
		# Deferred so Godot has finished sizing the newly shown containers.
		plot.queue_refresh.call_deferred()
