# economy_sim.gd
# Plays a run of koi-idle in fast-forward with the game's real rules, to see
# how long each rank takes to reach. Used by the Economy tab of the dev panel.
#
# Rules it uses from the game (not copies): FishGenerator.roll_raw / roll_growth
# for new fish, GrowthModel.mass_at for pond growth, the snowball chain
# payout, the rank costs and odds you pass in.
#
# The simulated player is simple, so treat results as a guide:
#   - Climbs one rank at a time, saving for the next rank up.
#   - Fills empty toilet slots with the best rank it has unlocked.
#   - When the toilet is full and it can afford to restock a share of it
#     (`restock_fraction`) with the next rank, it flushes and restocks.
#   - With fishing on, it keeps `bait_slots` rank 0 fish in the toilet so they
#     reach the pond on each flush (every chain must start from a rank 0), and
#     every `fish_every_seconds` it fishes out the pond:
#     chains from its heaviest rank 0 up as far as the pond allows, keeping each.
# Offline time isn't simulated; this is an active player with the game open.
class_name EconomySim
extends RefCounted

const _GEN := preload("res://scripts/Singletons/FishGenerator.gd")

var ranks: Array = []                 # Array of FishRank
var capacity: int = 20
var start_money: float = 10.0
var coins_per_gram: float = 10.0
var chain_bonus: float = 1.5
## Pond hours per real second in the simulated run. 1.0 = real time.
var pond_time_scale: float = 1.0
var fish_every_seconds: float = 300.0
var restock_fraction: float = 0.25
## With fishing on: rank 0 fish the player keeps in the toilet as future bait.
## They earn little but get flushed into the pond, where every fishing chain
## has to start from a rank 0. Each one costs an income slot.
var bait_slots: int = 2
var max_seconds: float = 72.0 * 3600.0


## Plays one run. Returns:
##   reached:  PackedFloat64Array, seconds when each rank was first bought (-1 = never)
##   fishing_income / passive_income: coins earned each way
##   end_seconds: when the run stopped
func run(with_fishing: bool, rng_seed: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
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
		if toilet.size() >= capacity and next_rank < n:
			var restock: int = maxi(1, ceili(capacity * restock_fraction))
			if money >= ranks[next_rank].cost * restock:
				for f in toilet:   # flush: the toilet's fish move to the pond
					pond.append(_pond_fish(f, t, rng))
				toilet.clear()
				toilet_income = 0.0
		if with_fishing and bait_slots > 0 and top > 0:
			var bait := 0
			for f in toilet:
				if f["rank"] == 0:
					bait += 1
			while bait < bait_slots and toilet.size() < capacity and money >= ranks[0].cost:
				money -= ranks[0].cost
				var braw: int = _GEN.roll_raw(ranks[0], rng)
				var bf := {"rank": 0, "income": braw * _GEN.FISH_BASE_INCOME, "raw": braw}
				toilet.append(bf)
				toilet_income += bf["income"]
				bait += 1
		while toilet.size() < capacity:
			var buy: int = -1
			if top + 1 < n and money >= ranks[top + 1].cost:
				buy = top + 1
			elif top >= 0 and money >= ranks[top].cost:
				buy = top
			if buy < 0:
				break
			money -= ranks[buy].cost
			var raw: int = _GEN.roll_raw(ranks[buy], rng)
			var f := {"rank": buy, "income": raw * _GEN.FISH_BASE_INCOME, "raw": raw}
			toilet.append(f)
			toilet_income += f["income"]
			if buy > top:
				top = buy
				reached[buy] = t
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
	var base: float = f["raw"] * _GEN.FISH_BASE_MASS
	var g: Dictionary = _GEN.roll_growth(base, rng)
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
				if pond[i]["rank"] == want:
					var m: float = _mass(pond[i], t)
					if m > heaviest:
						heaviest = m
						pick = i
			if pick < 0:
				break
			chain.append(heaviest)
			pond.remove_at(pick)
			want += 1
		if chain.is_empty():
			break
		var v := 0.0
		for i in chain.size():
			var worth: float = chain[i] * coins_per_gram
			v = worth if i == 0 else (v + worth) * chain_bonus
		paid += v
	return paid
