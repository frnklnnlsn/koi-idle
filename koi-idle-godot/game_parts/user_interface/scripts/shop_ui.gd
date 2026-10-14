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
		FishHandler.keep_fish.emit([selected_fish])

func _on_keep_all_pressed() -> void:
	FishHandler.keep_fish.emit(card_manager.temp_fish_array.duplicate())

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
	if PassiveSystems.net_worth < Ranks.get_rank(rank).cost:
		return
	FishGenerator.generate_fish(number_of_fish, rank)

func _on_buy_max_pressed() -> void:
	FishHandler.calculate_total_fish()
	var remainder: int = FishHandler.capacity - FishHandler.total_fish
	var cost: int = Ranks.get_rank(rank).cost
	var can_buy: int = min(remainder, int(PassiveSystems.net_worth / cost))
	if can_buy > 0:
		FishGenerator.generate_fish(can_buy, rank)


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
