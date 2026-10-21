# dev_tools.gd
# Developer panel, toggled with F1. Autoload; only exists in debug builds
# (see DevSettings.dev_panel_enabled()), so players never see it.
#
# Everything here goes through the game's real systems (the same functions the
# shop, flush and offline catch-up use), so what you set up here behaves
# exactly like it would in play.
extends Node

const TOGGLE_KEY := KEY_P

var _layer: CanvasLayer
var _panel: PanelContainer
var _info: Label
var _log: Label
var _rank: SpinBox
var _count: SpinBox
var _reset_button: Button
var _reset_armed := false
var _info_timer := 0.0


func _ready() -> void:
	if not DevSettings.dev_panel_enabled():
		set_process(false)
		set_process_input(false)
		return
	_build_ui()
	_panel.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == TOGGLE_KEY:
		_panel.visible = not _panel.visible
		if _panel.visible:
			_rank.max_value = Ranks.max_rank()   # follow the rank table
			_update_info()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_info_timer += delta
	if _info_timer >= 0.25:
		_info_timer = 0.0
		_update_info()


# --- Actions ------------------------------------------------------------------

func _add_money(amount: float) -> void:
	PassiveSystems.net_worth += amount
	PassiveSystems._flush_to_save()
	_say("Added $%s" % _commas(amount))


func _add_points(n: int) -> void:
	Progression.refund(n)
	_say("Added %d skill point%s (%d to spend)" % [n, "" if n == 1 else "s", Progression.points()])


func _respec() -> void:
	var back := Upgrades.respec()
	_say("Skills reset, %d point%s back" % [back, "" if back == 1 else "s"])


func _boss_scene() -> void:
	var ui = get_tree().get_first_node_in_group("main_ui")
	if ui and Prestige.current().has_boss():
		_panel.visible = false
		ui._play_boss()
	else:
		_say("No boss on this level")


func _next_level() -> void:
	if Prestige.has_next():
		Prestige.jump_to(Prestige.level() + 1)
	else:
		_say("Already on the last level")


func _level_one() -> void:
	Prestige.jump_to(0)


func _zero_money() -> void:
	PassiveSystems.net_worth = 0.0
	PassiveSystems._flush_to_save()
	_say("Money set to $0")


## Fish of the chosen rank straight into the shop, as if bought, but free.
func _spawn_shop() -> void:
	var rank := int(_rank.value)
	var n := int(_count.value)
	FishGenerator.generate_fish(n, rank)                      # shop + save + charge...
	PassiveSystems.net_worth += Ranks.get_rank(rank).cost * n   # ...refunded
	PassiveSystems._flush_to_save()
	_say("Added %d rank %d fish to the shop (free)" % [n, rank])


## Fish into the toilet: they start earning income right away, like kept fish.
func _spawn_toilet() -> void:
	var list := _make(int(_rank.value), int(_count.value))
	FishHandler.save_work_fish(list)
	for f in list:
		PassiveSystems.add_fish(f)
	PassiveSystems._flush_to_save()
	DisplayManager.display_fish_toilet.emit(list)
	_say("Added %d rank %d fish to the toilet" % [list.size(), int(_rank.value)])


## Fish straight into the pond at their base mass, growth clock at 0.
func _spawn_pond() -> void:
	var list := _make(int(_rank.value), int(_count.value))
	var data := SaveManager.load_saved_data()
	for f in list:
		FishGrowthManager.enter_pond(f)
		data.list_of_retired_fish.append(f)
	SaveManager.save_current_data(data)
	DisplayManager.display_fish_pond.emit(data.list_of_retired_fish)
	FishGrowthManager.growth_updated.emit()
	_say("Added %d rank %d fish to the pond" % [list.size(), int(_rank.value)])


## Pretend the game was closed for `seconds`, then run the real offline
## catch-up (income and pond growth), exactly as on a real relaunch.
func _away(seconds: float) -> void:
	PassiveSystems._flush_to_save()            # current money into the save first
	SaveManager.backdate_timestamp(seconds)
	var grown := FishGrowthManager.apply_offline_growth()
	PassiveSystems.reload()                    # recalculates income + offline earnings
	SaveManager.save_timestamp()
	PassiveSystems._flush_to_save()
	var paid: float = PassiveSystems.last_offline["coins"]
	_say("Away %s: earned $%s, pond grew %s pond-hours" % [
		_duration(seconds), _commas(paid),
		_commas(grown * FishGrowthManager.TIME_SCALE / 3600.0)])


func _save_now() -> void:
	PassiveSystems._flush_to_save()
	_say("Saved to %s" % ProjectSettings.globalize_path(SaveManager.SAVE_PATH))


func _open_save_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path("user://"))


func _reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Click again to WIPE the save"
		await get_tree().create_timer(3.0).timeout
		_reset_armed = false
		_reset_button.text = "Reset save"
		return
	_reset_armed = false
	_reset_button.text = "Reset save"
	SaveManager.reset_save_data()
	_say("Save wiped. Fresh start with $%s" % _commas(SaveManager.STARTING_COINS))


func _make(rank: int, n: int) -> Array:
	var list := []
	for i in n:
		list.append(FishGenerator.make_fish(rank))
	return list


# --- Display ------------------------------------------------------------------

func _update_info() -> void:
	var data := SaveManager.load_saved_data()
	var ranks := {}
	for f in data.list_of_retired_fish:
		ranks[f.rank] = ranks.get(f.rank, 0) + 1
	var pond_ranks := []
	for r in range(Ranks.count()):
		pond_ranks.append("R%d:%d" % [r, ranks.get(r, 0)])
	_info.text = "\n".join([
		"Money  $%s   Income  $%s/s" % [FishLabelDisplay.num(PassiveSystems.net_worth), FishLabelDisplay.num(PassiveSystems.income_rate())],
		"Shop %d   Toilet %d   Pond %d  (%s)" % [data.list_of_shop_fish.size(), data.list_of_work_fish.size(), data.list_of_retired_fish.size(), " ".join(pond_ranks)],
		"Pond time: 1 real second = %s pond hour%s" % [_commas(FishGrowthManager.TIME_SCALE / 3600.0), "" if FishGrowthManager.TIME_SCALE == 3600.0 else "s"],
		"Reset on launch: %s" % ("ON" if DevSettings.RESET_SAVE_ON_LAUNCH else "off"),
	])


func _say(text: String) -> void:
	_log.text = text
	print("[Dev] ", text)
	_update_info()


static func _commas(x: float) -> String:
	var n := floori(x)
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(-3)
	return ("-" if n < 0 else "") + digits + out


static func _duration(seconds: float) -> String:
	if seconds >= 3600.0:
		return "%sh" % str(snappedf(seconds / 3600.0, 0.1)).trim_suffix(".0")
	return "%dmin" % roundi(seconds / 60.0)


# --- UI construction ------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.position.y = 40
	_layer.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	_panel.add_child(margin)

	var outer := VBoxContainer.new()
	margin.add_child(outer)

	var title := Label.new()
	title.text = "Developer tools  (F1)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)

	# Tabs keep each tool on its own page so the panel doesn't get cluttered.
	var tabs := TabContainer.new()
	outer.add_child(tabs)

	var box := VBoxContainer.new()
	box.name = "Game"
	box.custom_minimum_size.x = 330
	tabs.add_child(box)
	# The Economy tab is tall; scroll it so it fits a 720p window.
	var econ_scroll := ScrollContainer.new()
	econ_scroll.name = "Economy"
	econ_scroll.custom_minimum_size = Vector2(545, 560)
	econ_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(econ_scroll)
	econ_scroll.add_child(preload("res://scripts/dev/economy_tab.gd").new())

	_info = Label.new()
	box.add_child(_info)

	_section(box, "Money")
	_row(box, [["+$100", _add_money.bind(100.0)], ["+$10k", _add_money.bind(10_000.0)],
		["+$1M", _add_money.bind(1_000_000.0)], ["$0", _zero_money]])

	_section(box, "Fish")
	var pick := HBoxContainer.new()
	box.add_child(pick)
	pick.add_child(_label("Rank"))
	_rank = SpinBox.new()
	_rank.max_value = Ranks.max_rank()
	pick.add_child(_rank)
	pick.add_child(_label("  Count"))
	_count = SpinBox.new()
	_count.min_value = 1
	_count.max_value = 50
	_count.value = 3
	pick.add_child(_count)
	_row(box, [["→ Shop (free)", _spawn_shop], ["→ Toilet", _spawn_toilet], ["→ Pond", _spawn_pond]])

	_section(box, "Skill points")
	_row(box, [["+1 point", _add_points.bind(1)], ["+5 points", _add_points.bind(5)], ["Respec (refund all)", _respec]])

	_section(box, "Prestige")
	_row(box, [["Boss scene", _boss_scene], ["Next level", _next_level], ["Level 1", _level_one]])

	_section(box, "Time away (real offline catch-up)")
	_row(box, [["10 min", _away.bind(600.0)], ["1 hour", _away.bind(3600.0)], ["8 hours", _away.bind(8.0 * 3600.0)]])

	_section(box, "Save")
	_reset_button = Button.new()
	_reset_button.text = "Reset save"
	_reset_button.pressed.connect(_reset)
	var save_row := _row(box, [["Save now", _save_now], ["Open folder", _open_save_folder]])
	save_row.add_child(_reset_button)
	_reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_log = Label.new()
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.custom_minimum_size.x = 330
	box.add_child(_log)


func _section(box: Control, text: String) -> void:
	box.add_child(HSeparator.new())
	box.add_child(_label(text))


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _row(box: Control, buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	box.add_child(row)
	for spec in buttons:
		var b := Button.new()
		b.text = spec[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		row.add_child(b)
	return row
