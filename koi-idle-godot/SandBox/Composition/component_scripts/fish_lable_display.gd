class_name FishLabelDisplay
extends Node
## Fills the shop's fish info panel (name / rank / cost / income / sell value)
## with the real numbers for a fish.

var fish_name_label
var fish_rank_label
var fish_cost_label
var fish_income_label
var sell_value_label

func _init(name_l, rank_l, cost_l, income_l, sell_l):
	fish_name_label   = name_l
	fish_rank_label   = rank_l
	fish_cost_label   = cost_l
	fish_income_label = income_l
	sell_value_label  = sell_l


func show(fish: fish_conf) -> void:
	if fish == null:
		clear()
		return
	var rank_def := Ranks.get_rank(fish.rank)
	var potential := fish.carrying_capacity / maxf(fish.y_start if fish.y_start > 0.0 else fish.mass, 0.0001)
	var details := "%sg %s · grows ×%s %s" % [num(fish.mass), _rarity(fish.mass_z),
		num(potential), _rarity(fish.size_z)]
	if is_fast_grower(fish):
		details += ", fast grower!"
	_put(fish_name_label, str(fish.ID))
	_put(fish_rank_label, "%s   (%s)" % [rank_def.display_name, details])
	_put(fish_cost_label, "$" + num(fish.cost))
	var payback := ""
	if fish.income > 0.0:
		payback = "   pays for itself in %s" % duration(fish.cost / fish.income)
	_put(fish_income_label, "$%s/s %s%s" % [num(fish.income), _rarity(fish.income_z), payback])
	# Selling in the shop refunds the price; keeping it, then catching it from
	# the pond later, pays its catch value (more once it has grown).
	var catch_now := FishingLine.catch_value_of(fish)
	_put(sell_value_label, "$%s recycle   (catch $%s)" % [num(PassiveSystems.recycle_refund(fish)), num(catch_now)])


## Everything about a fish as a few lines of text (the terminal's info area).
static func describe(fish: fish_conf) -> String:
	if fish == null:
		return ""
	var rank_def := Ranks.get_rank(fish.rank)
	var start := fish.y_start if fish.y_start > 0.0 else fish.mass
	var potential := fish.carrying_capacity / maxf(start, 0.0001)
	var cz := FishStats.fish_combined_z(fish)
	var lines := [
		"%s · %s (%s overall)%s" % [rank_def.display_name, FishStats.tier_name(cz),
			FishStats.rarity_label(cz), "   · fast grower!" if is_fast_grower(fish) else ""],
		"Income  $%s/s %s   pays for itself in %s" % [num(fish.income), _rarity(fish.income_z),
			duration(fish.cost / fish.income) if fish.income > 0.0 else "—"],
		"Size    %sg %s   grows ×%s %s" % [num(fish.mass), _rarity(fish.mass_z), num(potential), _rarity(fish.size_z)],
		"Price   $%s   recycle $%s   catch now $%s" % [num(fish.cost), num(PassiveSystems.recycle_refund(fish)),
			num(FishingLine.catch_value_of(fish))],
	]
	return "\n".join(lines)


## Empty panel, shown before any fish is hovered.
func clear() -> void:
	for l in [fish_name_label, fish_rank_label, fish_cost_label, fish_income_label, sell_value_label]:
		_put(l, "—")


func _put(label, text: String) -> void:
	if label:
		label.text = text


## "(top 3%)", with a star for the top 1%.
static func _rarity(z: float) -> String:
	var label := FishStats.rarity_label(z)
	return ("★ " + label) if FishStats.is_top(z) else "(%s)" % label


## Fast growers peak before normal fish can (see the rank table's Pond growth).
static func is_fast_grower(fish: fish_conf) -> bool:
	return fish.mid_point < Ranks.table().normal_peak_hours.x


## Readable number: decimals for small values, commas for big ones.
## 0.123 -> "0.12", 12.5 -> "12.5", 1234567 -> "1,234,567"
static func num(x: float) -> String:
	var a := absf(x)
	if a < 10.0:
		return _trim("%.2f" % x)
	if a < 1000.0:
		return _trim("%.1f" % x)
	var digits := str(absi(floori(a)))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(-3)
	return ("-" if x < 0 else "") + digits + out


static func duration(seconds: float) -> String:
	if seconds < 90.0:
		return "%ds" % roundi(seconds)
	if seconds < 5400.0:
		return "%.1f min" % (seconds / 60.0)
	return "%.1f h" % (seconds / 3600.0)


static func _trim(s: String) -> String:
	if s.contains("."):
		s = s.rstrip("0").trim_suffix(".")
	return s
