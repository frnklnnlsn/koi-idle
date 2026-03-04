extends Control

signal keep(fish_resource_array: Array)
signal sell(fish_resource_array: Array)

@onready var fish_card_hbox   = %fish_card_hbox
@onready var fish_viewport    = %FishViewport
@onready var display_fish_card = %display_fish_card

var card_manager:   FishCardManager
var renderer:       FishViewportRenderer
var graph_manager:  ShopGraphManager
var label_display:  FishLabelDisplay
var selected_fish:  fish_conf = null
var rank := 0
var number_of_fish := 1

func _ready():
	renderer      = FishViewportRenderer.new()
	card_manager  = FishCardManager.new(fish_card_hbox)
	graph_manager = ShopGraphManager.new(%bellcurve, %Growth_curve, %Histogram)
	label_display = FishLabelDisplay.new(%fish_name, %fish_rank, %fish_cost, %fish_income, %"sell value")

	add_child(renderer)
	add_child(card_manager)
	add_child(graph_manager)
	add_child(label_display)

	FishGenerator.new_fish.connect(_on_new_fish)
	%Histogram.bar_clicked.connect(_on_bar_clicked)
	keep.connect(_on_keep)
	sell.connect(_on_sell)

	await _populate(FishHandler.list_of_shop_fish)

func _populate(fish_array: Array):
	for fish in fish_array:
		var card = card_manager.add_card(fish, renderer)
		card.hovered.connect(_on_card_hovered)
		card.unhovered.connect(_on_card_unhovered)
		card.selected_deselected.connect(_on_card_selected)
		await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	graph_manager.refresh_histogram(card_manager.temp_fish_array)

func _on_new_fish(arr): await _populate(arr)

func _on_card_hovered(fish: fish_conf):
	renderer.place_fish_in_viewport(fish_viewport, fish)
	graph_manager.update_for_fish(fish)
	label_display.show(fish)

func _on_card_unhovered(_fish):
	renderer.clear_viewport(fish_viewport)
	if selected_fish:
		renderer.place_fish_in_viewport(fish_viewport, selected_fish)

func _on_bar_clicked(fish: fish_conf, _i):
	selected_fish = fish
	_on_card_hovered(fish)

func _on_card_selected(fish: fish_conf):
	selected_fish = null if selected_fish == fish else fish

func _on_keep(list: Array):
	if list.is_empty(): return
	card_manager.remove_cards(list)
	_after_transaction(list)
	FishHandler.save_work_fish(list)
	FishHandler.remove_shop_fish(list)
	DisplayManager.display_new_fish.emit(list)

func _on_sell(list: Array):
	if list.is_empty(): return
	card_manager.remove_cards(list)
	_after_transaction(list)
	Economy.for_sell_fish(list)
	FishHandler.remove_shop_fish(list)

func _after_transaction(_list):
	renderer.clear_viewport(fish_viewport)
	selected_fish = null
	graph_manager.refresh_histogram(card_manager.temp_fish_array)
	graph_manager.clear_hover()

### Button Handlers
func _on_keep_pressed():         keep.emit([selected_fish])
func _on_keep_all_pressed():     keep.emit(card_manager.temp_fish_array.duplicate())
func _on_sell_pressed():         sell.emit([selected_fish])
func _on_sell_all_pressed():     sell.emit(card_manager.temp_fish_array.duplicate())
func _on_qnty_line_text_submitted(t): number_of_fish = int(t)
func _on_class_button_item_selected(i): rank = i
func _on_button_pressed():       FishGenerator.generate_fish(number_of_fish, rank)

func _on_buy_max_pressed():
	FishHandler.calculate_total_fish()
	var remainder = FishHandler.capacity - FishHandler.total_fish
	var cost = FishGenerator.fish_cost_array[rank]
	var can_buy = min(remainder, int(Economy.net_worth / cost))
	if can_buy > 0:
		FishGenerator.generate_fish(can_buy, rank)
