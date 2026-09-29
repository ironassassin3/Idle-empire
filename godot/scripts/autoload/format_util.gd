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
	# Below 1 this used to floor to "0" via str(int(n)), so a new player holding
	# nine Corner Dealers read "$0/s" on the row and "+ $0 / SEC" in the masthead
	# one tutorial step after being told buildings earn passively (device pass
	# 2026-07-30). Small values keep two decimals; the trim keeps whole numbers
	# clean, so "$10" and "$1" are unchanged. Intentionally diverges from
	# src/theme.py format_number, which is lab-only and never shown to a player.
	if n < 10.0:
		return ("-" if neg else "") + ("%.2f" % n).rstrip("0").rstrip(".")
	return ("-" if neg else "") + str(int(n))


func format_money(n: float) -> String:
	return "$" + format_number(n)
