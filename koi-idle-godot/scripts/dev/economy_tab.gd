# economy_tab.gd
# The "Economy" tab of the developer panel. Build ranks from a few curves,
# simulate how long each rank takes to reach, fit prices to your targets, then
# play the result or save it to the rank table for hand tweaking.
#
#   Generate     new ranks from the knobs (rough prices)
#   Fit prices   find each rank's price so passive play hits its target time
#   Simulate     re-run the simulation without changing anything
#   Apply        use these ranks in the running game (keeps your save)
#   Play fresh   apply, then wipe the save and start a new run
#   Save         write them to rank_table.tres (and the knobs to economy_knobs.tres)
extends VBoxContainer

const KNOBS_PATH := "res://game_parts/fish_ranks/economy_knobs.tres"

var knobs: EconomyKnobs
## The ranks being worked on (copies; the game only changes on Apply/Save).
var ranks: Array[FishRank] = []

var _passive := {}
var _fishing := {}
var _spins := {}
var _rank_grid: GridContainer
var _target_cells := {}   # rank -> Label, updated live when a stretch changes
var _summary: Label
var _status: Label
var _plot: TauPlot


func _ready() -> void:
	name = "EconomyTab"
	if ResourceLoader.exists(KNOBS_PATH):
		knobs = (load(KNOBS_PATH) as EconomyKnobs).duplicate()
	else:
		knobs = EconomyKnobs.new()
		knobs.rank_count = Ranks.count()
	knobs.coins_per_gram = PassiveSystems.fishing_multiplier
	_load_current_table()
	_build()
	_simulate()
	_say("Showing the current rank table. Change the knobs and press Generate.")


# --- Actions --------------------------------------------------------------------

func _load_current_table() -> void:
	ranks.clear()
	for r in Ranks.all():
		ranks.append(r.duplicate())


func _generate() -> void:
	ranks = RankCurve.generate(knobs, Ranks.all())
	_simulate()
	_say("Generated %d ranks with rough prices. Press Fit prices to match the targets." % ranks.size())


func _fit() -> void:
	var t0 := Time.get_ticks_msec()
	RankCurve.fit(knobs, ranks)
	_simulate()
	_say("Prices fitted in %d ms." % (Time.get_ticks_msec() - t0))


func _simulate() -> void:
	if ranks.size() < 2:
		return
	var sim := RankCurve.make_sim(knobs, ranks)
	_passive = sim.run(false, 1)
	_fishing = sim.run(true, 1)
	_refresh()


func _apply() -> void:
	var table := Ranks.table()
	var copy: Array[FishRank] = []
	for r in ranks:
		copy.append(r.duplicate())
	table.ranks.assign(copy)   # replace the contents in place
	table.coins_per_gram = knobs.coins_per_gram
	get_tree().reload_current_scene()   # shop dropdown, charts etc. rebuild
	_say("Applied %d ranks to the running game (not saved to disk yet)." % ranks.size())


func _play_fresh() -> void:
	_apply()
	SaveManager.reset_save_data()
	_say("Applied and started a fresh run.")


func _save() -> void:
	_apply()
	var err := ResourceSaver.save(Ranks.table(), Ranks.TABLE_PATH)
	var err2 := ResourceSaver.save(knobs, KNOBS_PATH)
	if err != OK or err2 != OK:
		_say("Could not save (%s). Saving only works when running from the editor." % error_string(err if err != OK else err2))
	else:
		_say("Saved to %s. Open it in the Inspector to hand-tweak." % Ranks.TABLE_PATH)


# --- Display --------------------------------------------------------------------

func _refresh() -> void:
	# Per-rank table
	for c in _rank_grid.get_children():
		_rank_grid.remove_child(c)
		c.queue_free()
	_target_cells.clear()
	for h in ["Rank", "Stretch", "Target", "Passive", "Fishing", "Price", "Income/s"]:
		_rank_grid.add_child(_cell(h, true))
	var p: PackedFloat64Array = _passive.get("reached", PackedFloat64Array())
	var f: PackedFloat64Array = _fishing.get("reached", PackedFloat64Array())
	for n in ranks.size():
		_rank_grid.add_child(_cell(ranks[n].display_name))
		if n == 0:
			_rank_grid.add_child(_cell("—"))
		else:
			var spin := _spin(knobs.stretch_for(n), 0.1, 10.0, 0.05)
			spin.value_changed.connect(_on_stretch.bind(n))
			_rank_grid.add_child(spin)
		var tc := _cell("—" if n == 0 else _time(RankCurve.target_reach(knobs, n)))
		_target_cells[n] = tc
		_rank_grid.add_child(tc)
		_rank_grid.add_child(_cell(_reach(p, n)))
		_rank_grid.add_child(_cell(_reach(f, n)))
		_rank_grid.add_child(_cell("$" + DevTools._commas(ranks[n].cost)))
		_rank_grid.add_child(_cell(DevTools._commas(_avg_income(ranks[n]))))

	# Summary
	var top := ranks.size() - 1
	var lines := []
	if p.size() > top and p[top] >= 0.0:
		lines.append("Passive reaches %s in %s." % [ranks[top].display_name, _time(p[top])])
	else:
		lines.append("Passive never reaches %s within the simulated time." % ranks[top].display_name)
	if f.size() > top and f[top] >= 0.0 and p[top] > 0.0:
		lines.append("Fishing speed-up: ×%.2f (target ×%.1f). Fishing earned $%s, passive $%s." % [
			p[top] / f[top], knobs.fishing_speedup,
			DevTools._commas(_fishing["fishing_income"]), DevTools._commas(_fishing["passive_income"])])
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


func _on_stretch(value: float, rank: int) -> void:
	if knobs.stretch.size() < knobs.rank_count:
		var old := knobs.stretch.size()
		knobs.stretch.resize(knobs.rank_count)
		for i in range(old, knobs.rank_count):
			knobs.stretch[i] = 1.0
	knobs.stretch[rank] = value
	# Only the targets change; update them in place (rebuilding the table would
	# take the cursor out of the box being edited). Fit prices to act on it.
	for n in _target_cells:
		if n > 0:
			_target_cells[n].text = _time(RankCurve.target_reach(knobs, n))


func _on_knob(value: float, field: String) -> void:
	knobs.set(field, int(value) if field in ["rank_count", "rank0_cost", "bait_slots"] else value)


func _avg_income(r: FishRank) -> float:
	var vw: Dictionary = FishGenerator.value_weights(r)
	var tw := 0.0
	var tv := 0.0
	for i in vw["values"].size():
		tw += vw["weights"][i]
		tv += vw["values"][i] * vw["weights"][i]
	return tv / tw * FishGenerator.FISH_BASE_INCOME


func _reach(arr: PackedFloat64Array, n: int) -> String:
	if n >= arr.size():
		return "?"
	if arr[n] < 0.0:
		return "never"
	return "0" if n == 0 else _time(arr[n])


static func _time(seconds: float) -> String:
	if seconds < 90.0:
		return "%ds" % roundi(seconds)
	if seconds < 90.0 * 60.0:
		return "%.1f min" % (seconds / 60.0)
	return "%.1f h" % (seconds / 3600.0)


func _say(text: String) -> void:
	_status.text = text
	print("[Dev/Economy] ", text)


# --- UI construction ------------------------------------------------------------

func _build() -> void:
	custom_minimum_size.x = 520

	var grid := GridContainer.new()
	grid.columns = 4
	add_child(grid)
	for spec in [
		["Ranks", "rank_count", 2, 30, 1],
		["Rank 1 at (min)", "first_rank_minutes", 0.1, 600.0, 0.1],
		["Time growth ×", "time_growth", 1.0, 10.0, 0.05],
		["Income growth ×", "income_growth", 1.05, 50.0, 0.05],
		["Rank 0 income/s", "rank0_income", 0.1, 1000.0, 0.1],
		["Rank 0 price", "rank0_cost", 1, 100000, 1],
		["Coins per gram", "coins_per_gram", 0.0, 1.0e9, 0.1],
		["Fishing target ×", "fishing_speedup", 1.0, 10.0, 0.1],
		["Bait slots", "bait_slots", 0, 20, 1],
		["Fish every (min)", "fish_every_minutes", 0.5, 600.0, 0.5],
		["Pond speed ×", "pond_time_scale", 0.1, 3600.0, 0.1],
		["Bite growth ×", "bite_growth", 1.0, 5.0, 0.05],
	]:
		grid.add_child(_cell(spec[0]))
		var spin := _spin(knobs.get(spec[1]), spec[2], spec[3], spec[4])
		spin.value_changed.connect(_on_knob.bind(spec[1]))
		grid.add_child(spin)
		_spins[spec[1]] = spin

	_row([["Generate", _generate], ["Fit prices", _fit], ["Simulate", _simulate]])

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size.x = 500
	add_child(_summary)

	_rank_grid = GridContainer.new()
	_rank_grid.columns = 7
	_rank_grid.add_theme_constant_override("h_separation", 10)
	add_child(_rank_grid)

	_plot = TauPlot.new()
	_plot.custom_minimum_size = Vector2(500, 210)
	add_child(_plot)

	_row([["Apply", _apply], ["Play fresh", _play_fresh], ["Save to table", _save]])

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 500
	add_child(_status)


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
