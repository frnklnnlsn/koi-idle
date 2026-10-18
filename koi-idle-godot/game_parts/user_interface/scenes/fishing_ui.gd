# fishing_ui.gd
# The fishing panel. The rules (which rank bites, what a chain is worth, bite
# times) live in FishingLine; this script just drives the buttons and labels.
#
#   Cast      wait for a bite from the rank your bait unlocks
#   Keep      cash in the whole chain (snowball bonus), all its fish leave the pond
#   Release   let everything on the line go; the fish stay in the pond
#   Leave On  keep the new catch on the line as bait for the next rank up
#   Sell Pond fail-safe: sell every pond fish at a discount (click twice to confirm)
#
# Below the panel, the shop's three charts show every pond fish. Fish on the
# line are drawn in the accent colour; fish you kept earlier this session stay
# on the charts, faded (UIPalette chart_caught_earlier). That history is
# forgotten when the game closes.
extends Control

@onready var fishing_status: RichTextLabel = %FishingStatus
@onready var fish_stats:     Label         = %FishStats
@onready var chain_label:    Label         = %ChainLabel
@onready var bite_label:     Label         = %BiteTimer
@onready var bite_bar:       ProgressBar   = %BiteBar
@onready var fishing_button: Button        = %FishingButton
@onready var keep_button:    Button        = %KeepButton
@onready var release_button: Button        = %ReleaseButton
@onready var leave_on_button: Button       = %LeaveOnButton
@onready var fishing_timer:  Timer         = $FishingTimer
@onready var sell_pond_button: Button      = %SellPondButton
# Charts along the bottom half (Charts node in fishing_ui.tscn).
@onready var _scatter: FishScatterChart    = %Scatter
@onready var _growth:  GrowthChart         = %Growth
@onready var _bars:    CollectionChart     = %Bars

## Seconds the Sell Pond confirmation stays armed before it resets.
const SELL_CONFIRM_SECONDS := 4.0

var line := FishingLine.new()
var _waiting     := false   # cast is out, waiting for a bite
var _just_caught := false   # a fresh catch: choose Keep / Release / Leave On
var _sell_armed  := false   # Sell Pond clicked once; next click within SELL_CONFIRM_SECONDS sells
var _sell_arm_id := 0       # so an old timeout can't disarm a newer confirmation
var _caught_earlier: Array = []   # fish kept this session (they've left the pond)


func _ready() -> void:
	fishing_status.bbcode_enabled = true
	fishing_status.visible_ratio = 1.0
	fishing_timer.one_shot = true
	fishing_timer.timeout.connect(_on_fishing_timer_timeout)
	# The pond changes under us (flushes, growth, catches): keep the hints current.
	FishGrowthManager.growth_updated.connect(_refresh)
	visibility_changed.connect(_on_visibility_changed)
	_set_idle_status()
	_refresh()


func _on_visibility_changed() -> void:
	if visible and line.is_empty() and not _waiting:
		_set_idle_status()
	_refresh()


## The status shown with an empty line, depending on what the pond holds.
func _set_idle_status() -> void:
	var pond := _pond_fish()
	if pond.is_empty():
		_set_status("The pond is empty. Flush some fish into it first.")
	elif line.candidates(pond).is_empty():
		_set_status("No rank 0 fish in the pond. Sell Pond to cash out.")
	else:
		_set_status("Cast for a rank 0 fish")


func _process(_delta: float) -> void:
	if not _waiting:
		return
	var r := line.bite_range()
	var elapsed := fishing_timer.wait_time - fishing_timer.time_left
	bite_bar.max_value = r.y
	bite_bar.value = elapsed
	bite_label.text = "%.1fs   (bite in %s–%ss)" % [elapsed, _secs(r.x), _secs(r.y)]


# --- Buttons ------------------------------------------------------------------

func _on_fishing_button_pressed() -> void:
	if _waiting or _just_caught:
		return
	if not line.can_climb() or line.candidates(_pond_fish()).is_empty():
		_refresh()   # nothing can bite; the timer already shows ∞
		return
	_waiting = true
	fishing_timer.wait_time = line.roll_bite_time()
	fishing_timer.start()
	_set_status("[wave amp=20 freq=5 connected=1]Waiting for a rank %d...[/wave]" % line.target_rank())
	_refresh()


func _on_fishing_timer_timeout() -> void:
	_waiting = false
	# Re-check: the pond may have changed while the line was out.
	var pool := line.candidates(_pond_fish())
	if pool.is_empty():
		_set_status("Nothing bit. No rank %d fish left in the pond." % line.target_rank())
		_refresh()
		return
	var fish: fish_conf = pool[randi() % pool.size()]
	line.hook(fish)
	_just_caught = true
	_set_status("Caught a rank %d!  %sg" % [fish.rank, _commas(roundi(fish.mass))])
	_refresh()


func _on_keep_pressed() -> void:
	if line.is_empty() or _waiting:
		return
	var paid := line.value()
	var count := line.chain.size()
	PassiveSystems.pay_catch(paid)
	_caught_earlier.append_array(line.chain)
	DisplayManager.fish_caught.emit(line.chain.duplicate())   # removes them from the pond
	line.clear()
	_just_caught = false
	_set_status("Kept %d fish for $%s" % [count, _commas(floori(paid))])
	_refresh()


func _on_release_pressed() -> void:
	if line.is_empty() or _waiting:
		return
	line.clear()
	_just_caught = false
	_set_status("Released. They swim back into the pond.")
	_refresh()


func _on_leave_on_pressed() -> void:
	if not _just_caught:
		return
	_just_caught = false
	if not line.can_climb():
		_set_status("Top rank on the line. Nothing bigger will bite.")
	elif line.candidates(_pond_fish()).is_empty():
		_set_status("Rank %d on the line, but no rank %d fish are in the pond yet." % [line.top().rank, line.target_rank()])
	else:
		_set_status("Rank %d on the line. Cast for a rank %d!" % [line.top().rank, line.target_rank()])
	_refresh()


func _on_sell_pond_pressed() -> void:
	var pond := _pond_fish()
	if _waiting or pond.is_empty():
		return
	if not _sell_armed:
		# First click: show exactly what will happen and wait for a second click.
		_sell_armed = true
		_sell_arm_id += 1
		var my_id := _sell_arm_id
		_refresh()
		await get_tree().create_timer(SELL_CONFIRM_SECONDS).timeout
		if is_inside_tree() and _sell_armed and _sell_arm_id == my_id:
			_sell_armed = false
			_refresh()
		return
	# Second click: sell everything, including anything on the line.
	_sell_armed = false
	var paid := line.pond_sale_value(pond)
	line.clear()
	_just_caught = false
	PassiveSystems.pay_catch(paid)
	DisplayManager.fish_caught.emit(pond.duplicate())   # removes them all from the pond
	_set_status("Sold %d pond fish for $%s" % [pond.size(), _commas(floori(paid))])
	_refresh()


# --- Display ------------------------------------------------------------------

func _refresh() -> void:
	if not is_node_ready():
		return

	# What's on the line and what it's worth.
	if line.is_empty():
		chain_label.text = "Line: empty"
		fish_stats.text = ""
	else:
		var parts := line.chain.map(func(f): return "R%d %sg" % [f.rank, _commas(roundi(f.mass))])
		chain_label.text = "On line: " + " → ".join(parts)
		var text := "Keep now: $%s" % _commas(floori(line.value()))
		if line.chain.size() > 1:
			text += "   (separately $%s)" % _commas(floori(line.value_if_separate()))
		else:
			text += "   (shop price $%s)" % _commas(Ranks.get_rank(line.top().rank).cost)
		fish_stats.text = text

	# Bite timer: a range for the rank you'd catch next, or ∞ if nothing can bite.
	var can_cast := line.can_climb() and not line.candidates(_pond_fish()).is_empty()
	if not _waiting:
		bite_bar.value = 0.0
		if not line.can_climb():
			bite_label.text = "Next bite: ∞   (top rank on the line)"
		elif not can_cast:
			bite_label.text = "Next bite: ∞   (no rank %d fish in the pond)" % line.target_rank()
		else:
			var r := line.bite_range()
			bite_label.text = "Next bite: %s–%ss   (rank %d)" % [_secs(r.x), _secs(r.y), line.target_rank()]

	fishing_button.disabled = _waiting or _just_caught or not can_cast
	keep_button.disabled = _waiting or line.is_empty()
	release_button.disabled = _waiting or line.is_empty()
	leave_on_button.disabled = not _just_caught

	var pond := _pond_fish()
	_update_charts(pond)
	sell_pond_button.disabled = _waiting or pond.is_empty()
	if pond.is_empty():
		_sell_armed = false
		sell_pond_button.text = "Sell Pond"
	elif _sell_armed:
		sell_pond_button.text = "Confirm: sell %d fish for $%s?" % [pond.size(), _commas(floori(line.pond_sale_value(pond)))]
	else:
		sell_pond_button.text = "Sell Pond ($%s)" % _commas(floori(line.pond_sale_value(pond)))


## Pond fish plus this session's earlier catches; the line's fish highlighted.
func _update_charts(pond: Array) -> void:
	if not is_visible_in_tree():
		return
	var fish := pond + _caught_earlier
	for chart in [_scatter, _growth, _bars]:
		chart.set_fish_collection(fish)
		chart.set_caught(line.chain, _caught_earlier)


func _set_status(bbcode: String) -> void:
	fishing_status.text = "[center]" + bbcode


func _pond_fish() -> Array:
	var save_data := SaveManager.load_saved_data()
	return save_data.list_of_retired_fish if save_data else []


static func _secs(s: float) -> String:
	return str(int(s)) if is_equal_approx(s, roundf(s)) else "%.1f" % s


## 1234567 -> "1,234,567"
static func _commas(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(-3)
	return ("-" if n < 0 else "") + digits + out
