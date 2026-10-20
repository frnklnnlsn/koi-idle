extends Control
@onready var net_worth_label: Label               = %net_worth
## Skill points to spend, next to the money (hidden until the first point).
@onready var skill_points_label: Label = %SkillPoints
## Prestige level, left of the money (tooltip: the level's boss goal).
@onready var level_label: Label = %LevelLabel
## Close-up window of one fish: click a fish in the toilet or pond.
@onready var fish_peek: FishPeek = %FishPeek
## How close (in water pixels, beyond the fish's own width) a click must be
## to a fish to pick it.
@export var peek_pick_margin := 4.0
## The boss cut scene, played over everything when the boss is challenged.
@export var boss_cutscene: PackedScene = preload("res://game_parts/boss/boss_cutscene.tscn")
@onready var list_ui:         Control             = %ListUI
@onready var shop_ui:         Control             = %ShopUI
@onready var toilet:          SubViewportContainer = %ToiletViewportContainer
@onready var pond:            SubViewportContainer = %PondViewportContainer
@onready var fishing_ui: Control = %FishingUI
## The skill tree screen (skill_tree_ui.tscn). T or the Skills button.
@onready var skill_tree_ui: SkillTreeUI = %SkillTreeUI

## The keyboard terminal along the bottom (command_line.tscn); style and size
## it in the editor. The rest of the UI is kept above it.
@onready var command_line: CommandLine = %CommandLine
@onready var _main_column: VBoxContainer = $VBoxContainer
## Icon buttons down the left edge (menu, flush, view, list, shop, fishing).
@onready var _sidebar: Control = %Sidebar
## Shop-only bar down the right edge: buy buttons, keep / trash lights.
@onready var _shop_bar: Control = %ShopBar
@onready var _keep_light: TextureRect = %KeepLight
@onready var _trash_light: TextureRect = %TrashLight
## Rank picker on the ShopBar (rank_meter.gd): bars sized in its Inspector.
@onready var _rank_meter: RankMeter = %RankMeter
## See-through layer over the toilet / pond while the shop or fishing is open. Change how
## dark it is with its Color (the alpha slider) in the Inspector.
@onready var _shop_backdrop: ColorRect = %ShopBackdrop

## Light colours (keep / trash / off) come from UIPalette.

## Panels that Esc closes (shop, list, fishing). For a new pop-up, add its
## node to this group (Node tab > Groups in the editor, or add_to_group).
const ESC_CLOSES := "esc_closes"

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Keys drive the shop while it's open.
	# Keys drive the skill tree while it's open.
	command_line.target_provider = func():
		if shop_ui.visible:
			return shop_ui
		return skill_tree_ui if skill_tree_ui.visible else null
	command_line.resized.connect(_fit_above_terminal)
	# S opens / closes the shop from anywhere.
	command_line.global_keys["s"] = _on_shop_pressed
	# V switches between the toilet and the pond, like the View button.
	command_line.global_keys["v"] = _on_view_pressed
	# T opens / closes the skill tree.
	command_line.global_keys["t"] = _on_skills_pressed
	# Esc closes the open panel (once nothing is half typed in the terminal).
	command_line.global_keys["escape"] = close_open_panel
	# The close-up window first, so Esc closes it before the panel under it.
	fish_peek.add_to_group(ESC_CLOSES)
	for panel in [shop_ui, list_ui, fishing_ui, skill_tree_ui]:
		panel.add_to_group(ESC_CLOSES)
	shop_ui.visibility_changed.connect(_on_shop_visibility)
	fishing_ui.visibility_changed.connect(_update_backdrop)
	shop_ui.drag_zone_changed.connect(_on_drag_zone)
	shop_ui.action_message.connect(command_line.say)
	skill_tree_ui.action_message.connect(command_line.say)
	# Clicking the points counter opens the tree.
	skill_points_label.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_skills_pressed())
	Progression.points_changed.connect(_show_skill_points.unbind(1))
	Progression.milestone_earned.connect(_on_milestone_earned)
	Progression.credited_existing.connect(_on_credited_existing)
	_show_skill_points()
	_show_level()
	fishing_ui.boss_challenged.connect(_play_boss)
	add_to_group("main_ui")
	if Prestige.just_advanced:
		Prestige.just_advanced = false
		command_line.say.call_deferred("Welcome to %s. Money and fish start over; your %d skill points are back to spend (t)" % [Prestige.level_name(), Progression.points()])
	_rank_meter.rank_clicked.connect(_on_rank_clicked)
	_rank_meter.rank_scrolled.connect(_on_rank_scrolled)
	_on_shop_visibility()
	_on_drag_zone("")
	_fit_above_terminal()


## Stop the main column and the sidebar at the top of the terminal, however
## tall it is, and start the main column right of the sidebar.
func _fit_above_terminal() -> void:
	var h := command_line.size.y if command_line.visible else 0.0
	_main_column.offset_bottom = -h
	_sidebar.offset_bottom = -h
	_shop_bar.offset_bottom = -h
	_main_column.offset_left = _sidebar.size.x
	_main_column.offset_right = -_shop_bar.size.x if _shop_bar.visible else 0.0


## Hides the first visible panel in the ESC_CLOSES group. Returns true if
## one was closed.
func close_open_panel() -> bool:
	for panel in get_tree().get_nodes_in_group(ESC_CLOSES):
		if panel is CanvasItem and panel.is_visible_in_tree():
			panel.visible = false
			return true
	return false


func _on_shop_visibility() -> void:
	_shop_bar.visible = shop_ui.visible
	_update_backdrop()
	_fit_above_terminal()


func _update_backdrop() -> void:
	_shop_backdrop.visible = shop_ui.visible or fishing_ui.visible


func _on_drag_zone(zone: String) -> void:
	var pal := UIPalette.get_palette()
	var off := Color(pal.text_dim, 0.6)
	_keep_light.modulate = pal.keep.lightened(0.15) if zone == "keep" else off
	_trash_light.modulate = pal.trash.lightened(0.2) if zone == "trash" else off


# ── Fish close-up ─────────────────────────────────────────────────────────────
## A left click on the water (nothing else under the mouse) picks the fish
## nearest the click and opens the close-up on it. Clicks on buttons, panels
## and the close-up itself go to them as usual.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered not in [null, self, _main_column, toilet, pond]:
		return
	var container: SubViewportContainer = pond if pond.visible else toilet
	var fish := fish_at(container, event.position)
	if fish:
		fish_peek.open(fish, container.get_child(0), event.position)
		get_viewport().set_input_as_handled()


## The fish under `screen_pos` in `container`'s water, or null.
func fish_at(container: SubViewportContainer, screen_pos: Vector2) -> Node2D:
	var vp: SubViewport = container.get_child(0)
	var local := (screen_pos - container.global_position) / maxf(container.stretch_shrink, 1)
	var world := vp.get_canvas_transform().affine_inverse() * local
	var best: Node2D = null
	var best_d := INF
	for f in get_tree().get_nodes_in_group("fish"):
		if f.get_viewport() != vp or not f.is_visible_in_tree():
			continue
		var body: Line2D = f.get_node_or_null("%FishBody")
		if body == null:
			continue
		var reach := body.width * 0.5 + peek_pick_margin
		for i in body.get_point_count():
			var d := world.distance_to(body.to_global(body.get_point_position(i)))
			if d < reach and d < best_d:
				best_d = d
				best = f
	return best


# ── Prestige ──────────────────────────────────────────────────────────────────
func _show_level() -> void:
	var lvl := Prestige.current()
	level_label.text = "Level %d" % (Prestige.level() + 1)
	var goal := "Boss: hook a fish of %s, then challenge it from the fishing panel." % Prestige.mass_text(lvl.boss_mass) \
		if lvl.has_boss() and Prestige.has_next() else "No boss here yet."
	level_label.tooltip_text = "%s\n%s" % [Prestige.level_name(), goal]


## Plays the boss cut scene; its last button starts the next level.
func _play_boss() -> void:
	var boss := Prestige.current().boss
	if boss == null:
		return
	for p in [shop_ui, list_ui, fishing_ui, skill_tree_ui]:
		p.visible = false
	var scene: BossCutscene = boss_cutscene.instantiate()
	scene.setup(boss)
	scene.finished.connect(Prestige.advance)
	add_child(scene)


# ── Skill points ──────────────────────────────────────────────────────────────
func _show_skill_points() -> void:
	var p := Progression.points()
	skill_points_label.visible = Progression.points_earned() > 0
	skill_points_label.text = "%d skill point%s" % [p, "" if p == 1 else "s"]


func _on_milestone_earned(title: String, points: int, first_ever: bool) -> void:
	_show_skill_points()
	# Deferred: the purchase's own "Bought ..." message comes right after this
	# and would hide it.
	if first_ever:
		command_line.say.call_deferred("Skill point earned: %s! The first fish of each rank earns one. Spend them in the skill tree (t)" % title.to_lower())
	else:
		command_line.say.call_deferred("+%d skill point%s: %s  (%d to spend)" % [points, "" if points == 1 else "s", title.to_lower(), Progression.points()])


func _on_credited_existing(count: int, points: int) -> void:
	_show_skill_points()
	command_line.say("Skill points: +%d for the %d rank%s you already own. Each new rank's first fish earns another" % [points, count, "" if count == 1 else "s"])


func _on_buy_pressed() -> void:
	command_line.say(shop_ui.buy_one())


func _on_buy_max_pressed() -> void:
	command_line.say(shop_ui.fill_pool())


func _process(_delta: float) -> void:
	# Whole coins only, rounded down so it never shows money you don't have yet.
	net_worth_label.text = "$ " + _with_commas(floori(PassiveSystems.net_worth))
	if _shop_bar.visible:
		_update_rank_meter()


## Shows the shop's rank and how many ranks your money covers.
func _update_rank_meter() -> void:
	var n := 0
	while n < Ranks.count() and PassiveSystems.net_worth >= Ranks.price(n):
		n += 1
	_rank_meter.affordable = n
	_rank_meter.rank = shop_ui.rank


## Clicking or scrolling the meter runs the same rank command as :rank N / [ ].
func _on_rank_clicked(r: int) -> void:
	command_line.say(shop_ui.run_command({"cmd": "rank", "to": r}))
	_update_rank_meter()


func _on_rank_scrolled(step: int) -> void:
	command_line.say(shop_ui.run_command({"cmd": "rank", "by": step}))
	_update_rank_meter()
## 1234567 -> "1,234,567"
static func _with_commas(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(-3)
	return ("-" if n < 0 else "") + digits + out

# ── Button handlers ───────────────────────────────────────────────────────────
## Opens `panel` (closing the other panels), or closes it if it's open.
## Returns true if it's now open.
func _toggle_panel(panel: Control) -> bool:
	var open := not panel.visible
	for p in [shop_ui, list_ui, fishing_ui, skill_tree_ui]:
		if p != panel and open:
			p.visible = false
	panel.visible = open
	return open


func _on_shop_pressed() -> void:
	_toggle_panel(shop_ui)
func _on_skills_pressed() -> void:
	_toggle_panel(skill_tree_ui)
func _on_list_pressed() -> void:
	if _toggle_panel(list_ui):
		list_ui.refresh(pond.visible)
func _on_view_pressed() -> void:
	fish_peek.close()
	pond.visible   = not pond.visible
	toilet.visible = not toilet.visible
	if list_ui.visible:
		list_ui.refresh(pond.visible)
func _on_flush_pressed() -> void:
	var save_data = SaveManager.load_saved_data()

	var retired_ids = save_data.list_of_retired_fish.map(func(f): return f.ID)

	for fish in save_data.list_of_work_fish:
		if fish.ID not in retired_ids:
			FishGrowthManager.enter_pond(fish)   # base mass frozen, growth clock starts
			save_data.list_of_retired_fish.append(fish)

	save_data.list_of_work_fish.clear()
	SaveManager.save_current_data(save_data)
	DisplayManager.flush_fish.emit()
	DisplayManager.display_fish_pond.emit(save_data.list_of_retired_fish)


func _on_go_fishing_pressed() -> void:
	_toggle_panel(fishing_ui)
