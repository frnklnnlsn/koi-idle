# number_format.gd
# How big numbers are written, following Settings "Big numbers":
#   0  commas       1,234,567
#   1  short        1.23M      (K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc)
#   2  scientific   1.23e6
# Numbers under 1,000 always look the same. Settings sets `mode`.
class_name NumberFormat
extends RefCounted

const SUFFIXES := ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

static var mode := 0


## A whole number (money, grams): 950 -> "950", 1234567 -> "1,234,567" / "1.23M".
static func whole(x: float) -> String:
	if absf(x) < 1000.0:
		return str(int(x))
	return big(x)


## A number of 1,000 or more, in the chosen style.
static func big(x: float) -> String:
	var a := absf(x)
	var sign := "-" if x < 0 else ""
	match mode:
		1:
			var tier := int(floor(log(a) / log(1000.0)))
			if tier >= 1 and tier <= SUFFIXES.size():
				return sign + _three_digits(a / pow(1000.0, tier)) + SUFFIXES[tier - 1]
			return sign + _scientific(a)
		2:
			return sign + _scientific(a)
	return sign + commas(floori(a))


## 1234567 -> "1,234,567"
static func commas(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(-3)
	return ("-" if n < 0 else "") + digits + out


## 1.234 -> "1.23", 12.34 -> "12.3", 123.4 -> "123"
static func _three_digits(v: float) -> String:
	# Round down so 999.96K shows as 999K, not 1000K.
	if v >= 100.0:
		return str(floori(v))
	if v >= 10.0:
		return "%.1f" % (floorf(v * 10.0) / 10.0)
	return "%.2f" % (floorf(v * 100.0) / 100.0)


## 1234567 -> "1.23e6"
static func _scientific(a: float) -> String:
	var e := int(floor(log(a) / log(10.0)))
	return "%se%d" % [_three_digits(a / pow(10.0, e)), e]
