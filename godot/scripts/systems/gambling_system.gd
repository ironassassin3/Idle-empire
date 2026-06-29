class_name GamblingSystem
extends RefCounted
## Active gambling — skill/timing "Luck Wheel" minigame.
##
## Spine is the daily-return engagement hook, NOT cash wagering: the only faucet
## is free spins granted by the login streak. A spin's payout is income-scaled
## (like the daily reward / lucky coin) and multiplied by the segment the player
## stops the marker on. Player timing skill is the only lever, so there is no
## heat, no Influence stake, and no prestige-gate contribution — gambling cannot
## destabilise the core economy.
##
## Model lives here (pure, static, testable); GameState owns the runtime dict and
## the player-facing methods; the overlay scene drives the marker animation.

# Wheel = a ring of segments. Multiplier is applied to one spin's base stake.
# Most segments are small/zero so the income faucet stays modest; the 10× jackpot
# slot is a single narrow band, reachable only by precise timing.
const SEGMENT_MULTS: Array = [0.0, 0.5, 1.5, 0.0, 1.0, 0.5, 2.0, 0.0, 1.0, 0.5, 1.5, 0.0, 1.0, 0.5, 2.0, 10.0]
const JACKPOT_MULT := 10.0

# One spin's base value = this many seconds of current income, floored so the
# minigame is meaningful in the opening minutes before income ramps.
const BASE_INCOME_SECONDS := 90.0
const BASE_MIN_ABSOLUTE := 50.0

# Free-spin economy (engagement hook).
const DAILY_FREE_SPINS := 1          # granted per calendar day via the login flow
const FREE_SPIN_CAP := 5             # banked spins cannot exceed this
const STREAK_BONUS_THRESHOLD := 7    # a maxed daily streak grants a 2nd spin
const STREAK_BONUS_SPINS := 1
const WELCOME_FREE_SPINS := 1      # one-time onboarding spin on new game

# Marker sweep speed (bars/sec). UI reads this; validate via sim_gambling.py.
const SWEEP_SPEED := 1.7


## Fresh runtime container. Mirrors WorldState.make_* factories.
static func make_gambling() -> Dictionary:
	return {
		"free_spins": WELCOME_FREE_SPINS,
		"lifetime_plays": 0,
		"lifetime_winnings": 0.0,
		"best_mult": 0.0,
		# Per-round, runtime-only (not saved): the shuffled segment order the UI
		# is currently rendering. Rebuilt every start_round so a spin can't be
		# memorised. Empty when no round is staged.
		"round_segments": [],
	}


static func merge_save_gambling(g: Dictionary, saved) -> void:
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for key in ["free_spins", "lifetime_plays"]:
		if saved.get(key) != null:
			g[key] = int(saved[key])
	for key in ["lifetime_winnings", "best_mult"]:
		if saved.get(key) != null:
			g[key] = float(saved[key])
	g["free_spins"] = clampi(int(g.get("free_spins", 0)), 0, FREE_SPIN_CAP)
	g["round_segments"] = []


static func gambling_to_save(g: Dictionary) -> Dictionary:
	return {
		"free_spins": int(g.get("free_spins", 0)),
		"lifetime_plays": int(g.get("lifetime_plays", 0)),
		"lifetime_winnings": float(g.get("lifetime_winnings", 0.0)),
		"best_mult": float(g.get("best_mult", 0.0)),
	}


# ── Free-spin grants ───────────────────────────────────────────────────────

static func free_spins(state) -> int:
	return int(state.gambling.get("free_spins", 0))


static func has_spin(state) -> bool:
	return free_spins(state) > 0


## Daily login grant. Called from GameState._apply_daily_reward (which already
## fires exactly once per calendar day), so this needs no own date bookkeeping.
## Returns the number of spins actually banked (0 if already at cap), for the
## return-overlay copy.
static func grant_daily_spins(state, daily_streak: int) -> int:
	var grant := DAILY_FREE_SPINS
	if daily_streak >= STREAK_BONUS_THRESHOLD:
		grant += STREAK_BONUS_SPINS
	var before: int = free_spins(state)
	var after: int = clampi(before + grant, 0, FREE_SPIN_CAP)
	state.gambling["free_spins"] = after
	return after - before


## Monetization hook (rewarded ad → +1 spin). Kept here so the Monetization
## autoload stays a thin shell. Returns true if a spin was banked.
static func grant_ad_spin(state) -> bool:
	if free_spins(state) >= FREE_SPIN_CAP:
		return false
	state.gambling["free_spins"] = free_spins(state) + 1
	return true


# ── Round lifecycle ────────────────────────────────────────────────────────

## Stage a new round: shuffle the segment ring and hand the layout to the UI.
## Does NOT consume a spin (so closing the overlay mid-spin is free); the spin is
## consumed at resolve. Returns [] if the player has no spins.
static func start_round(state, rng: RandomNumberGenerator) -> Array:
	if not has_spin(state):
		state.gambling["round_segments"] = []
		return []
	var segs: Array = SEGMENT_MULTS.duplicate()
	# Fisher–Yates so the jackpot band sits in a different place each spin.
	for i in range(segs.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = segs[i]
		segs[i] = segs[j]
		segs[j] = tmp
	state.gambling["round_segments"] = segs
	return segs.duplicate()


static func segment_count() -> int:
	return SEGMENT_MULTS.size()


## Map a normalised marker position [0,1) to the staged segment index.
static func position_to_index(state, position: float) -> int:
	var segs: Array = state.gambling.get("round_segments", [])
	var n: int = segs.size() if not segs.is_empty() else SEGMENT_MULTS.size()
	var p := fposmod(position, 1.0)
	return clampi(int(p * float(n)), 0, n - 1)


static func base_stake(state) -> float:
	return maxf(BASE_MIN_ABSOLUTE, state.income_per_second() * BASE_INCOME_SECONDS)


## Resolve a spin at the given marker position. Pure w.r.t. RNG — outcome is
## fully determined by where the player stopped the marker (skill). Consumes one
## free spin. Returns a result dict the caller turns into a notification/overlay:
##   {ok, multiplier, payout, jackpot, reason}
static func resolve(state, position: float) -> Dictionary:
	if not has_spin(state):
		return {"ok": false, "multiplier": 0.0, "payout": 0.0, "jackpot": false, "reason": "No spins left"}
	var segs: Array = state.gambling.get("round_segments", [])
	if segs.is_empty():
		return {"ok": false, "multiplier": 0.0, "payout": 0.0, "jackpot": false, "reason": "No round staged"}
	var idx := position_to_index(state, position)
	var mult := float(segs[idx])
	var payout := base_stake(state) * mult
	# Consume the spin and clear the staged round.
	state.gambling["free_spins"] = maxi(0, free_spins(state) - 1)
	state.gambling["round_segments"] = []
	state.gambling["lifetime_plays"] = int(state.gambling.get("lifetime_plays", 0)) + 1
	if mult > float(state.gambling.get("best_mult", 0.0)):
		state.gambling["best_mult"] = mult
	if payout > 0.0:
		state.gambling["lifetime_winnings"] = float(state.gambling.get("lifetime_winnings", 0.0)) + payout
		state.balance += payout
		state.lifetime_earnings += payout
		# NOTE: deliberately NOT added to prestige_route_earnings — gambling must
		# not count toward the prestige gate (it is a free engagement faucet).
	return {
		"ok": true,
		"multiplier": mult,
		"payout": payout,
		"jackpot": mult >= JACKPOT_MULT,
		"reason": "",
	}
