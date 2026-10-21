# PassiveSystems.gd
extends Node

var income: float = 0.0
var net_worth: float = 0.0

const SAVE_INTERVAL: float = 5.0
var _save_timer: float = 0.0
# What caught fish pay is set by the rank table (catch_return) and each
# rank's price; see FishingLine.catch_value.
## What the last offline catch-up paid: {"seconds": away time used, "coins": earned}.
## Read it to show a "while you were away" message.
var last_offline := {"seconds": 0.0, "coins": 0.0}

func _ready() -> void:
	_load_from_save()
	FishGenerator.new_fish.connect(for_new_fish)
	FishHandler.keep_fish.connect(_on_keep_fish)
	DisplayManager.flush_fish.connect(reset_income)

## Pay out a kept catch. The fishing UI works out the amount (a whole chain is
## paid once, with its bonus), so catching fish no longer pays per fish here.
func pay_catch(amount: float) -> void:
	net_worth += amount
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

## Money the toilet earned over `seconds` away. With Old Timers each fish's
## seniority keeps growing meanwhile (worked out exactly: a straight rise to
## the cap, then flat), and every fish's work clock moves on by `seconds`.
func _offline_income(seconds: float) -> float:
	var work: Array = SaveManager.load_saved_data().list_of_work_fish
	var r := seniority_rate()
	if r <= 0.0:
		for f in work:
			if f is fish_conf:
				f.work_time += seconds
		return income_rate() * seconds
	var m := Tuning.modifier(Tuning.INCOME)
	var cap := Ranks.table().old_timer_cap
	var total := 0.0
	for f in work:
		if not (f is fish_conf):
			continue
		# Bonus-seconds: the integral of min(r × hours, cap) over the absence.
		var h0: float = f.work_time / 3600.0
		var to_cap := maxf((cap / r - h0) * 3600.0, 0.0)   # seconds until capped
		var rising := minf(seconds, to_cap)
		var bonus_s := r * (h0 * rising + rising * rising / 7200.0) + cap * maxf(seconds - to_cap, 0.0)
		total += (f.income + m.x) * (seconds + bonus_s)
		f.work_time += seconds
	return maxf(total * m.y, 0.0) * full_house_bonus()


func _apply_offline_earnings() -> void:
	last_offline = {"seconds": 0.0, "coins": 0.0}
	var last_timestamp := SaveManager.load_timestamp()
	if last_timestamp < 1577836800.0:
		return

	var now := Time.get_unix_time_from_system()
	# No cap: every second away pays (Tuning offline_income on top).
	var seconds_away := maxf(now - last_timestamp, 0.0)
	if seconds_away <= 0.0:
		return

	var earnings := _offline_income(seconds_away) * maxf(Tuning.apply(Tuning.OFFLINE_INCOME, 1.0), 0.0)
	net_worth += earnings
	last_offline = {"seconds": seconds_away, "coins": earnings}

## Money per second right now: the toilet fish's own incomes, through Tuning
## (income skills and the level apply to every fish, old and new; a knob
## "extra" counts once per fish), with each fish's seniority (Old Timers) and
## the full-toilet bonus (Full House).
func income_rate() -> float:
	var m := Tuning.modifier(Tuning.INCOME)
	var work: Array = SaveManager.load_saved_data().list_of_work_fish
	var total := 0.0
	if seniority_rate() <= 0.0:
		total = income + m.x * work.size()
	else:
		for f in work:
			if f is fish_conf:
				total += (f.income + m.x) * seniority(f)
	return maxf(total * m.y, 0.0) * full_house_bonus()


## One fish's income with skills, the level and its seniority applied (for
## labels). The full-toilet bonus is the whole toilet's, so it's not in here.
static func fish_income(fish: fish_conf) -> float:
	return maxf(Tuning.apply(Tuning.INCOME, fish.income), 0.0) * seniority(fish)


## Old Timers: income bonus per hour worked (0 = not owned).
static func seniority_rate() -> float:
	return maxf(Tuning.apply(Tuning.OLD_TIMERS, 0.0), 0.0)


## Income multiplier from how long `fish` has worked in the toilet:
## 1 + rate × hours, up to 1 + the rank table's old_timer_cap.
static func seniority(fish: fish_conf) -> float:
	var r := seniority_rate()
	if r <= 0.0 or fish == null:
		return 1.0
	return 1.0 + minf(r * fish.work_time / 3600.0, Ranks.table().old_timer_cap)


## Full House: income multiplier while the toilet is full (1 otherwise).
func full_house_bonus() -> float:
	var bonus := Tuning.apply(Tuning.FULL_HOUSE, 0.0)
	if bonus <= 0.0 or FishHandler.work_count() < FishHandler.capacity:
		return 1.0
	return 1.0 + bonus


func _process(delta: float) -> void:
	net_worth += income_rate() * delta
	# Seniority (Old Timers): every toilet fish's working clock runs.
	for f in SaveManager.load_saved_data().list_of_work_fish:
		if f is fish_conf:
			f.work_time += delta

	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL:
		_save_timer = 0.0
		_flush_to_save()

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

## Recycling a shop fish refunds its price minus the rank table's recycle fee.
func remove_fish(fish_res: fish_conf) -> void:
	if fish_res:
		net_worth += recycle_refund(fish_res)


static func recycle_refund(fish_res: fish_conf) -> float:
	return fish_res.cost * (1.0 - Tuning.apply_share(Tuning.RECYCLE_FEE, Ranks.table().recycle_fee))

func _debug_print() -> void:
	#print("income: %.2f | net_worth: %.2f" % [income, net_worth])
	pass


func reset_income() -> void:
	income = 0.0
	_flush_to_save()
	_debug_print()
