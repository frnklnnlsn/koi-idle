extends Control
@onready var net_worth_label: Label               = %net_worth
## Skill points to spend, next to the money (hidden until the first point).
@onready var skill_points_label: Label = %SkillPoints
## Prestige level, left of the money (tooltip: the level's boss goal).
@onready var level_label: Label = %LevelLabel
## Toilet fill in the top bar: a bar filling up with "Toilet 3/20" over it.
@onready var toilet_meter: ProgressBar = %ToiletMeter
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
## The settings window (menu button, or Esc with nothing open).
@onready var settings_menu: SettingsMenu = %SettingsMenu
## "Ask before big sells": yes / no box for recycling many fish at once.
var _confirm_dialog: ConfirmationDialog
var _confirm_action: Callable

## Short messages fading in at the bottom ("Kept 3 fish"): toast.tscn.
@onready var toast: Toast = %Toast
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
## The bobber view shown behind the fishing panel (in place of the pond).
@onready var fishing_scene: FishingScene = %FishingScene
var _fishing_open := false
## Flush cut scene's circle wipe.
@onready var iris: IrisTransition = %IrisTransition
## Flush cut scene: how close it shows the pipe (pond camera zoom), how far
## below the pipe it centres (pond pixels), and how long before pulling back.
@export var flush_pipe_zoom := 2.5
@export var flush_pipe_focus_offset := 50.0
@export var flush_pipe_hold := 2.5

## Light colours (keep / trash / off) come from UIPalette.

## Panels that Esc closes (shop, list, fishing). For a new pop-up, add its
## node to this group (Node tab > Groups in the editor, or add_to_group).
const ESC_CLOSES := "esc_closes"

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Shortcut keys: see _unhandled_key_input.
	# The close-up window first, so Esc closes it before the panel under it.
	fish_peek.add_to_group(ESC_CLOSES)
	for panel in [shop_ui, list_ui, fishing_ui, skill_tree_ui]:
		panel.add_to_group(ESC_CLOSES)
	shop_ui.visibility_changed.connect(_on_shop_visibility)
	fishing_ui.visibility_changed.connect(_update_backdrop)
	shop_ui.drag_zone_changed.connect(_on_drag_zone)
	# (Buying / keeping / recycling show no message; the toilet count in the
	# top bar shows the result.)
	shop_ui.confirm_requested.connect(_ask)
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Are you sure?"
	_confirm_dialog.confirmed.connect(func():
		if _confirm_action.is_valid():
			_confirm_action.call())
	add_child(_confirm_dialog)
	skill_tree_ui.action_message.connect(toast.say)
	# Clicking the points counter opens the tree.
	skill_points_label.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_skills_pressed())
	Progression.points_changed.connect(_show_skill_points.unbind(1))
	Progression.milestone_earned.connect(_on_milestone_earned)
	Progression.credited_existing.connect(_on_credited_existing)
	_show_skill_points()
	_show_level()
	_style_toilet_meter()
	fishing_ui.boss_challenged.connect(_play_boss)
	# The bobber view follows the fishing panel.
	fishing_ui.cast_started.connect(fishing_scene.cast)
	fishing_ui.cast_ended.connect(fishing_scene.reel_in)
	fishing_ui.fish_hooked.connect(fishing_scene.hook)
	fishing_ui.line_kept.connect(fishing_scene.keep)
	fishing_ui.line_released.connect(fishing_scene.release)
	_update_backdrop()
	# The fish the close-up is following never sinks out of view.
	if Pond.current:
		Pond.current.keep_visible = func(n): return fish_peek.is_showing(n)
	add_to_group("main_ui")
	if Prestige.just_advanced:
		Prestige.just_advanced = false
		toast.say.call_deferred("Welcome to %s. Money and fish start over; your %d skill points are back to spend (t)" % [Prestige.level_name(), Progression.points()])
	_rank_meter.rank_clicked.connect(_on_rank_clicked)
	_rank_meter.rank_scrolled.connect(_on_rank_scrolled)
	_on_shop_visibility()
	_on_drag_zone("")
	_fit_layout()


## Shortcut keys, anywhere: S shop, V toilet / pond, T skill tree, Esc closes
## the open panel (or opens the settings with nothing open).
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.is_command_or_control_pressed() or k.alt_pressed:
		return
	match k.keycode:
		KEY_S: _on_shop_pressed()
		KEY_V: _on_view_pressed()
		KEY_T: _on_skills_pressed()
		KEY_ESCAPE:
			if not close_open_panel():
				settings_menu.open()
		_: return
	get_viewport().set_input_as_handled()


## The main column fills the space between the sidebars.
func _fit_layout() -> void:
	_main_column.offset_bottom = 0.0
	_sidebar.offset_bottom = 0.0
	_shop_bar.offset_bottom = 0.0
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
	_fit_layout()


func _update_backdrop() -> void:
	_shop_backdrop.visible = shop_ui.visible
	# Fishing: zoom into the pond, then the bobber scene fades in (and back).
	var cam := pond.get_node_or_null("PondViewport/Camera2D") as Camera2D
	if fishing_ui.visible and not _fishing_open:
		_fishing_open = true
		fishing_scene.open.call_deferred(cam)   # after the view has switched to the pond
	elif not fishing_ui.visible and _fishing_open:
		_fishing_open = false
		fishing_scene.close(cam)


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
	if fishing_ui.visible:
		return   # the bobber view covers the water
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
## "Toilet 3/20" over a bar that fills as the toilet fills (top bar).
func _update_toilet_meter() -> void:
	var n := FishHandler.work_count()
	var cap := FishHandler.capacity
	toilet_meter.max_value = maxi(cap, 1)
	toilet_meter.value = n
	(toilet_meter.get_node("Text") as Label).text = "Toilet %d/%d" % [n, cap]


## The toilet meter's look, from the UI palette: like the other top bar
## boxes, with the fill in the accent colour (keep green when full).
func _style_toilet_meter() -> void:
	var pal := UIPalette.get_palette()
	var bg := StyleBoxFlat.new()
	bg.bg_color = pal.inset
	bg.border_color = pal.accent
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(pal.accent, 0.35)
	fill.set_corner_radius_all(4)
	toilet_meter.add_theme_stylebox_override("background", bg)
	toilet_meter.add_theme_stylebox_override("fill", fill)


func _show_skill_points() -> void:
	var p := Progression.points()
	skill_points_label.visible = Progression.points_earned() > 0
	skill_points_label.text = "%d skill point%s" % [p, "" if p == 1 else "s"]


func _on_milestone_earned(title: String, points: int, first_ever: bool) -> void:
	_show_skill_points()
	# Deferred: the purchase's own "Bought ..." message comes right after this
	# and would hide it.
	if first_ever:
		toast.say.call_deferred("Skill point earned: %s! The first fish of each rank earns one. Spend them in the skill tree (t)" % title.to_lower())
	else:
		toast.say.call_deferred("+%d skill point%s: %s  (%d to spend)" % [points, "" if points == 1 else "s", title.to_lower(), Progression.points()])


func _on_credited_existing(count: int, points: int) -> void:
	_show_skill_points()
	toast.say("Skill points: +%d for the %d rank%s you already own. Each new rank's first fish earns another" % [points, count, "" if count == 1 else "s"])


func _on_buy_pressed() -> void:
	shop_ui.buy_one()


func _on_buy_max_pressed() -> void:
	shop_ui.fill_pool()


func _process(_delta: float) -> void:
	# Whole coins only, rounded down so it never shows money you don't have yet.
	net_worth_label.text = "$ " + NumberFormat.whole(floorf(PassiveSystems.net_worth))
	_update_toilet_meter()
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
	toast.say(shop_ui.run_command({"cmd": "rank", "to": r}))
	_update_rank_meter()


func _on_rank_scrolled(step: int) -> void:
	toast.say(shop_ui.run_command({"cmd": "rank", "by": step}))
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


func _on_menu_pressed() -> void:
	settings_menu.toggle()


## Yes / no box; `on_yes` runs if confirmed.
func _ask(question: String, yes_text: String, on_yes: Callable) -> void:
	_confirm_action = on_yes
	_confirm_dialog.dialog_text = question
	_confirm_dialog.ok_button_text = yes_text
	_confirm_dialog.popup_centered()


## Shows the pond (true) or the toilet (false).
func _show_view(show_pond: bool) -> void:
	if pond.visible == show_pond:
		return
	fish_peek.close()
	pond.visible   = show_pond
	toilet.visible = not show_pond
	if list_ui.visible:
		list_ui.refresh(pond.visible)


func _on_shop_pressed() -> void:
	# The shop sends fish to the toilet, so it opens over the toilet.
	if _toggle_panel(shop_ui):
		_show_view(false)
func _on_skills_pressed() -> void:
	_toggle_panel(skill_tree_ui)
func _on_list_pressed() -> void:
	if _toggle_panel(list_ui):
		list_ui.refresh(pond.visible)
func _on_view_pressed() -> void:
	# Switching view closes whatever panel is open, so you see the water.
	for p in [shop_ui, list_ui, fishing_ui, skill_tree_ui]:
		p.visible = false
	_show_view(not pond.visible)
func _on_flush_pressed() -> void:
	var save_data = SaveManager.load_saved_data()

	var retired_ids = save_data.list_of_retired_fish.map(func(f): return f.ID)

	for fish in save_data.list_of_work_fish:
		if fish.ID not in retired_ids:
			FishGrowthManager.enter_pond(fish)   # base mass frozen, growth clock starts
			save_data.list_of_retired_fish.append(fish)

	# Cut scene: follow the fish down the drain into the pond (Settings).
	var cutscene: bool = Settings.get_value("gameplay/flush_cutscene") and toilet.visible \
		and not save_data.list_of_work_fish.is_empty() and not DisplayManager.is_flushing
	save_data.list_of_work_fish.clear()
	SaveManager.save_current_data(save_data)
	DisplayManager.flush_fish.emit()
	DisplayManager.display_fish_pond.emit(save_data.list_of_retired_fish)
	if cutscene:
		_play_flush_cutscene()


## The screen closes in on the drain as the fish swirl down it, then opens
## on the pond's pipe as they swim out.
func _play_flush_cutscene() -> void:
	var tv := toilet.get_node("ToiletViewport")
	# Wait for the fish to reach the drain (give up after a few seconds).
	var state := {"drained": false}
	var mark := func(): state["drained"] = true
	tv.flush_draining.connect(mark, CONNECT_ONE_SHOT)
	var waited := 0.0
	while not state["drained"] and waited < 6.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not state["drained"]:
		if tv.flush_draining.is_connected(mark):
			tv.flush_draining.disconnect(mark)
		return
	await iris.close_on(tv.drain_screen_position(), 0.6)
	if DisplayManager.is_flushing:
		await DisplayManager.flush_completed
	# Clear the view and switch to the pond while the screen is dark.
	for p in [shop_ui, list_ui, fishing_ui, skill_tree_ui]:
		p.visible = false
	_show_view(true)
	# Open once the first fish is on its way out of the pipe (at most 2s).
	var before := Pond.current.fish_container_pond.get_child_count() if Pond.current else 0
	var t := 0.0
	while t < 2.0 and Pond.current and Pond.current.fish_container_pond.get_child_count() <= before:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().create_timer(0.35).timeout
	if Pond.current == null:
		await iris.open_on(size * 0.5, 0.8)
		return
	# Open on a close-up of the pipe as the fish swim out, then pull back.
	var cam := Pond.current.get_node_or_null("Camera2D") as Camera2D
	var home := {"position": cam.position, "zoom": cam.zoom} if cam else {}
	if cam:
		cam.position = Pond.current.pipe_origin + Vector2(0, flush_pipe_focus_offset)
		cam.zoom = Vector2.ONE * flush_pipe_zoom
		await get_tree().process_frame
	await iris.open_on(Pond.current.pipe_screen_position(), 0.8)
	if cam:
		await get_tree().create_timer(flush_pipe_hold).timeout
		var back := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		back.tween_property(cam, "position", home["position"], 1.2)
		back.tween_property(cam, "zoom", home["zoom"], 1.2)


func _on_go_fishing_pressed() -> void:
	# Fishing happens in the pond, so it opens over the pond.
	if _toggle_panel(fishing_ui):
		_show_view(true)
