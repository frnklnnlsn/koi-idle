# shop_ui.gd
# The shop: a pool of fish cards to screen, and the three charts. Buying,
# keeping and recycling are done with keys through the terminal (see
# CommandLine / VimKeys); the selected fish's details show there too.
extends Control

signal sell(fish_resource_array: Array)
## While a card is dragged: "keep" (above the card row), "trash" (below it)
## or "" (over the row, or not dragging). The right bar's lights follow this.
signal drag_zone_changed(zone: String)
## A message for the terminal from a mouse action (drag, buttons).
signal action_message(text: String)

const KEEP_COLOR := Color(0.3, 0.9, 0.4)
const TRASH_COLOR := Color(1.0, 0.3, 0.3)

@onready var fish_card_hbox:    HBoxContainer = %fish_card_hbox
## Empty space above the cards, sized so the cards' bottom edge sits on the
## screen's horizontal middle line (see _place_cards).
@onready var _top_spacer: Control = %TopSpacer


var card_manager:  FishCardManager
var renderer:      FishViewportRenderer
var graph_manager: ShopGraphManager

var selected_fish: fish_conf = null
var rank:           int = 0

var _last_known_net_worth: float = -1.0
## Keyboard cursor: index of the card it's on (cards counted left to right).
var _cursor := 0
## The fish whose details the terminal shows (hovered, else selected).
var _shown_fish: fish_conf = null
## Card drag: the copy that follows the mouse, and where it is.
var _ghost: Panel
var _ghost_style: StyleBoxFlat
var _drag_card: Control
var _drag_offset := Vector2.ZERO
var _zone := ""
# --- Lifecycle ---

func _ready() -> void:
	resized.connect(_place_cards)
	visibility_changed.connect(_place_cards)
	get_viewport().size_changed.connect(_place_cards)
	_init_managers()
	_connect_signals()
	await _populate(FishHandler.list_of_shop_fish)
	_refresh_affordability()

func _process(_delta: float) -> void:
	if PassiveSystems.net_worth != _last_known_net_worth:
		_last_known_net_worth = PassiveSystems.net_worth
		_refresh_affordability()

func _init_managers() -> void:
	renderer      = FishViewportRenderer.new()
	card_manager  = FishCardManager.new(fish_card_hbox)
	graph_manager = ShopGraphManager.new(%bellcurve, %Growth_curve, %Histogram)
	add_child(renderer)
	add_child(card_manager)
	add_child(graph_manager)

func _connect_signals() -> void:
	FishGenerator.new_fish.connect(_on_new_fish)
	FishHandler.keep_fish.connect(_on_keep)
	sell.connect(_on_sell)
	%Histogram.bar_clicked.connect(_on_bar_clicked)
	# Clicking a dot (scatter) or a curve (growth) selects that fish too.
	for chart in [%bellcurve, %Growth_curve]:
		if chart.has_signal("fish_clicked"):
			chart.fish_clicked.connect(func(f): _on_bar_clicked(f, -1))


# --- Population ---

func _populate(fish_array: Array) -> void:
	for fish in fish_array:
		var card = card_manager.add_card(fish, renderer)
		card.hovered.connect(_on_card_hovered)
		card.unhovered.connect(_on_card_unhovered)
		card.selected_deselected.connect(_on_card_selected)
		card.drag_started.connect(_on_drag_started)
		card.drag_moved.connect(_on_drag_moved)
		card.drag_ended.connect(_on_drag_ended)
		_renumber()
		# Cards arrive one by one; stop if the scene was reloaded meanwhile
		# (Apply / new save), or we'd keep working on a freed shop.
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.1).timeout
		if not is_inside_tree():
			return

	await get_tree().process_frame
	if not is_inside_tree():
		return
	graph_manager.refresh_histogram(card_manager.temp_fish_array)


# --- Card events ---

func _on_card_hovered(fish: fish_conf) -> void:
	# Mouse, keys and chart clicks all move the keyboard cursor to this fish.
	var i := _cards().map(func(c): return c.fish_resource).find(fish)
	if i >= 0 and i != _cursor:
		_cursor = i
		_show_cursor()
	_shown_fish = fish
	graph_manager.update_for_fish(fish)

func _on_card_unhovered(_fish: fish_conf) -> void:
	_shown_fish = selected_fish   # back to the selected fish (or nothing)
	if selected_fish:
		graph_manager.update_for_fish(selected_fish)

func _on_card_selected(fish: fish_conf) -> void:
	selected_fish = null if selected_fish == fish else fish

func _on_bar_clicked(fish: fish_conf, _i) -> void:
	selected_fish = fish
	_on_card_hovered(fish)


# --- Card drag: up to keep, down to trash ------------------------------------

func _on_drag_started(card: Control, mouse: Vector2) -> void:
	_drag_card = card
	if _ghost == null:
		_ghost_style = StyleBoxFlat.new()
		_ghost_style.bg_color = Color(0.1, 0.12, 0.16, 0.85)
		_ghost_style.set_border_width_all(2)
		_ghost_style.set_corner_radius_all(4)
		_ghost = Panel.new()
		_ghost.top_level = true
		_ghost.z_index = 10
		_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost.add_theme_stylebox_override("panel", _ghost_style)
		var pic := TextureRect.new()
		pic.name = "Fish"
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_ghost.add_child(pic)
		add_child(_ghost)
	var rect: Rect2 = card.get_global_rect()
	_ghost.size = rect.size
	_drag_offset = rect.position - mouse
	(_ghost.get_node("Fish") as TextureRect).texture = card.fish_texture()
	_ghost.visible = true
	card.modulate.a = 0.3
	_on_drag_moved(card, mouse)


func _on_drag_moved(_card: Control, mouse: Vector2) -> void:
	if _ghost == null:
		return
	_ghost.global_position = mouse + _drag_offset
	_set_zone(drag_zone(mouse.y))


## Which zone a drag at screen height `y` is in: the card row is neutral,
## above it keeps, below it trashes.
func drag_zone(y: float) -> String:
	var row: Rect2 = fish_card_hbox.get_parent().get_global_rect()
	if y < row.position.y:
		return "keep"
	if y > row.end.y:
		return "trash"
	return ""


func _set_zone(zone: String) -> void:
	_ghost_style.border_color = {"keep": KEEP_COLOR, "trash": TRASH_COLOR}.get(zone, Color(1, 1, 1, 0.4))
	if zone != _zone:
		_zone = zone
		drag_zone_changed.emit(zone)


func _on_drag_ended(card: Control, mouse: Vector2) -> void:
	var zone := drag_zone(mouse.y)
	if _ghost:
		_ghost.visible = false
	_set_zone("")
	_drag_card = null
	if is_instance_valid(card):
		card.modulate.a = 1.0
	var fish: fish_conf = card.fish_resource
	if fish == null:
		return
	if zone == "keep":
		_drop_message(run_command({"cmd": "keep", "fish": [fish]}))
	elif zone == "trash":
		_drop_message(run_command({"cmd": "recycle", "fish": [fish]}))


## Mouse actions report in the terminal like key commands do.
func _drop_message(text: String) -> void:
	action_message.emit(text)


## Buttons on the right bar. Each returns the message for the terminal.
func buy_one() -> String:
	return run_command({"cmd": "buy", "count": 1})


func fill_pool() -> String:
	return run_command({"cmd": "fill"})


# --- Transactions ---

func _on_keep(list: Array) -> void:
	if list.is_empty():
		return
	card_manager.remove_cards(list)
	_after_transaction()
	FishHandler.save_work_fish(list)
	FishHandler.remove_shop_fish(list)
	DisplayManager.display_fish_toilet.emit(list)

func _on_sell(list: Array) -> void:
	if list.is_empty():
		return
	card_manager.remove_cards(list)
	_after_transaction()
	PassiveSystems.for_sell_fish(list)
	FishHandler.remove_shop_fish(list)

func _after_transaction() -> void:
	_renumber.call_deferred()   # after the removed cards are gone
	selected_fish = null
	_shown_fish = null
	graph_manager.refresh_histogram(card_manager.temp_fish_array)
	graph_manager.clear_hover()
	_refresh_affordability()
	_select_cursor.call_deferred()   # the next fish under the cursor


# --- Keep / recycle / buy ---------------------------

## Keeps as many of `list` as the toilet has room for, in order.
## Returns how many were kept.
func _keep(list: Array) -> int:
	var room := FishHandler.toilet_space()
	var kept := list.slice(0, room)
	if not kept.is_empty():
		FishHandler.keep_fish.emit(kept)
	return kept.size()


## Buys up to `n` fish of the current rank, limited by the pool and money.
## Returns how many were bought.
func _buy(n: int) -> int:
	var cost: float = Ranks.get_rank(rank).cost
	var can: int = mini(n, FishHandler.pool_space())
	if cost > 0.0:
		can = mini(can, int(PassiveSystems.net_worth / cost))
	if can > 0:
		FishGenerator.generate_fish(can, rank)
	return can


# --- Keyboard (see CommandLine and VimKeys) -------------------------------------

## The cards in screen order, left to right (ignores ones being removed).
func _cards() -> Array:
	return fish_card_hbox.get_children().filter(
		func(c): return not c.is_queued_for_deletion() and c.get("fish_resource") != null)


## Number the cards 1.. left to right and put the cursor back on one.
func _renumber() -> void:
	if not is_inside_tree():
		return
	var cards := _cards()
	for i in cards.size():
		cards[i].set_number(i + 1)
	_show_cursor()
	if cards.size() <= 2:
		_place_cards()   # first cards in: measure the real card position
	# Nothing picked yet (e.g. the pool just filled): show the cursor's fish.
	if _shown_fish == null and not cards.is_empty():
		_move_cursor_to(_cursor)


func _show_cursor() -> void:
	var cards := _cards()
	_cursor = clampi(_cursor, 0, maxi(cards.size() - 1, 0))
	for i in cards.size():
		cards[i].set_cursor(i == _cursor)


func _move_cursor_to(i: int) -> void:
	var cards := _cards()
	if cards.is_empty():
		return
	_cursor = clampi(i, 0, cards.size() - 1)
	_show_cursor()
	var fish: fish_conf = cards[_cursor].fish_resource
	selected_fish = fish
	_on_card_hovered(fish)


## Runs a keyboard command; returns the message for the command bar.
func run_command(cmd: Dictionary) -> String:
	var cards := _cards()
	match cmd["cmd"]:
		"move":
			_move_cursor_to(_cursor + cmd["by"])
			return ""
		"first":
			_move_cursor_to(0)
			return ""
		"last":
			_move_cursor_to(cards.size() - 1)
			return ""
		"keep", "recycle":
			var picked := _pick(cmd, cards)
			if picked.is_empty():
				return "No fish there"
			var fish: Array = picked.map(func(c): return c.fish_resource)
			if cmd["cmd"] == "keep":
				var kept := _keep(fish)
				if kept == 0:
					return "Toilet full (%d/%d)" % [FishHandler.work_count(), FishHandler.capacity]
				var note := "" if kept == fish.size() else "  (toilet full, %d left)" % (fish.size() - kept)
				return "Kept %d fish%s" % [kept, note]
			var refund := 0.0
			for f in fish:
				refund += PassiveSystems.recycle_refund(f)
			sell.emit(fish)
			return "Recycled %d fish for $%s" % [fish.size(), FishLabelDisplay.num(refund)]
		"buy", "fill":
			var want: int = cmd.get("count", 1) if cmd["cmd"] == "buy" else Ranks.table().shop_pool_size
			var got := _buy(want)
			if got == 0:
				return "Pool full" if FishHandler.pool_space() == 0 else "Can't afford a %s" % Ranks.get_rank(rank).display_name
			return "Bought %d %s fish" % [got, Ranks.get_rank(rank).display_name]
		"rank":
			var to: int = cmd["to"] if cmd.has("to") else rank + cmd["by"]
			to = clampi(to, 0, Ranks.max_rank())
			if PassiveSystems.net_worth < Ranks.get_rank(to).cost:
				return "Can't afford %s yet" % Ranks.get_rank(to).display_name
			rank = to
			_refresh_affordability()
			return "%s selected" % Ranks.get_rank(rank).display_name
	return ""


## The cards a keep / recycle command covers: a count from the cursor, the
## cursor to the end, a numbered range (1-based), or all.
func _pick(cmd: Dictionary, cards: Array) -> Array:
	if cards.is_empty():
		return []
	if cmd.has("fish"):   # specific fish (a dragged card)
		return cards.filter(func(c): return c.fish_resource in cmd["fish"])
	if cmd.get("all", false):
		return cards
	if cmd.has("from"):
		var a := clampi(int(cmd["from"]) - 1, 0, cards.size())
		var b := clampi(int(cmd["to"]), 0, cards.size())
		return cards.slice(a, b)
	if cmd.get("to_end", false):
		return cards.slice(_cursor)
	return cards.slice(_cursor, _cursor + int(cmd.get("count", 1)))


## After cards change, show the fish now under the cursor.
func _select_cursor() -> void:
	var cards := _cards()
	if cards.is_empty() or not is_inside_tree():
		return
	_move_cursor_to(_cursor)


func command_info() -> String:
	return FishLabelDisplay.describe(_shown_fish)


func command_status() -> String:
	var r := Ranks.get_rank(rank)
	return "%s $%s · pool %d/%d · toilet %d/%d" % [r.display_name, FishLabelDisplay.num(r.cost),
		Ranks.table().shop_pool_size - FishHandler.pool_space(), Ranks.table().shop_pool_size,
		FishHandler.work_count(), FishHandler.capacity]


## Grows or shrinks the spacer above the cards so their row ends exactly at
## the middle of the screen; the charts take the space below.
func _place_cards() -> void:
	if not is_visible_in_tree():
		return
	await get_tree().process_frame   # let containers settle first
	if not is_inside_tree():
		return
	# Measure a card that isn't enlarged by the cursor; with no cards yet,
	# where one would sit (they're centred in the row).
	var bottom: float
	var plain := _cards().filter(func(c): return not c.is_cursor)
	if not plain.is_empty():
		# The visible frame ends inside the card's margin.
		bottom = plain[0].global_position.y + plain[0].size.y - plain[0].get_theme_constant("margin_bottom")
	else:
		var row: Control = fish_card_hbox.get_parent()
		bottom = row.global_position.y + (row.size.y + 100.0) / 2.0 - 10.0
	var middle := get_viewport().get_visible_rect().size.y / 2.0
	var h := maxf(_top_spacer.custom_minimum_size.y + middle - bottom, 0.0)
	if absf(h - _top_spacer.custom_minimum_size.y) > 1.0:
		_top_spacer.custom_minimum_size.y = h


## Drops the selected rank to the best one you can afford.
func _refresh_affordability() -> void:
	while rank > 0 and PassiveSystems.net_worth < Ranks.get_rank(rank).cost:
		rank -= 1

func _on_new_fish(arr: Array) -> void:
	if not is_inside_tree():
		return
	await _populate(arr)
	if is_inside_tree():
		_refresh_affordability()
