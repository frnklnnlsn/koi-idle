# shop_ui.gd
extends Control

signal sell(fish_resource_array: Array)

@onready var fish_card_hbox:    HBoxContainer = %fish_card_hbox
@onready var fish_viewport:     SubViewport   = %FishViewport
@onready var display_fish_card: Control       = %display_fish_card
@onready var rank_cost_label: Label = %RankCostLabel
@onready var class_button: OptionButton = %class_button
@onready var buy_button: Button = %BuyButton
@onready var buy_max_button: Button = %BuyMaxButton


var card_manager:  FishCardManager
var renderer:      FishViewportRenderer
var graph_manager: ShopGraphManager
var label_display: FishLabelDisplay

var selected_fish: fish_conf = null
var rank:           int = 0
var number_of_fish: int = 1

var _last_known_net_worth: float = -1.0
## Keyboard cursor: index of the card it's on (cards counted left to right).
var _cursor := 0
# --- Lifecycle ---

func _ready() -> void:
	_fill_rank_dropdown()
	_init_managers()
	_connect_signals()
	await _populate(FishHandler.list_of_shop_fish)
	_refresh_affordability()

func _process(_delta: float) -> void:
	if PassiveSystems.net_worth != _last_known_net_worth:
		_last_known_net_worth = PassiveSystems.net_worth
		_refresh_affordability()

## One dropdown entry per rank in the rank table, so new ranks show up here.
## Each entry shows the rank's price, e.g. "Rank 1  ($100)".
func _fill_rank_dropdown() -> void:
	class_button.clear()
	for i in Ranks.count():
		var r := Ranks.get_rank(i)
		class_button.add_item("%s  ($%s)" % [r.display_name, FishLabelDisplay.num(r.cost)], i)


func _init_managers() -> void:
	renderer      = FishViewportRenderer.new()
	card_manager  = FishCardManager.new(fish_card_hbox)
	graph_manager = ShopGraphManager.new(%bellcurve, %Growth_curve, %Histogram)
	label_display = FishLabelDisplay.new(%fish_name, %fish_rank, %fish_cost, %fish_income, %"sell value")
	add_child(renderer)
	add_child(card_manager)
	add_child(graph_manager)
	add_child(label_display)
	label_display.clear()

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
	renderer.place_fish_in_viewport(fish_viewport, fish)
	graph_manager.update_for_fish(fish)
	label_display.show(fish)

func _on_card_unhovered(_fish: fish_conf) -> void:
	renderer.clear_viewport(fish_viewport)
	if selected_fish:
		renderer.place_fish_in_viewport(fish_viewport, selected_fish)
	label_display.show(selected_fish)   # back to the selected fish (or blank)
	if selected_fish:
		graph_manager.update_for_fish(selected_fish)

func _on_card_selected(fish: fish_conf) -> void:
	selected_fish = null if selected_fish == fish else fish

func _on_bar_clicked(fish: fish_conf, _i) -> void:
	selected_fish = fish
	_on_card_hovered(fish)


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
	renderer.clear_viewport(fish_viewport)
	selected_fish = null
	graph_manager.refresh_histogram(card_manager.temp_fish_array)
	graph_manager.clear_hover()
	label_display.clear()
	_refresh_affordability()


# --- Signal receivers --


# --- Button handlers ---

func _on_keep_pressed() -> void:
	if selected_fish:
		_keep([selected_fish])

func _on_keep_all_pressed() -> void:
	_keep(_cards().map(func(c): return c.fish_resource))

func _on_sell_pressed() -> void:
	if selected_fish:
		sell.emit([selected_fish])

func _on_sell_all_pressed() -> void:
	sell.emit(card_manager.temp_fish_array.duplicate())

func _on_qnty_line_text_submitted(t: String) -> void:
	number_of_fish = int(t)

func _on_class_button_item_selected(i: int) -> void:
	rank = i
	rank_cost_label.text = "Cost: %d" % Ranks.get_rank(rank).cost

func _on_button_pressed() -> void:
	_buy(number_of_fish)

func _on_buy_max_pressed() -> void:
	_buy(Ranks.table().shop_pool_size)


# --- Keep / recycle / buy, shared by buttons and keys ---------------------------

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
	if cmd.get("all", false):
		return cards
	if cmd.has("from"):
		var a := clampi(int(cmd["from"]) - 1, 0, cards.size())
		var b := clampi(int(cmd["to"]), 0, cards.size())
		return cards.slice(a, b)
	if cmd.get("to_end", false):
		return cards.slice(_cursor)
	return cards.slice(_cursor, _cursor + int(cmd.get("count", 1)))


func command_status() -> String:
	var r := Ranks.get_rank(rank)
	return "%s $%s · pool %d/%d · toilet %d/%d" % [r.display_name, FishLabelDisplay.num(r.cost),
		Ranks.table().shop_pool_size - FishHandler.pool_space(), Ranks.table().shop_pool_size,
		FishHandler.work_count(), FishHandler.capacity]


func _refresh_affordability() -> void:
	# Clamp rank down to highest affordable
	while rank > 0 and PassiveSystems.net_worth < Ranks.get_rank(rank).cost:
		rank -= 1
	class_button.selected = rank
	rank_cost_label.text = "Cost: %d" % Ranks.get_rank(rank).cost

	# Disable ranks you can't afford
	for i in Ranks.count():
		var cost: int = Ranks.get_rank(i).cost
		class_button.set_item_disabled(i, PassiveSystems.net_worth < cost)

	# Block buying if you can't afford current rank
	var can_afford: bool = PassiveSystems.net_worth >= Ranks.get_rank(rank).cost
	buy_button.disabled = not can_afford
	buy_max_button.disabled = not can_afford

func _on_new_fish(arr: Array) -> void:
	if not is_inside_tree():
		return
	await _populate(arr)
	if is_inside_tree():
		_refresh_affordability()
