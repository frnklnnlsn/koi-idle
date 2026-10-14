# economy_tab.gd
# The "Economy" tab of the developer panel.
#
# Top: the five settings you tune most. "More settings" folds out the rest.
# Grid: one row per rank. Income/s and Stretch are editable; prices refit
# automatically so the simulated passive player reaches each rank on time.
#
#   Generate     new incomes and prices for every rank from the settings
#   Apply        use these ranks in the running game (keeps your save)
#   Play fresh   apply, then wipe the save and start a new run
#   Save         write them to rank_table.tres (and the settings to economy_knobs.tres)
extends VBoxContainer

const KNOBS_PATH := "res://game_parts/fish_ranks/economy_knobs.tres"
const SEEDS := 5
## Wait this long after the last edit before refitting (spin arrows fire fast).
const SETTLE_SECONDS := 0.35

## Main settings: [label, knob field, min, max, step, what a change does]
const MAIN := [
	["Ranks", "rank_count", 2, 30, 1, "generate"],
	["Rank 0 income/s", "rank0_income", 0.01, 100000.0, 0.01, "generate"],
	["Rank 0 price", "rank0_cost", 1, 100000, 1, "refit"],
	["Catch return ×", "catch_return", 0.0, 1000.0, 0.05, "simulate"],
	["Fast grower odds", "fast_grower_chance", 0.0, 1.0, 0.005, "simulate"],
]
## Folded-away settings.
const MORE := [
	["Rank 1 at (min)", "first_rank_minutes", 0.1, 600.0, 0.1, "refit"],
	["Time growth ×", "time_growth", 1.0, 10.0, 0.05, "refit"],
	["Income growth ×", "income_growth", 1.05, 50.0, 0.05, "generate"],
	["Roll spread", "roll_spread", 0.0, 1.0, 0.01, "spread"],
	["Fishing target ×", "fishing_speedup", 1.0, 10.0, 0.1, "simulate"],
	["Bait / upgrade", "bait_per_upgrade", 0, 100, 1, "simulate"],
	["Fish every (min)", "fish_every_minutes", 0.5, 600.0, 0.5, "simulate"],
	["Let grow (min)", "grow_minutes", 0.0, 6000.0, 5.0, "simulate"],
	["Pond speed ×", "pond_time_scale", 0.1, 3600.0, 0.1, "simulate"],
	["Bite growth ×", "bite_growth", 1.0, 5.0, 0.05, "generate"],
]
const INT_FIELDS := ["rank_count", "rank0_cost", "bait_per_upgrade"]

var knobs: EconomyKnobs
## The ranks being worked on (copies; the game only changes on Apply/Save).
var ranks: Array[FishRank] = []

var _passive := {}
var _fishing := {}
var _speedups := PackedFloat64Array()
var _rows := []            # per rank: {income: SpinBox, price, payback, target, reached: Label}
var _rank_grid: GridContainer
var _more_box: GridContainer
var _summary: Label
var _status: Label
var _plot: TauPlot
var _pending := ""         # "refit" or "simulate", run once edits settle
var _pending_id := 0


func _ready() -> void:
	name = "EconomyTab"
	if ResourceLoader.exists(KNOBS_PATH):
		knobs = (load(KNOBS_PATH) as EconomyKnobs).duplicate()
	else:
		knobs = EconomyKnobs.new()
		knobs.rank_count = Ranks.count()
	knobs.catch_return = Ranks.table().catch_return
	knobs.fast_grower_chance = Ranks.table().fast_grower_chance
	for r in Ranks.all():
		ranks.append(r.duplicate())
	if not ranks.is_empty():
		knobs.rank0_cost = ranks[0].cost
	_build()
	_rebuild_grid()
	_simulate()
	_say("Showing the game's current ranks. Edit incomes or stretch, or press Generate.")


# --- Actions --------------------------------------------------------------------

## New incomes (rank 0 income × income growth per rank) and fitted prices.
func _generate() -> void:
	ranks = RankCurve.generate(knobs, Ranks.all())
	var t0 := Time.get_ticks_msec()
	RankCurve.fit(knobs, ranks)
	_rebuild_grid()
	_simulate()
	_say("Generated %d ranks and fitted prices (%d ms)." % [ranks.size(), Time.get_ticks_msec() - t0])


func _refit() -> void:
	RankCurve.fit(knobs, ranks)
	_simulate()
	_say("Prices refitted to the targets.")


func _simulate() -> void:
	if ranks.size() < 2:
		return
	var sim := RankCurve.make_sim(knobs, ranks)
	_passive = sim.run(false, 1)
	_fishing = sim.run(true, 1)
	# One run depends on luck, so measure the fishing speed-up over a few seeds.
	_speedups.clear()
	var top := ranks.size() - 1
	for seed_i in range(1, SEEDS + 1):
		var p: Dictionary = _passive if seed_i == 1 else sim.run(false, seed_i)
		var f: Dictionary = _fishing if seed_i == 1 else sim.run(true, seed_i)
		if p["reached"][top] > 0.0 and f["reached"][top] > 0.0:
			_speedups.append(p["reached"][top] / f["reached"][top])
	_refresh()


## `reload`: rebuild the game scene so the shop dropdown, charts etc. pick up
## the new ranks. Play fresh passes false because the save reset reloads too.
func _apply(reload := true) -> void:
	var table := Ranks.table()
	var copy: Array[FishRank] = []
	for r in ranks:
		copy.append(r.duplicate())
	table.ranks.assign(copy)   # replace the contents in place
	table.catch_return = knobs.catch_return
	table.fast_grower_chance = knobs.fast_grower_chance
	if reload:
		SaveManager.reload_scene_once()
	_say("Applied %d ranks to the running game (not saved to disk yet)." % ranks.size())


func _play_fresh() -> void:
	_apply(false)
	SaveManager.reset_save_data()   # wipes the save and reloads the scene once
	_say("Applied and started a fresh run.")


func _save() -> void:
	_apply()
	var err := ResourceSaver.save(Ranks.table(), Ranks.TABLE_PATH)
	var err2 := ResourceSaver.save(knobs, KNOBS_PATH)
	if err != OK or err2 != OK:
		_say("Could not save (%s). Saving only works when running from the editor." % error_string(err if err != OK else err2))
	else:
		_say("Saved to %s. Open it in the Inspector to hand-tweak." % Ranks.TABLE_PATH)


# --- Edits ----------------------------------------------------------------------

func _on_knob(value: float, field: String, effect: String) -> void:
	knobs.set(field, int(value) if field in INT_FIELDS else value)
	match effect:
		"generate":
			_say("Press Generate to rebuild the ranks with this.")
		"spread":
			# Re-shape every rank's bell, keeping each rank's average income.
			for r in ranks:
				RankCurve.set_spread(r, knobs.roll_spread)
			_schedule("refit")
		"refit":
			if field == "rank0_cost" and not ranks.is_empty():
				ranks[0].cost = int(value)
			_schedule("refit")
		_:
			_schedule("simulate")


func _on_income(value: float, rank: int) -> void:
	RankCurve.set_income(ranks[rank], value)
	_schedule("refit")


func _on_stretch(value: float, rank: int) -> void:
	if knobs.stretch.size() < ranks.size():
		var old := knobs.stretch.size()
		knobs.stretch.resize(ranks.size())
		for i in range(old, ranks.size()):
			knobs.stretch[i] = 1.0
	knobs.stretch[rank] = value
	_schedule("refit")


## Run a refit / simulation once the edits stop for a moment. A refit wins over
## a simulation (it simulates too).
func _schedule(what: String) -> void:
	if _pending != "refit":
		_pending = what
	_pending_id += 1
	var my_id := _pending_id
	_say("Updating...")
	await get_tree().create_timer(SETTLE_SECONDS).timeout
	if my_id != _pending_id or not is_inside_tree():
		return
	var what_now := _pending
	_pending = ""
	if what_now == "refit":
		_refit()
	else:
		_simulate()
		_say("Simulation updated.")


# --- Display --------------------------------------------------------------------

## One row per rank. Only rebuilt when the set of ranks changes, so editing a
## box never loses focus.
func _rebuild_grid() -> void:
	for c in _rank_grid.get_children():
		_rank_grid.remove_child(c)
		c.queue_free()
	_rows.clear()
	for h in ["Rank", "Income/s", "Stretch", "Price", "Payback", "Target", "Reached"]:
		_rank_grid.add_child(_cell(h, true))
	for n in ranks.size():
		_rank_grid.add_child(_cell(ranks[n].display_name))
		var inc := _spin(RankCurve.avg_income(ranks[n]), 0.001, 1e12, 0.01)
		inc.tooltip_text = "Average income per fish. Prices refit after you change it."
		inc.custom_minimum_size.x = 108
		inc.value_changed.connect(_on_income.bind(n))
		_rank_grid.add_child(inc)
		if n == 0:
			_rank_grid.add_child(_cell("—"))
		else:
			var st := _spin(knobs.stretch_for(n), 0.1, 10.0, 0.05)
			st.custom_minimum_size.x = 62
			st.tooltip_text = "Time to reach this rank × this. Prices refit after you change it."
			st.value_changed.connect(_on_stretch.bind(n))
			_rank_grid.add_child(st)
		var row := {"income": inc}
		for key in ["price", "payback", "target", "reached"]:
			row[key] = _cell("")
			_rank_grid.add_child(row[key])
		_rows.append(row)


func _refresh() -> void:
	var p: PackedFloat64Array = _passive.get("reached", PackedFloat64Array())
	var f: PackedFloat64Array = _fishing.get("reached", PackedFloat64Array())

	for n in mini(_rows.size(), ranks.size()):
		var row: Dictionary = _rows[n]
		var income := RankCurve.avg_income(ranks[n])
		row["income"].set_value_no_signal(income)
		row["price"].text = "$" + FishLabelDisplay.num(ranks[n].cost)
		row["payback"].text = FishLabelDisplay.duration(ranks[n].cost / income) if income > 0.0 else "—"
		row["target"].text = "—" if n == 0 else _time(RankCurve.target_reach(knobs, n))
		row["reached"].text = _reach(p, n)

	# Summary
	var top := ranks.size() - 1
	var lines := []
	if p.size() > top and p[top] >= 0.0:
		lines.append("Passive play reaches %s in %s." % [ranks[top].display_name, _time(p[top])])
	else:
		lines.append("Passive play never reaches %s." % ranks[top].display_name)
	if _speedups.size() > 0:
		var lo := INF
		var hi := -INF
		var sum := 0.0
		for x in _speedups:
			lo = minf(lo, x)
			hi = maxf(hi, x)
			sum += x
		lines.append("Fishing makes it ×%.2f faster on average (×%.2f–×%.2f over %d runs; target ×%.1f)." % [
			sum / _speedups.size(), lo, hi, _speedups.size(), knobs.fishing_speedup])
	_summary.text = "\n".join(lines)

	# Chart: minutes to reach each rank
	var cats := PackedStringArray()
	var target := []
	var pas := []
	var fis := []
	for n in range(1, ranks.size()):
		cats.append("R%d" % n)
		target.append(RankCurve.target_reach(knobs, n) / 60.0)
		pas.append(maxf(p[n], 0.0) / 60.0 if n < p.size() else 0.0)
		fis.append(maxf(f[n], 0.0) / 60.0 if n < f.size() else 0.0)
		TauCharts.bar(_plot, "Minutes to reach each rank", cats,
		{"Target": target, "Passive": pas, "With fishing": fis},
		{"y_title": "Minutes", "legend": true})


func _reach(arr: PackedFloat64Array, n: int) -> String:
	if n >= arr.size():
		return "?"
	if arr[n] < 0.0:
		return "never"
	return "start" if n == 0 else _time(arr[n])


static func _time(seconds: float) -> String:
	return FishLabelDisplay.duration(seconds)


func _say(text: String) -> void:
	_status.text = text
	if text != "Updating...":
		print("[Dev/Economy] ", text)


# --- UI construction ------------------------------------------------------------

func _build() -> void:
	custom_minimum_size.x = 520

	var grid := GridContainer.new()
	grid.columns = 4
	add_child(grid)
	for spec in MAIN:
		_add_knob(grid, spec)

	var more_button := Button.new()
	more_button.text = "More settings ▸"
	more_button.flat = true
	more_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(more_button)
	_more_box = GridContainer.new()
	_more_box.columns = 4
	_more_box.visible = false
	add_child(_more_box)
	for spec in MORE:
		_add_knob(_more_box, spec)
	more_button.pressed.connect(func():
		_more_box.visible = not _more_box.visible
		more_button.text = "More settings ▾" if _more_box.visible else "More settings ▸")

	_row([["Generate", _generate]])

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size.x = 500
	add_child(_summary)

	_rank_grid = GridContainer.new()
	_rank_grid.columns = 7
	_rank_grid.add_theme_constant_override("h_separation", 8)
	add_child(_rank_grid)

	_plot = TauPlot.new()
	_plot.custom_minimum_size = Vector2(500, 210)
	add_child(_plot)

	_row([["Apply", _apply], ["Play fresh", _play_fresh], ["Save to table", _save]])

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 500
	add_child(_status)


func _add_knob(grid: GridContainer, spec: Array) -> void:
	grid.add_child(_cell(spec[0]))
	var spin := _spin(knobs.get(spec[1]), spec[2], spec[3], spec[4])
	spin.value_changed.connect(_on_knob.bind(spec[1], spec[5]))
	grid.add_child(spin)


func _row(buttons: Array) -> void:
	var row := HBoxContainer.new()
	add_child(row)
	for spec in buttons:
		var b := Button.new()
		b.text = spec[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		row.add_child(b)


func _cell(text: String, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	if bold:
		l.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	return l


func _spin(value: float, lo: float, hi: float, step: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.allow_greater = true
	s.custom_minimum_size.x = 90
	return s
