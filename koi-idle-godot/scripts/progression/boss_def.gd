# boss_def.gd
# The boss at the end of a level (LevelDef.boss): its look, the cut scene's
# lines and the conversation after the catch.
class_name BossDef
extends Resource

@export var boss_name: String = "The Boss"
## Shown under the name when it's caught, in grams (the cut scene writes it as
## kg / t). Just for show.
@export var weight_grams: float = 1000.0

@export_group("Look")
## Rank whose look (body shape) it borrows.
@export_range(0, 6) var look_rank: int = 0
## Same number = same pattern and colours every time. Try others for new looks.
@export var look_seed: int = 1
## Colours to use instead of random ones (empty = from look_seed).
@export var colors: PackedColorArray = PackedColorArray()
## Size in the cut scene, × a normal fish on screen.
@export_range(1.0, 40.0, 0.5) var size: float = 14.0

@export_group("Words")
## Shown one after another while reeling it in.
@export var reel_lines: PackedStringArray = PackedStringArray([
	"Something huge took the bait...",
	"It's pulling hard!",
	"Don't let go...",
	"It's coming up!",
])
## The conversation after the catch, one line per entry, click to go on.
## Lines starting with "you:" are yours; the rest are the boss speaking.
@export var dialogue: PackedStringArray = PackedStringArray()
