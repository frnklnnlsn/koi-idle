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
# Boss: with a fish on the line at least as heavy as the level's boss_mass
# (Prestige), Cast turns into "Challenge the boss" (click twice to confirm).
# That emits boss_challenged; main_ui plays the boss cut scene.
#
# Layout: no panel box. The controls sit at the bottom middle and only show
# what applies: Cast; after a catch Keep / Release / Leave On; the bite bar
# with a wavy "Waiting" while the line is out; Sell Pond only when nothing in
# the pond can bite. The growth and bar charts start hidden below the screen;
# the Charts tab slides them up on either side of the controls. Fish on the
# line are drawn in the accent colour in them.
extends Control

## For the fishing scene (the bobber view behind the panel).
signal cast_started
signal cast_ended            # the line came back with nothing
signal fish_hooked(fish: fish_conf)
signal line_kept
signal line_released

## "Challenge the boss" confirmed: main_ui plays the cut scene.
signal boss_challenged

@onready var fishing_status: RichTextLabel = %FishingStatus
@onready var fish_stats:     Label         = %FishStats
@onready var chain_label:    Label         = %ChainLabel
@onready var bite_bar:       ProgressBar   = %BiteBar
@onready var fishing_button: Button        = %FishingButton
@onready var keep_button:    Button        = %KeepButton
@onready var release_button: Button        = %ReleaseButton
@onready var leave_on_button: Button       = %LeaveOnButton
@onready var fishing_timer:  Timer         = $FishingTimer
@onready var sell_pond_button: Button      = %SellPondButton
# Charts on either side of the controls (Charts node in fishing_ui.tscn),
# hidden below the screen until the Charts tab is pressed.
@onready var _charts: Control             = %Charts
@onready var _charts_tab: Button          = %ChartsTab
## Seconds the charts take to slide up / down.
@export var charts_slide_seconds := 0.35
var _charts_shown := false
var _charts_tween: Tween
@onready var _growth:  GrowthChart         = %Growth
@onready var _bars:    CollectionChart     = %Bars

## Seconds the Sell Pond confirmation stays armed before it resets.
const SELL_CONFIRM_SECONDS := 4.0

var line := FishingLine.new()
var _waiting     := false   # cast is out, waiting for a bite
var _just_caught := false   # a fresh catch: choose Keep / Release / Leave On
var _sell_armed  := false   # Sell Pond clicked once; next click within SELL_CONFIRM_SECONDS sells
var _sell_arm_id := 0       # so an old timeout can't disarm a newer confirmation
var _instant     := false   # the current cast is a Hungry Bait instant bite
var _boss_armed  := false   # Challenge the boss clicked once
var _boss_arm_id := 0


func _ready() -> void:
	fishing_status.bbcode_enabled = true
	fishing_status.visible_ratio = 1.0
	fishing_timer.one_shot = true
	fishing_timer.timeout.connect(_on_fishing_timer_timeout)
	# The pond changes under us (flushes, growth, catches): keep the hints current.
	FishGrowthManager.growth_updated.connect(_refresh)
	visibility_changed.connect(_on_visibility_changed)
	_charts_tab.pressed.connect(func(): _show_charts(not _charts_shown, true))
	resized.connect(func(): _show_charts(_charts_shown, false))
	_set_idle_status()
	_refresh()


func _on_visibility_changed() -> void:
	if visible and line.is_empty() and not _waiting:
		_set_idle_status()
	if visible:
		_show_charts(false, false)   # charts start tucked away below
	_refresh()


## Slides the charts up into view (or down, leaving just the tab showing).
func _show_charts(shown: bool, animate: bool) -> void:
	_charts_shown = shown
	_charts_tab.text = "Hide charts" if shown else "Charts"
	# Hidden: moved down by the charts' height, so only the tab peeks out.
	var target := 0.0 if shown else size.y * (1.0 - 0.52)
	if _charts_tween and _charts_tween.is_valid():
		_charts_tween.kill()
	if animate:
		_charts_tween = create_tween()
		_charts_tween.tween_property(_charts, "position:y", target, charts_slide_seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_charts.position.y = target
	if shown:
		_refresh()


## The status shown with an empty line: only when something's wrong.
func _set_idle_status() -> void:
	var pond := _pond_fish()
	if pond.is_empty():
		_set_status("The pond is empty. Flush some fish into it first.")
	elif line.candidates(pond).is_empty():
		_set_status("No rank 0 fish in the pond. Sell Pond to cash out.")
	else:
		_set_status("")


func _process(delta: float) -> void:
	line.tick(delta)
	# Pace and streak change every moment.
	if (not line.is_empty() and Tuning.apply(Tuning.SWIFT_LADDER, 0.0) > 0.0) \
			or Tuning.apply(Tuning.HOT_STREAK, 0.0) > 0.0:
		fish_stats.text = _stats_text()
	if not _waiting:
		return
	var r := line.bite_range(_pond_fish())
	var elapsed := fishing_timer.wait_time - fishing_timer.time_left
	bite_bar.max_value = r.y
	bite_bar.value = elapsed


# --- Buttons ------------------------------------------------------------------

func _on_fishing_button_pressed() -> void:
	if not _waiting and Prestige.boss_ready(line.top()):
		_on_boss_pressed()
		return
	if _waiting or _just_caught:
		return
	if not line.can_climb() or line.candidates(_pond_fish()).is_empty():
		_refresh()   # nothing can bite; the timer already shows ∞
		return
	_waiting = true
	# Hungry Bait: right after a Keep, low ranks snap at the bait at once.
	_instant = line.is_instant()
	line.note_cast(_pond_fish(), _instant)
	fishing_timer.wait_time = 0.05 if _instant else line.roll_bite_time(_pond_fish())
	fishing_timer.start()
	cast_started.emit()
	_set_status("[wave amp=20 freq=5 connected=1]Waiting[/wave]")
	_refresh()


func _on_fishing_timer_timeout() -> void:
	_waiting = false
	# Re-check: the pond may have changed while the line was out.
	var pool := line.candidates(_pond_fish())
	if pool.is_empty():
		_set_status("Nothing bit. No rank %d fish left in the pond." % line.target_rank())
		cast_ended.emit()
		_refresh()
		return
	var fish: fish_conf = pool[randi() % pool.size()]
	line.hook(fish, fishing_timer.wait_time, _instant)
	_just_caught = true
	fish_hooked.emit(fish)
	if Prestige.boss_ready(fish):
		_set_status("[shake rate=20 level=8]A %s monster! Something bigger stirs below...[/shake]" % Prestige.mass_text(fish.mass))
	elif _instant:
		_set_status("[shake rate=30 level=6]Snap![/shake]  A hungry rank %d!  %sg" % [fish.rank, _commas(roundi(fish.mass))])
	else:
		_set_status("Caught a rank %d!  %sg" % [fish.rank, _commas(roundi(fish.mass))])
	_refresh()


func _on_keep_pressed() -> void:
	if line.is_empty() or _waiting:
		return
	var bonuses := line.bonuses()
	var paid := line.payout()
	var count := line.chain.size()
	var top: int = line.top().rank
	PassiveSystems.pay_catch(paid)
	DisplayManager.fish_caught.emit(line.chain.duplicate())   # removes them from the pond
	line.clear()
	_just_caught = false
	line_kept.emit()
	# Hungry Bait: the next chain's low ranks bite instantly.
	line.instant_through = FishingLine.hungry_reach(top)
	var text := "Kept %d fish for $%s" % [count, _commas(floori(paid))]
	if not bonuses.is_empty():
		text += "  (" + ", ".join(bonuses.map(func(b): return "×%s %s" % [str(snappedf(b[1], 0.01)), b[0]])) + ")"
	# Welcome Back is used up by this Keep.
	if bonuses.any(func(b): return b[0] == "welcome back"):
		PassiveSystems.welcome_back_pending = false
	if line.instant_through >= 0:
		text += "\nHungry fish: rank%s bite instantly next" % (
			" 0" if line.instant_through == 0 else "s 0–%d" % line.instant_through)
	_set_status(text)
	_refresh()


func _on_release_pressed() -> void:
	if line.is_empty() or _waiting:
		return
	line.clear()
	_just_caught = false
	line_released.emit()
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


## First click arms the challenge (it ends the level); the second starts it.
func _on_boss_pressed() -> void:
	if not _boss_armed:
		_boss_armed = true
		_boss_arm_id += 1
		var my_id := _boss_arm_id
		_refresh()
		await get_tree().create_timer(SELL_CONFIRM_SECONDS).timeout
		if is_inside_tree() and _boss_armed and _boss_arm_id == my_id:
			_boss_armed = false
			_refresh()
		return
	_boss_armed = false
	_refresh()
	boss_challenged.emit()


# --- Display ------------------------------------------------------------------

func _refresh() -> void:
	if not is_node_ready():
		return
	var pond := _pond_fish()
	var can_cast := line.can_climb() and not line.candidates(pond).is_empty()
	var boss := not _waiting and Prestige.boss_ready(line.top())
	if not boss:
		_boss_armed = false

	# What's on the line and what it's worth (only with something on it).
	chain_label.visible = not line.is_empty()
	if not line.is_empty():
		var parts := line.chain.map(func(f): return "R%d %sg" % [f.rank, _commas(roundi(f.mass))])
		chain_label.text = "On line: " + " → ".join(parts)
	fish_stats.text = _stats_text()
	fish_stats.visible = fish_stats.text != ""

	# The bite bar only while the line is out.
	bite_bar.visible = _waiting
	if not _waiting:
		bite_bar.value = 0.0

	# Buttons: Cast with nothing to decide; Keep / Release / Leave On right
	# after a catch; Cast + Keep + Release with fish left on as bait.
	fishing_button.visible = not _waiting and not _just_caught and (can_cast or boss)
	if boss:
		fishing_button.text = "Confirm: end %s? Money and fish are wiped" % Prestige.level_name() if _boss_armed \
			else "Challenge the boss"
	else:
		fishing_button.text = "Cast"
	keep_button.visible = not _waiting and not line.is_empty()
	release_button.visible = not _waiting and not line.is_empty()
	leave_on_button.visible = _just_caught

	# Sell Pond: the fail-safe, only when nothing in the pond can bite.
	sell_pond_button.visible = not _waiting and line.is_empty() and not pond.is_empty() \
		and line.candidates(pond).is_empty()
	if not sell_pond_button.visible:
		_sell_armed = false
	elif _sell_armed:
		sell_pond_button.text = "Confirm: sell %d fish for $%s?" % [pond.size(), _commas(floori(line.pond_sale_value(pond)))]
	else:
		sell_pond_button.text = "Sell Pond ($%s)" % _commas(floori(line.pond_sale_value(pond)))
	_update_charts(pond)


## What Keep would pay now, the Swift Ladder pace and the Hot Streak when
## they're owned.
func _stats_text() -> String:
	var streak := ""
	var pond := _pond_fish()
	if Tuning.apply(Tuning.HOT_STREAK, 0.0) > 0.0 and line.streak_bonus(pond) > 0.0:
		streak = "Streak %d  (+%d%%)" % [line.streak, roundi(line.streak_bonus(pond) * 100.0)]
		if line.is_empty():
			streak += "  %.0fs left" % maxf(line.streak_time_left(pond), 0.0)
	if line.is_empty():
		return streak
	var text := "Keep now: $%s" % _commas(floori(line.payout()))
	if line.chain.size() > 1:
		text += "   (separately $%s)" % _commas(floori(line.value_if_separate()))
	else:
		text += "   (shop price $%s)" % _commas(floori(Ranks.price(line.top().rank)))
	if Tuning.apply(Tuning.SWIFT_LADDER, 0.0) > 0.0:
		text += "\nPace %.1fs / par %.1fs  → ×%s" % [line.elapsed(), line.par_seconds,
			str(snappedf(line.speed_multiplier(), 0.01))]
	if streak != "":
		text += "\n" + streak
	return text


## Every pond fish; the line's fish highlighted, with a "Now" dot on their
## growth curves.
func _update_charts(pond: Array) -> void:
	if not is_visible_in_tree():
		return
	for chart in [_growth, _bars]:
		chart.set_fish_collection(pond)
		chart.set_caught(line.chain, [])
	# A dot on each line fish's growth curve at its current growth.
	_growth.set_now_fish(line.chain)


func _set_status(bbcode: String) -> void:
	fishing_status.text = "[center]" + bbcode
	fishing_status.visible = bbcode != ""


func _pond_fish() -> Array:
	var save_data := SaveManager.load_saved_data()
	return save_data.list_of_retired_fish if save_data else []


## 1.5 -> "1.5s", 75 -> "1m 15s".
static func _secs(s: float) -> String:
	if s >= 60.0:
		return "%dm %02ds" % [int(s) / 60, int(s) % 60]
	return (str(int(s)) if is_equal_approx(s, roundf(s)) else "%.1f" % s) + "s"


## 1234567 -> "1,234,567"
## Money and grams, in the Settings "Big numbers" style.
static func _commas(n: int) -> String:
	return NumberFormat.whole(n)