# economy_sim.gd
# Plays a run of koi-idle in fast-forward with the game's real rules, to see
# how long each rank takes to reach. Used by the Economy tab of the dev panel.
#
# Rules it uses from the game (not copies): FishGenerator.roll_stats /
# roll_growth for new fish, GrowthModel.mass_at for pond growth, the snowball chain
# payout, the rank costs and odds you pass in.
#
# The simulated player is simple, so treat results as a guide:
#   - Climbs at most one rank per shopping trip, saving for the next rank up.
#   - Fills empty toilet slots with the best rank it has unlocked.
#   - When the toilet is full and it can afford to restock a share of it
#     (`restock_fraction`) with the next rank, it flushes and restocks.
#   - Its very first upgrade flushes a toilet full of rank 0s, which stocks
#     the pond with bait for free.
#   - With fishing on, every later upgrade is a "bait flush": after flushing
#     its earners it buys `bait_per_upgrade` rank 0s and flushes them straight
#     away, so the toilet only ever holds its best earners. Every
#     `fish_every_seconds` it fishes out the pond: chains from its heaviest
#     rank 0 up as far as the pond allows, keeping each. Fish younger than
#     `min_grow_seconds` are left in the pond to grow.
# Offline time isn't simulated; this is an active player with the game open.
class_name EconomySim
extends RefCounted

const _GEN := preload("res://scripts/Singletons/FishGenerator.gd")

var ranks: Array = []                 # Array of FishRank
var capacity: int = 20
var start_money: float = 10.0
## Kept fish pay price × catch_return × mass / average starting mass.
var catch_return: float = 1.0
## Pond growth settings (the rank table's Pond growth group). null = the game's.
var growth_table: RankTable = null
var chain_bonus: float = 1.5
## Pond hours per real second in the simulated run. 1.0 = real time.
var pond_time_scale: float = 1.0
var fish_every_seconds: float = 300.0
var restock_fraction: float = 0.25
## With fishing on: rank 0 fish bought and flushed straight into the pond on
## each upgrade (every fishing chain has to start from a rank 0).
var bait_per_upgrade: int = 5
## Fish only count as catchable after this many seconds in the pond, so the
## player lets them grow before cashing them in.
var min_grow_seconds: float = 0.0
var max_seconds: float = 72.0 * 3600.0


## Plays one run. Returns:
##   reached:  PackedFloat64Array, seconds when each rank was first bought (-1 = never)
##   fishing_income / passive_income: coins earned each way
##   end_seconds: when the run stopped
func run(with_fishing: bool, rng_seed: int = 1) -> Dictionary:
	# Separate random streams for the shop and the pond, so a fishing run and a
	# passive run with the same seed buy exactly the same fish: the comparison
	# then shows the effect of fishing, not of luckier rolls.
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var pond_rng := RandomNumberGenerator.new()
	pond_rng.seed = rng_seed + 1_000_003
	var n := ranks.size()
	var reached := PackedFloat64Array()
	reached.resize(n)
	reached.fill(-1.0)

	var t := 0.0
	var money := start_money
	var toilet: Array = []      # {rank, income}
	var toilet_income := 0.0
	var pond: Array = []        # {rank, base, k, r, mid, entered}
	var passive_total := 0.0
	var fishing_total := 0.0
	var next_fish := fish_every_seconds
	var top := -1               # best rank bought so far

	while t < max_seconds:
		# --- shopping ------------------------------------------------------
		# The player climbs one rank at a time: it saves for the next rank up,
		# and fills any empty slots with the best rank it has unlocked.
		var next_rank: int = top + 1
		var can_climb := true   # at most one new rank per shopping trip
		if toilet.size() >= capacity and next_rank < n:
			var restock: int = maxi(1, ceili(capacity * restock_fraction))
			if money >= ranks[next_rank].cost * restock:
				for f in toilet:   # flush: the toilet's fish move to the pond
					pond.append(_pond_fish(f, t, pond_rng))
				toilet.clear()
				toilet_income = 0.0
				# Bait flush: a few cheap rank 0s straight through to the pond
				# (only once rank 0 is no longer what the toilet is full of).
				if with_fishing and top > 0:
					for i in mini(bait_per_upgrade, capacity):
						if money < ranks[0].cost:
							break
						money -= ranks[0].cost
						var bst: Dictionary = _GEN.roll_stats(ranks[0], pond_rng)
						pond.append(_pond_fish({"rank": 0, "mass": bst["mass"]}, t, pond_rng))
		while toilet.size() < capacity:
			var buy: int = -1
			if can_climb and top + 1 < n and money >= ranks[top + 1].cost:
				buy = top + 1
			elif top >= 0 and money >= ranks[top].cost:
				buy = top
			if buy < 0:
				break
			money -= ranks[buy].cost
			var st: Dictionary = _GEN.roll_stats(ranks[buy], rng)
			var f := {"rank": buy, "income": st["income"], "mass": st["mass"]}
			toilet.append(f)
			toilet_income += f["income"]
			if buy > top:
				top = buy
				reached[buy] = t
				can_climb = false
		if reached[n - 1] >= 0.0:
			break

		# --- fishing -------------------------------------------------------
		if with_fishing and fish_every_seconds > 0.0 and t >= next_fish:
			var paid: float = _fish_out(pond, t)
			money += paid
			fishing_total += paid
			next_fish += fish_every_seconds

		# --- time passes ----------------------------------------------------
		# Short steps early, longer later: costs grow roughly exponentially, so
		# a step that's a small fraction of elapsed time keeps results accurate.
		var dt: float = clampf(t * 0.01, 1.0, 120.0)
		if with_fishing and fish_every_seconds > 0.0:
			dt = minf(dt, maxf(next_fish - t, 1.0))
		money += toilet_income * dt
		passive_total += toilet_income * dt
		t += dt

	return {"reached": reached, "passive_income": passive_total,
		"fishing_income": fishing_total, "end_seconds": t}


func _pond_fish(f: Dictionary, t: float, rng: RandomNumberGenerator) -> Dictionary:
	var base: float = f["mass"]
	var g: Dictionary = _GEN.roll_growth(base, ranks[f["rank"]], rng, growth_table)
	return {"rank": f["rank"], "base": base, "k": float(g["carrying_capacity"]),
		"r": g["growth_rate"], "mid": g["mid_point"], "entered": t}


func _mass(f: Dictionary, t: float) -> float:
	var entered: float = f["entered"]
	var hours: float = (t - entered) * pond_time_scale / 3600.0
	return GrowthModel.mass_at(f["base"], f["k"], f["r"], f["mid"], hours)


## Fish the pond empty of chains: start from the heaviest rank 0, climb using the
## heaviest fish of each next rank, keep the chain. Repeat while rank 0s remain.
func _fish_out(pond: Array, t: float) -> float:
	var paid := 0.0
	while true:
		var chain: Array = []
		var want := 0
		while true:
			var pick := -1
			var heaviest := -1.0
			for i in pond.size():
				if pond[i]["rank"] == want and t - float(pond[i]["entered"]) >= min_grow_seconds:
					var m: float = _mass(pond[i], t)
					if m > heaviest:
						heaviest = m
						pick = i
			if pick < 0:
				break
			chain.append(FishingLine.catch_value(ranks[want], heaviest, catch_return))
			pond.remove_at(pick)
			want += 1
		if chain.is_empty():
			break
		var v := 0.0
		for i in chain.size():
			var worth: float = chain[i]
			v = worth if i == 0 else (v + worth) * chain_bonus
		paid += v
	return paid
