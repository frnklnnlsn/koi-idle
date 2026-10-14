# ShopDisplay.gd
extends Control

signal sell(fish_resource_array: Array)

@onready var fish_card_hbox:    HBoxContainer = %fish_card_hbox
@onready var fish_viewport:     SubViewport   = %FishViewport
@onready var display_fish_card: Control       = %display_fish_card

var card_manager:  FishCardManager
var renderer:      FishViewportRenderer
var graph_manager: ShopGraphManager
var label_display: FishLabelDisplay

var selected_fish: fish_conf = null
var rank:           int = 0
var number_of_fish: int = 1


# --- Lifecycle ---

func _ready() -> void:
	_init_managers()
	_connect_signals()
	await _populate(FishHandler.list_of_shop_fish)

func _init_managers() -> void:
	renderer      = FishViewportRenderer.new()
	card_manager  = FishCardManager.new(fish_card_hbox)
	graph_manager = ShopGraphManager.new(%bellcurve, %Growth_curve, %Histogram)
	label_display = FishLabelDisplay.new(%fish_name, %fish_rank, %fish_cost, %fish_income, %"sell value")
	add_child(renderer)
	add_child(card_manager)
	add_child(graph_manager)
	add_child(label_display)

func _connect_signals() -> void:
	FishGenerator.new_fish.connect(_on_new_fish)
	FishHandler.keep_fish.connect(_on_keep)
	sell.connect(_on_sell)
	%Histogram.bar_clicked.connect(_on_bar_clicked)


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


# --- Signal receivers ---

func _on_new_fish(arr: Array) -> void:
	await _populate(arr)


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

func _on_button_pressed() -> void:
	FishGenerator.generate_fish(number_of_fish, rank)

func _on_buy_max_pressed() -> void:
	FishHandler.calculate_total_fish()
	var remainder: int = FishHandler.capacity - FishHandler.total_fish
	var cost: int = Ranks.get_rank(rank).cost
	var can_buy: int = min(remainder, int(PassiveSystems.net_worth / cost))
	if can_buy > 0:
		FishGenerator.generate_fish(can_buy, rank)
