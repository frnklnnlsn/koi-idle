extends MarginContainer

signal hovered(fish_resource:fish_conf)
signal unhovered(fish_resource:fish_conf)
signal selected_deselected(fish_resource:fish_conf)
var fish_resource:fish_conf

var focused:bool = false


func _ready() -> void:
	# See-through fish viewport, so the card's rarity colour shows behind it.
	$SubViewportContainer/FishViewport.transparent_bg = true
	if fish_resource:
		_apply_rarity()


## Background colour by the fish's combined rarity across all three stats
## (FishStats tiers: Uncommon green, Rare blue, Epic purple, Legendary gold).
## Common fish keep the plain card.
func _apply_rarity() -> void:
	var cz := FishStats.fish_combined_z(fish_resource)
	var tier := FishStats.tier_index(cz)
	$card_button.tooltip_text = "%s  (top %s%% overall)" % [FishStats.TIERS[tier][0], FishStats._pct(FishStats.top_percent(cz))]
	if tier == FishStats.TIERS.size() - 1:
		return
	var style := StyleBoxFlat.new()
	var c: Color = FishStats.TIERS[tier][2]
	style.bg_color = Color(c, 0.4)
	style.set_corner_radius_all(3)
	var bg := Panel.new()
	bg.name = "RarityBackground"
	bg.add_theme_stylebox_override("panel", style)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)   # behind the fish and the button

func _on_card_button_pressed():
	
	#print(self.has_theme_stylebox("normal"))
	if focused == false:
		focused = true
		
	else:
		focused = false

	selected_deselected.emit(fish_resource)
	


func _on_card_button_mouse_entered():
	hovered.emit(fish_resource)
	self.set_scale(Vector2(1.5,1.5))


func _on_card_button_mouse_exited():
	unhovered.emit(fish_resource)
	self.set_scale(Vector2(1,1))
