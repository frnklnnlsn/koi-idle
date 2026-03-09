# PassiveSystems.gd
extends Node

var income: float = 0.0
var net_worth: float = 0.0

const SAVE_INTERVAL: float = 5.0
var _save_timer: float = 0.0
var fishing_multiplier: float = 10.0
# --- Debug ---
var debug_time_scale: float = 3600.0  # 1.0 = real time | 60.0 = 1 second = 1 minute | 3600.0 = 1 second = 1 hour

func _ready() -> void:
	_load_from_save()
	FishGenerator.new_fish.connect(for_new_fish)
	FishHandler.keep_fish.connect(_on_keep_fish)
	DisplayManager.flush_fish.connect(reset_income)
	DisplayManager.fish_caught.connect(_on_fish_caught)  # add this

func _on_fish_caught(fish_list: Array) -> void:
	for fish in fish_list:
		net_worth += fish.mass * fishing_multiplier
	_flush_to_save()

func _load_from_save() -> void:
	var save_data: SaveData = SaveManager.load_saved_data()
	if save_data:
		income = save_data.income
		net_worth = save_data.net_worth
		_recalculate_income_from_save(save_data)
		_apply_offline_earnings()

func reload() -> void:
	income = 0.0
	net_worth = 0.0
	_load_from_save()

func _recalculate_income_from_save(save_data: SaveData) -> void:
	income = 0.0
	for fish in save_data.list_of_work_fish:
		if fish is fish_conf:
			income += fish.income

func _apply_offline_earnings() -> void:
	var last_timestamp := SaveManager.load_timestamp()

	if last_timestamp < 1577836800.0:
		return

	var now := Time.get_unix_time_from_system()
	var seconds_away := now - last_timestamp
	seconds_away = clampf(seconds_away, 0.0, 8.0 * 60.0 * 60.0)  # min 0, max 8 hours

	if seconds_away <= 0.0:
		return

	var earnings := income * seconds_away
	net_worth += earnings

func _process(delta: float) -> void:
	net_worth += income * delta

	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL:
		_save_timer = 0.0
		_flush_to_save()
		_apply_growth_to_retired_fish(SAVE_INTERVAL)

func _apply_growth_to_retired_fish(extra_seconds: float) -> void:
	var save_data: SaveData = SaveManager.load_saved_data()
	if not save_data or save_data.list_of_retired_fish.is_empty():
		return

	for fish in save_data.list_of_retired_fish:
		if fish is fish_conf:
			fish.age += extra_seconds
			fish.mass = logistic_mass(fish, fish.age)

	SaveManager.save_current_data(save_data)

func _flush_to_save() -> void:
	var save_data: SaveData = SaveManager.load_saved_data()
	save_data.income = income
	save_data.net_worth = net_worth
	SaveManager.save_current_data(save_data)
	SaveManager.save_timestamp()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			_flush_to_save()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED:
			_flush_to_save()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_flush_to_save()

# --- Fish purchased from shop ---
func for_new_fish(fish_res_array: Array) -> void:
	if fish_res_array.is_empty():
		return
	for fish in fish_res_array:
		net_worth -= fish.cost
	_debug_print()

# --- Fish moved from shop to pond ---
func _on_keep_fish(fish_list: Array) -> void:
	if fish_list.is_empty():
		return
	for fish in fish_list:
		add_fish(fish)
	_debug_print()

func add_fish(fish_res: fish_conf) -> void:
	if fish_res:
		income += fish_res.income

# --- Fish sold ---
func for_sell_fish(fish_res_array: Array) -> void:
	if fish_res_array.is_empty():
		return
	for fish in fish_res_array:
		remove_fish(fish)
	_debug_print()

func remove_fish(fish_res: fish_conf) -> void:
	if fish_res:
		#income -= fish_res.income
		net_worth += fish_res.cost

func _debug_print() -> void:
	#print("income: %.2f | net_worth: %.2f" % [income, net_worth])
	pass


func reset_income() -> void:
	income = 0.0
	_flush_to_save()
	_debug_print()

func logistic_mass(fish: fish_conf, elapsed_seconds: float) -> float:
	var K: float = float(fish.carrying_capacity)
	var r: float = fish.growth_rate
	var elapsed_hours: float = (elapsed_seconds * debug_time_scale) / 3600.0
	var x: float = fish.x_start + elapsed_hours - fish.mid_point
	return K / (1.0 + exp(-r * x))


# Call this when moving fish into list_of_retired_fish
func retire_fish(fish: fish_conf) -> void:
	var K: float = float(fish.carrying_capacity)
	# solve logistic formula for x given current mass
	var clamped_mass: float = clampf(fish.mass, 0.001, K - 0.001)
	fish.x_start = -log((K / clamped_mass) - 1.0) / fish.growth_rate
	# mid_point becomes x_start + how many virtual hours until peak growth
	fish.mid_point = fish.x_start + randf_range(6.0, 48.0)
	fish.age = 0.0
	#print("retiring fish [%s] | mass: %.3f | x_start recalc: %.4f | mid_point: %.4f" % [
		#fish.ID, fish.mass, fish.x_start, fish.mid_point
	#])
