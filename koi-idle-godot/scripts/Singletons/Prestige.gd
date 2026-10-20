# Prestige.gd (autoload "Prestige")
# Prestige levels. Each level (game_parts/progression/levels.tres) makes some
# numbers harder and ends with a boss:
#
#   1. Hook a fish weighing at least the level's boss_mass: in the fishing
#      panel, Cast turns into "Challenge the boss".
#   2. The boss cut scene plays (boss_cutscene.tscn): the reel-in, the catch
#      and a conversation with the boss.
#   3. advance(): the next level starts. Money and fish are wiped, starting
#      money buys starter_fish rank 0 fish, and every skill point spent comes
#      back (free respec). Points, milestones and the level are kept.
#
# It's a Tuning source: the current level's knob_changes apply to the game's
# numbers alongside skills.
extends Node

## A new level started (after the wipe; the scene reloads right after).
signal level_started(level: int)

const LEVELS_PATH := "res://game_parts/progression/levels.tres"

var table: LevelTable
## Set by advance() so the reloaded main screen can say welcome.
var just_advanced := false


func _ready() -> void:
	table = load(LEVELS_PATH) if ResourceLoader.exists(LEVELS_PATH) else LevelTable.new()
	Tuning.add_source(self)


## The current level number (0 = the first; players see it as level 1).
func level() -> int:
	return SaveManager.load_saved_data().level


## The current level's settings (the last one if the save is past the table).
func current() -> LevelDef:
	return level_def(level())


func level_def(n: int) -> LevelDef:
	if table.levels.is_empty():
		return LevelDef.new()
	return table.levels[clampi(n, 0, table.levels.size() - 1)]


## "Level 2 · The Garden Pond"
func level_name(n: int = -1) -> String:
	if n < 0:
		n = level()
	var t := level_def(n).title
	return "Level %d" % (n + 1) + (" · " + t if t != "" else "")


func has_next() -> bool:
	return level() + 1 < table.levels.size()


## True if `fish` (on the line) is heavy enough to challenge this level's boss.
func boss_ready(fish: fish_conf) -> bool:
	var lvl := current()
	return fish != null and lvl.has_boss() and has_next() and fish.mass >= lvl.boss_mass


## The boss's fish, the same every time (its look comes from look_seed).
func make_boss_fish(boss: BossDef) -> fish_conf:
	seed(boss.look_seed)
	var fish := FishGenerator.make_fish(boss.look_rank)
	randomize()
	if not boss.colors.is_empty():
		fish.colors = boss.colors
		fish.offsets = PackedFloat32Array()
		for i in boss.colors.size():
			fish.offsets.append(float(i) / boss.colors.size())
		fish.fin_color = boss.colors[-1]
	fish.ID = "BOSS_%d_%d" % [level(), boss.look_seed]
	fish.mass = boss.weight_grams
	return fish


## Starts the next level: wipe the run, refund skills, reload the scene.
func advance() -> void:
	if not has_next():
		return
	Upgrades.respec()
	var sd := SaveManager.load_saved_data()
	sd.level += 1
	SaveManager.save_current_data(sd)
	# Priced at the new level (its knob_changes apply from here).
	var money := current().starter_fish * Ranks.price(0)
	just_advanced = true
	SaveManager.wipe_run(money)
	level_started.emit(sd.level)


## Dev: back to a level (no boss needed), wiping the run the same way.
func jump_to(n: int) -> void:
	Upgrades.respec()
	var sd := SaveManager.load_saved_data()
	sd.level = clampi(n, 0, maxi(table.levels.size() - 1, 0))
	SaveManager.save_current_data(sd)
	just_advanced = true
	SaveManager.wipe_run(current().starter_fish * Ranks.price(0))


## Text for "123 g" / "4.2 kg" / "1.3 t".
static func mass_text(grams: float) -> String:
	if grams >= 1_000_000.0:
		return "%s t" % _short(grams / 1_000_000.0)
	if grams >= 1000.0:
		return "%s kg" % _short(grams / 1000.0)
	return "%d g" % roundi(grams)


static func _short(x: float) -> String:
	return str(snappedf(x, 0.1 if x < 100.0 else 1.0)).trim_suffix(".0")


# ------------------------------------------------------------------ Tuning

func tuning_modifier(knob: String) -> Vector2:
	return current().modifier(knob)
