# layers.gd
# Drawing order (z_index) of the water views, bottom to top. The toilet and
# the pond use the same bands, so things stack the same way in both:
#
#   UNDERWATER     -20  "Underwater" Node2D: bowl bottom, pond floor, rocks,
#                       plants (underwater.gdshader via Use Parent Material)
#   WATER_FLOOR    -10  light net on the bottom (WaterFloor, pond_water)
#   FISH             0  fish; pond depth levels go 0, -1, -2, -3
#   WATER_SURFACE   10  sparkles / foam (WaterSurface, pond_water)
#   ABOVE_WATER     20  "AboveWater" Node2D: rim, edge stones, lily pads,
#                       pipe, anything dry (no water shader)
#
# Scenes set these numbers on the group nodes in the Inspector; code that
# places things uses the constants.
class_name Layers
extends RefCounted

const UNDERWATER := -20
const WATER_FLOOR := -10
const FISH := 0
const WATER_SURFACE := 10
const ABOVE_WATER := 20
