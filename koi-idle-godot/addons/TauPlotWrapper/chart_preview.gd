@tool
class_name ChartPreview
extends Node

@export var plot: TauPlot
@export var chart: Script
@export_tool_button("Refresh Preview") var refresh = _draw_preview

func _draw_preview() -> void:
	if plot == null or chart == null:
		push_warning("ChartPreview: assign Plot and Chart in the Inspector.")
		return
	chart.call("draw", plot, chart.call("sample_data"))
	await get_tree().process_frame
	plot.queue_refresh()
	plot.queue_redraw()
