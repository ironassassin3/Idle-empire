extends Node
## Compact number formatting — matches src/theme.py format_number.

const _SUFFIXES: Array = [
	[1e33, "Dc"], [1e30, "No"], [1e27, "Oc"], [1e24, "Sp"], [1e21, "Sx"],
	[1e18, "Qi"], [1e15, "Qa"], [1e12, "T"], [1e9, "B"], [1e6, "M"], [1e3, "K"],
]


func format_number(n: float) -> String:
	if is_nan(n) or is_inf(n):
		return "0"
	var neg := n < 0.0
	n = absf(n)
	for entry in _SUFFIXES:
		var threshold: float = entry[0]
		var suffix: String = entry[1]
		if n >= threshold:
			var val := n / threshold
			var decimals := 1 if val >= 10.0 else 2
			var formatted := ("%." + str(decimals) + "f") % val
			formatted = formatted.rstrip("0").rstrip(".")
			return ("-" if neg else "") + formatted + suffix
	return ("-" if neg else "") + str(int(n))


func format_money(n: float) -> String:
	return "$" + format_number(n)
