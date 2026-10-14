extends MarginContainer

signal hovered(fish_resource:fish_conf)
signal unhovered(fish_resource:fish_conf)
signal selected_deselected(fish_resource:fish_conf)
var fish_resource:fish_conf

var focused:bool = false
## True while the keyboard cursor is on this card.
var is_cursor := false
var _number: Label
var _cursor_frame: Panel


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
	self.set_scale(Vector2(1.5, 1.5) if is_cursor else Vector2(1, 1))


## The small number in the corner, used by keyboard commands like ":3,7d".
func set_number(n: int) -> void:
	if _number == null:
		_number = Label.new()
		_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_number.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_number.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_number.add_theme_font_size_override("font_size", 11)
		_number.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		_number.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_number.add_theme_constant_override("outline_size", 3)
		add_child(_number)
	_number.text = str(n)


## Keyboard cursor on / off: same enlarged look as mouse hover, plus a frame.
func set_cursor(on: bool) -> void:
	is_cursor = on
	set_scale(Vector2(1.5, 1.5) if on else Vector2(1, 1))
	z_index = 1 if on else 0
	if on and _cursor_frame == null:
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.border_color = Color(1.0, 0.85, 0.2)
		style.set_border_width_all(2)
		style.set_corner_radius_all(3)
		_cursor_frame = Panel.new()
		_cursor_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cursor_frame.add_theme_stylebox_override("panel", style)
		add_child(_cursor_frame)
	if _cursor_frame:
		_cursor_frame.visible = on
