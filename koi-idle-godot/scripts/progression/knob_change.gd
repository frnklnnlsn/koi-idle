# knob_change.gd
# One change to a Tuning knob, used by levels (LevelDef.knob_changes):
#     number = (number + extra) × multiplier
class_name KnobChange
extends Resource

## The number to change (see tuning.gd for where each is used).
@export_enum("price", "income", "bite_time", "growth_speed", "growth_potential",
	"toilet_capacity", "shop_pool", "recycle_fee", "pond_sale_rate",
	"offline_income", "offline_growth", "start_mass", "chain_bonus",
	"swift_ladder", "instant_bites", "old_timers", "full_house",
	"empty_bowl", "hot_streak", "patient_angler", "welcome_back") var knob: String = "bite_time"
## Added (slots, seconds...; for shares like recycle_fee, 0.05 = 5%).
@export var extra: float = 0.0
## Multiplied (1 = no change, 1.25 = 25% more).
@export var multiplier: float = 1.0
