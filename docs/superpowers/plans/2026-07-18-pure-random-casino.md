# Pure-Random Cash Casino Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the timing/skill nudge from the cash-wager casino so it is honest pure-RNG with a single fixed `WAGER_RTP = 0.90`; the wheel animation becomes a cosmetic reveal of a pre-resolved outcome.

**Architecture:** The model (`gambling_system.gd`) collapses `RTP(skill)` to one constant and drops the position parameter from `resolve_wager`. `GameState.place_wager(stake)` resolves instantly and returns the result dict; player-facing feedback (toast + sfx) moves to a new `notify_wager_result(res)` the overlay calls **after** the reveal animation lands, so sound never spoils the spin. The wheel gains a `spin_to_band()` ease-out reveal over a cosmetic band ring. Free-spin Luck Wheel path is untouched.

**Tech Stack:** Godot 4.6 GDScript (ship target), Python sim (`sim_gambling.py`) as the EV guardrail, headless probes (`wager_probe.gd`, `shell_smoke.gd`).

**Spec:** `docs/superpowers/specs/2026-07-18-pure-random-casino-design.md`

## Global Constraints

- In-game currency only; **never real money** (hard constraint).
- Wheel band shape + weights unchanged: `WAGER_BANDS = [0.0, 0.5, 1.0, 2.0, 5.0, 25.0]`, `WAGER_WEIGHTS = [0.48, 0.20, 0.15, 0.10, 0.06, 0.01]` (mean exactly 1.0); only the RTP scalar changes.
- `WAGER_RTP := 0.90` — the single fixed house edge.
- Free-spin Luck Wheel behavior byte-for-byte unchanged (`SEGMENT_MULTS`, `resolve`, `start_round`, sweep/STOP input).
- No save migration; lifetime wager stats preserved; `wager_sweet_spot` key stays initialised to `-1.0` for save-shape stability (vestigial).
- Godot binary for headless runs: `$env:GODOT_BIN` or `E:\Downloads\Godot_v4.6.3-stable_win64.exe`.
- Tabs for GDScript indentation (project convention).

---

### Task 1: Sim guardrail — pure-random wager path

**Files:**
- Modify: `sim_gambling.py:93-180` (wager section only)

**Interfaces:**
- Produces: `WAGER_RTP = 0.90` constant and `simulate_wager(rng) -> float`; `print_wager_section` prints `PASS` iff measured EV < 1.0 and within 0.02 of 0.90. Task 2 must keep the GDScript constants identical to this mirror.

- [ ] **Step 1: Replace the skill-conditioned wager model**

Replace the block at `sim_gambling.py:93-139` (comment header through `simulate_wager`) with:

```python
# --- Cash-wager casino (pure RNG, fixed house edge) ----------------------
# Mirror of gambling_system.gd WAGER_* constants. The wheel SHAPE has mean 1.0
# so it leaks no EV; the house edge lives entirely in the fixed WAGER_RTP < 1.
WAGER_BANDS = [0.0, 0.5, 1.0, 2.0, 5.0, 25.0]
WAGER_WEIGHTS = [0.48, 0.20, 0.15, 0.10, 0.06, 0.01]
WAGER_JACKPOT = 25.0
WAGER_RTP = 0.90


def _wager_draw_band(rng: random.Random) -> float:
    u = rng.random()
    c = 0.0
    for band, w in zip(WAGER_BANDS, WAGER_WEIGHTS):
        c += w
        if u <= c:
            return band
    return WAGER_BANDS[-1]


def simulate_wager(rng: random.Random) -> float:
    """One cash wager: pure RNG band times fixed RTP. No skill axis exists."""
    return _wager_draw_band(rng) * WAGER_RTP
```

This deletes `_ring_dist`, `_wager_skill`, and the jitter/sweet-spot model (`WAGER_RTP_BASE`, `WAGER_RTP_SKILL`, `WAGER_SKILL_TOL`).

- [ ] **Step 2: Replace `print_wager_section`**

Replace `print_wager_section` (was `sim_gambling.py:142-180`) with:

```python
def print_wager_section(spins: int, seed: int) -> None:
    shape_mean = sum(b * w for b, w in zip(WAGER_BANDS, WAGER_WEIGHTS))
    print("\n" + "=" * 78)
    print("CASH-WAGER CASINO — pure RNG, fixed house edge")
    print("  wheel shape mean = %.4fx (must be 1.0000 or the edge leaks) · "
          "jackpot %gx" % (shape_mean, WAGER_JACKPOT))
    print("  RTP = %.2f fixed  ->  house edge %.0f%% for every player "
          "(timing does nothing)" % (WAGER_RTP, (1 - WAGER_RTP) * 100))
    rng = random.Random(seed + 99)
    evs = [simulate_wager(rng) for _ in range(spins)]
    ev = statistics.fmean(evs)
    p_jack = sum(1 for m in evs if m >= WAGER_JACKPOT * WAGER_RTP) / spins
    p_loss = sum(1 for m in evs if m < 1.0) / spins
    print("%-30s %8s %8s %9s %8s"
          % ("profile", "EV(x)", "P(25x)", "P(<stake)", "edge"))
    print("-" * 78)
    print("%-30s %8.3f %7.2f%% %8.1f%% %7.1f%%"
          % ("any player (no skill axis)", ev,
             p_jack * 100, p_loss * 100, (1 - ev) * 100))
    print("-" * 78)
    ok = ev < 1.0 and abs(ev - WAGER_RTP) < 0.02
    print("  HOUSE EDGE HOLDS: measured EV = %.3fx (expected %.2fx, must be "
          "< 1.0)  ->  %s" % (ev, WAGER_RTP, "PASS" if ok else "FAIL"))
    print("  Every player loses ~%.0f%% of each dollar wagered long-run; no "
          "timing can change it." % ((1 - ev) * 100))
```

The free-spin sections (`SKILL_PROFILES`, `simulate_spin`, daily scenarios) are untouched.

- [ ] **Step 3: Run the sim and verify PASS**

Run: `python sim_gambling.py --wager --spins 200000`
Expected: wager section prints `EV ≈ 0.900`, `HOUSE EDGE HOLDS ... PASS`; free-spin section output unchanged from before the edit.

- [ ] **Step 4: Lint**

Run: `flake8 sim_gambling.py`
Expected: no output.

- [ ] **Step 5: Commit**

```powershell
git add sim_gambling.py
git commit -m "feat(sim): pure-random cash casino guardrail - fixed 0.90 RTP, no skill axis"
```

---

### Task 2: Model + GameState entry points + headless probe

**Files:**
- Modify: `godot/scripts/systems/gambling_system.gd:37-166`
- Modify: `godot/scripts/autoload/game_state.gd:1305-1352`
- Modify: `godot/scripts/tools/wager_probe.gd`

**Interfaces:**
- Consumes: constants proven in Task 1 (`WAGER_RTP = 0.90`).
- Produces (Task 3 relies on these exact signatures):
  - `GamblingSystem.resolve_wager(state, stake: float, rng) -> Dictionary` — keys `{ok, multiplier, band, rtp, stake, payout, net, jackpot, reason}` (no `skill`, no `position` param).
  - `GamblingSystem.make_wager_display() -> Array` — shuffled cosmetic band ring.
  - `GameState.place_wager(stake: float) -> Dictionary` — result dict; on success also `"msg"` (status-line copy). No toast/sfx here.
  - `GameState.notify_wager_result(res: Dictionary) -> void` — toast + sfx, called after the reveal.
  - `GameState.wager_display_segments() -> Array`.
  - `GameState.start_wager_round()` is **deleted**.

- [ ] **Step 1: Collapse the RTP model in `gambling_system.gd`**

Replace the casino header + constants block (lines 37–59) with:

```gdscript
# ── Cash-wager casino (pure RNG, fixed house edge) ─────────────────────────
## Unlike the free daily spin (positive-EV, no loss), the casino lets the player
## stake real balance and CAN lose it. The outcome is pure RNG — there is no
## timing/skill input. The wheel SHAPE has mean multiplier == 1.0 (pure
## variance), and the entire edge lives in one constant: payout is
## `stake * band * WAGER_RTP`, so EV == WAGER_RTP == 0.90 < 1 → the house
## always wins long-run. Proven in sim_gambling.py (--wager). KEEP IN SYNC.
const WAGER_ENABLED := true

# Fair wheel shape: Σ weights == 1 and Σ band*weight == 1.0 exactly. The mean is
# pinned to 1.0 so the segment RNG can never leak EV — the edge is only in RTP.
const WAGER_BANDS: Array = [0.0, 0.5, 1.0, 2.0, 5.0, 25.0]
const WAGER_WEIGHTS: Array = [0.48, 0.20, 0.15, 0.10, 0.06, 0.01]
const WAGER_JACKPOT := 25.0

# Single fixed return-to-player. This IS the house edge (10%).
const WAGER_RTP := 0.90
const WAGER_MIN_STAKE := 1.0
```

Then delete `wager_skill()` (lines 62–66), `wager_rtp()` (69–70), and `roll_sweet_spot()` (84–89). `wager_draw_band()` stays verbatim.

- [ ] **Step 2: Add the cosmetic display ring builder**

Insert after `wager_draw_band()`:

```gdscript
## Cosmetic reveal ring for the casino spin: a shuffled strip of band values the
## needle settles on. Segment counts are VISUAL ONLY — the real odds are
## WAGER_WEIGHTS; the landing segment is chosen to match the already-drawn band.
static func make_wager_display() -> Array:
	var counts := {0.0: 9, 0.5: 4, 1.0: 3, 2.0: 2, 5.0: 1, 25.0: 1}
	var segs: Array = []
	for band in counts:
		for i in int(counts[band]):
			segs.append(float(band))
	segs.shuffle()
	return segs
```

- [ ] **Step 3: Rewrite `resolve_wager` without the position/skill axis**

Replace `resolve_wager` (lines 92–132) with:

```gdscript
## Resolve a cash wager. Debits `stake` from balance, draws an RNG band, scales
## by the fixed WAGER_RTP, credits the payout. Net can be negative (a real loss).
## Returns {ok, multiplier, band, rtp, stake, payout, net, jackpot, reason}.
static func resolve_wager(state, stake: float, rng: RandomNumberGenerator) -> Dictionary:
	var fail := {
		"ok": false, "multiplier": 0.0, "band": 0.0, "rtp": 0.0,
		"stake": 0.0, "payout": 0.0, "net": 0.0, "jackpot": false, "reason": "",
	}
	if not WAGER_ENABLED:
		fail["reason"] = "Casino disabled"
		return fail
	if stake < WAGER_MIN_STAKE:
		fail["reason"] = "Stake too small"
		return fail
	if stake > state.balance:
		fail["reason"] = "Not enough cash"
		return fail
	var band := wager_draw_band(rng)
	var mult := band * WAGER_RTP
	var payout := stake * mult
	var net := payout - stake
	# Debit the stake, credit the payout. Winnings feed balance/lifetime_earnings
	# but NOT prestige_route_earnings (same rule as the free spin).
	state.balance -= stake
	state.balance += payout
	if net > 0.0:
		state.lifetime_earnings += net
	state.gambling["lifetime_wagered"] = float(state.gambling.get("lifetime_wagered", 0.0)) + stake
	state.gambling["lifetime_wager_net"] = float(state.gambling.get("lifetime_wager_net", 0.0)) + net
	state.gambling["lifetime_plays"] = int(state.gambling.get("lifetime_plays", 0)) + 1
	if mult > float(state.gambling.get("best_mult", 0.0)):
		state.gambling["best_mult"] = mult
	return {
		"ok": true, "multiplier": mult, "band": band, "rtp": WAGER_RTP,
		"stake": stake, "payout": payout, "net": net,
		"jackpot": band >= WAGER_JACKPOT, "reason": "",
	}
```

In `make_gambling()` change the `wager_sweet_spot` comment to:

```gdscript
		# Vestigial (pre-pure-random save shape); nothing writes a real value.
		"wager_sweet_spot": -1.0,
```

`merge_save_gambling` keeps `g["wager_sweet_spot"] = -1.0` as-is.

- [ ] **Step 4: Rewire `game_state.gd` casino entry points**

Replace the `# ── Cash-wager casino` section (lines 1305–1352: `gambling_wager_enabled`, `start_wager_round`, `place_wager`) with:

```gdscript
# ── Cash-wager casino ────────────────────────────────────────────────────────

func gambling_wager_enabled() -> bool:
	return GameConfig.GAMBLING_ENABLED and _GamblingSystem.WAGER_ENABLED


## Cosmetic reveal ring for the overlay (visual only; odds live in the system).
func wager_display_segments() -> Array:
	return _GamblingSystem.make_wager_display()


## Place a cash wager — pure RNG, resolved instantly (the wheel animation is a
## cosmetic reveal). Returns the result dict; on success it includes "msg" for
## the overlay status line. Toast + sfx fire in notify_wager_result, which the
## overlay calls AFTER the reveal lands so sound doesn't spoil the outcome.
func place_wager(stake: float) -> Dictionary:
	var res := _GamblingSystem.resolve_wager(self, stake, _rng)
	if not res.get("ok", false):
		return res
	_mark_ips_dirty()
	stats_changed.emit()
	var mult: float = float(res.get("multiplier", 0.0))
	var net: float = float(res.get("net", 0.0))
	var win_net_ratio := 0.0
	var wagered: float = float(gambling.get("lifetime_wagered", 0.0))
	if wagered > 0.0:
		win_net_ratio = float(gambling.get("lifetime_wager_net", 0.0)) / wagered
	Telemetry.log_event("gamble_wager_resolve", {
		"stake": float(res.get("stake", 0.0)),
		"mult": mult,
		"net": net,
		"rtp": float(res.get("rtp", 0.0)),
		"jackpot": bool(res.get("jackpot", false)),
		"lifetime_wagered": wagered,
		"lifetime_wager_net": float(gambling.get("lifetime_wager_net", 0.0)),
		"lifetime_wager_net_ratio": win_net_ratio,
	})
	if res.get("jackpot", false):
		res["msg"] = "BIG SCORE ×%.1f\n+%s" % [mult, FormatUtil.format_money(net)]
	elif net > 0.0:
		res["msg"] = "Paid off ×%.2f\n+%s" % [mult, FormatUtil.format_money(net)]
	else:
		res["msg"] = "Deal fell through\n%s" % FormatUtil.format_money(net)
	return res


## Player-facing feedback for a resolved wager. Split from place_wager so the
## overlay can delay it until the reveal animation lands.
func notify_wager_result(res: Dictionary) -> void:
	if not res.get("ok", false):
		return
	var mult: float = float(res.get("multiplier", 0.0))
	var net: float = float(res.get("net", 0.0))
	if res.get("jackpot", false):
		_play_sfx("rankup")
		notification.emit("BIG SCORE ×%.0f  +%s" % [mult, FormatUtil.format_money(net)], GameTheme.GOLD_BRIGHT)
	elif net > 0.0:
		_play_sfx("coin")
		notification.emit("Paid off ×%.2f  +%s" % [mult, FormatUtil.format_money(net)], GameTheme.GREEN)
	else:
		_play_sfx("click")
		notification.emit("Deal fell through  %s" % FormatUtil.format_money(net), GameTheme.RED)
```

Telemetry drops the `skill` field; `rtp` stays (now constant).

- [ ] **Step 5: Update `wager_probe.gd` — exact-payout invariant + 0.90 RTP**

Replace the trial loop and verdict (lines 26–45) with:

```gdscript
	var bad_payout := false
	for i in trials:
		if gs.balance < 1000.0:
			gs.balance += 1_000_000.0
		var stake := 100.0
		var before: float = gs.balance
		var res: Dictionary = gs.place_wager(stake)
		var net: float = gs.balance - before
		# Exact-payout invariant: payout == stake * band * WAGER_RTP (0.90).
		var expect_net: float = stake * (float(res.get("band", 0.0)) * 0.90 - 1.0)
		if absf(net - expect_net) > 0.001:
			bad_payout = true
		total_staked += stake
		total_net += net
		min_balance = minf(min_balance, gs.balance)
		if gs.balance < 0.0:
			neg = true
	var rtp := (total_staked + total_net) / total_staked
	print("trials=%d  staked=%.0f  net=%.0f" % [trials, total_staked, total_net])
	print("effective RTP = %.4f  (expect ~0.90)" % rtp)
	print("house edge = %.2f%%" % ((1.0 - rtp) * 100.0))
	print("min balance seen = %.0f   negative-balance? %s" % [min_balance, str(neg)])
	print("exact-payout invariant holds? %s" % str(not bad_payout))
	var ok := not neg and not bad_payout and rtp < 1.0 and absf(rtp - 0.90) < 0.01
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	return true
```

Also delete the now-dead `gs.start_wager_round()` and `var pos := rng.randf()` lines, update the file docstring ("random-timing wagers" → "pure-RNG wagers"), and drop the unused `rng` if nothing else uses it.

- [ ] **Step 6: Run the probe headlessly and verify PASS**

```powershell
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "E:\Downloads\Godot_v4.6.3-stable_win64.exe" }
& $godot --headless --path godot -s res://scripts/tools/wager_probe.gd
```

Expected: `effective RTP = 0.90xx`, `exact-payout invariant holds? true`, `RESULT: PASS`. Also confirm no script parse errors in the output (the overlay UI still references the old API at this point — that's Task 3; parse errors from `gambling_overlay.gd`/`gambling_wheel.gd` are expected only if they load in headless. If they appear, note it and proceed to Task 3 before re-running.)

- [ ] **Step 7: Grep for stragglers**

Run: `grep -rn "start_wager_round\|wager_skill\|roll_sweet_spot\|WAGER_RTP_BASE" godot/scripts sim_gambling.py`
Expected: only hits left are in `gambling_overlay.gd`/`gambling_wheel.gd` (fixed in Task 3).

- [ ] **Step 8: Commit**

```powershell
git add godot/scripts/systems/gambling_system.gd godot/scripts/autoload/game_state.gd godot/scripts/tools/wager_probe.gd
git commit -m "feat(casino): pure-random cash wager - fixed 0.90 RTP, no skill nudge (model+state)"
```

---

### Task 3: UI — SPIN reveal replaces timing input (wager mode only)

**Files:**
- Modify: `godot/scripts/ui/gambling_wheel.gd`
- Modify: `godot/scripts/ui/gambling_overlay.gd`

**Interfaces:**
- Consumes: `GameState.place_wager(stake) -> Dictionary` (with `"msg"`), `GameState.notify_wager_result(res)`, `GameState.wager_display_segments() -> Array` from Task 2.
- Produces: wheel API `set_wager_segments(segs: Array)`, `spin_to_band(band: float)`, `signal landed`, `is_wager_mode() -> bool`. Free-spin API (`set_segments`, `start_sweep`, `stop_sweep`, `stopped`) unchanged.

- [ ] **Step 1: Rework `gambling_wheel.gd` — drop sweet spot, add reveal animation**

Remove `_sweet_spot`, `set_sweet_spot()`, `_draw_wager_meter()`, and the sweet-spot branches in `_draw()`/`has_round()`/`is_wager_mode()`. Add the reveal state + API:

```gdscript
signal landed

const REVEAL_TIME := 1.6   # seconds for the cosmetic casino reveal
const REVEAL_LOOPS := 2.5  # extra full loops before settling

var _wager_mode := false
var _revealing := false
var _reveal_t := 0.0
var _reveal_from := 0.0
var _reveal_travel := 0.0
```

`set_segments(segs)` additionally sets `_wager_mode = false`. New methods:

```gdscript
## Casino mode: show the cosmetic band ring the reveal needle settles on.
func set_wager_segments(segs: Array) -> void:
	_segments = segs
	_wager_mode = true
	queue_redraw()


func is_wager_mode() -> bool:
	return _wager_mode


## Cosmetic reveal: auto-spin the needle and settle it on a segment holding
## `band`. The outcome is already resolved — this animation only presents it.
func spin_to_band(band: float) -> void:
	var candidates: Array = []
	for i in _segments.size():
		if is_equal_approx(float(_segments[i]), band):
			candidates.append(i)
	if candidates.is_empty():
		candidates.append(0)
	var idx: int = candidates[randi() % candidates.size()]
	var target := (float(idx) + randf_range(0.35, 0.65)) / float(_segments.size())
	_reveal_from = fposmod(_position, 1.0)
	_reveal_travel = REVEAL_LOOPS + fposmod(target - _reveal_from, 1.0)
	_reveal_t = 0.0
	_revealing = true
	_sweeping = false
	set_process(true)
```

`_process` handles the reveal before the sweep:

```gdscript
func _process(delta: float) -> void:
	if _revealing:
		_reveal_t = minf(_reveal_t + delta / REVEAL_TIME, 1.0)
		var eased := 1.0 - pow(1.0 - _reveal_t, 3)
		_position = fposmod(_reveal_from + _reveal_travel * eased, 1.0)
		queue_redraw()
		if _reveal_t >= 1.0:
			_revealing = false
			set_process(false)
			landed.emit()
		return
	if not _sweeping:
		return
	_position = fposmod(_position + _Gambling.SWEEP_SPEED * delta, 1.0)
	queue_redraw()
```

`reset()` also clears `_revealing = false`; `has_round()` becomes `return not _segments.is_empty()`; `start_sweep()` guard becomes `if not has_round() or _revealing: return`. `_draw()` keeps only the segment-ring path (existing `_seg_color`/`_seg_label` already handle 0/0.5/1/2/5/25 — 25 ≥ `JACKPOT_MULT` renders gold). Update the file doc comment: wager mode is a cosmetic auto-spin reveal, not an input.

- [ ] **Step 2: Rework `gambling_overlay.gd` — BET resolves instantly, reveal then feedback**

Replace `var _active_stake: float = 0.0` with `var _active_res: Dictionary = {}`. In `_ready()` add `_wheel.landed.connect(_on_wheel_landed)`. Replace `_on_bet_pressed` and `_on_wheel_stopped`, add `_on_wheel_landed`:

```gdscript
func _on_bet_pressed() -> void:
	if _phase == Phase.SWEEPING or not _can_wager():
		return
	_stake = clampf(_stake, _Gambling.WAGER_MIN_STAKE, GameState.balance)
	var res: Dictionary = GameState.place_wager(_stake)
	if not res.get("ok", false):
		_status.text = str(res.get("reason", "Cannot bet"))
		return
	# Cash already settled — the spin below is a cosmetic reveal only.
	_active_res = res
	_mode = Mode.WAGER
	_status.text = ""
	_wheel.set_wager_segments(GameState.wager_display_segments())
	_wheel.reset()
	_wheel.spin_to_band(float(res.get("band", 0.0)))
	_phase = Phase.SWEEPING
	_refresh()


func _on_wheel_landed() -> void:
	GameState.notify_wager_result(_active_res)
	_status.text = str(_active_res.get("msg", ""))
	_active_res = {}
	_phase = Phase.DONE
	_refresh()


func _on_wheel_stopped(position: float) -> void:
	if _mode != Mode.FREE:
		return
	_status.text = GameState.resolve_gamble(position)
	_phase = Phase.DONE
	_refresh()
```

In `_refresh()`, replace the `Phase.SWEEPING` branch with:

```gdscript
	if _phase == Phase.SWEEPING:
		_wager_row.visible = false
		_bet_btn.visible = false
		_ad_btn.visible = false
		if _mode == Mode.WAGER:
			# Pure RNG — no input during the reveal; the outcome is already drawn.
			_prompt.text = "The wheel decides — pure luck, no skill."
			_spin_btn.visible = false
		else:
			_prompt.text = "STOP on a high multiplier — timing is everything."
			_spin_btn.visible = true
			_spin_btn.text = "STOP"
			_spin_btn.disabled = false
		return
```

Update the file doc comment (lines 2–9): BET is pure-RNG resolved at press, marker auto-spins as a reveal; FREE SPIN keeps the skill STOP. Note: closing the overlay mid-reveal is safe — the wager settled at press, only the toast is skipped.

- [ ] **Step 3: Straggler grep**

Run: `grep -rn "set_sweet_spot\|_sweet_spot\|start_wager_round\|_active_stake" godot/scripts`
Expected: only the vestigial `wager_sweet_spot` save key in `gambling_system.gd` remains.

- [ ] **Step 4: Headless verification — probe + shell smoke**

```powershell
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "E:\Downloads\Godot_v4.6.3-stable_win64.exe" }
& $godot --headless --path godot -s res://scripts/tools/wager_probe.gd
& $godot --headless --path godot -s res://scripts/tools/shell_smoke.gd
```

Expected: `RESULT: PASS` and `[shell_smoke] PASS`, no script errors mentioning `gambling_*`.

- [ ] **Step 5: Commit**

```powershell
git add godot/scripts/ui/gambling_wheel.gd godot/scripts/ui/gambling_overlay.gd
git commit -m "feat(casino): SPIN reveal replaces timing input in cash-wager mode"
```

---

### Task 4: Docs + final sweep

**Files:**
- Modify: `docs/GAMBLING_ARCHITECTURE.md:130-170` (casino section)

**Interfaces:** none (documentation).

- [ ] **Step 1: Update the architecture doc**

Read `docs/GAMBLING_ARCHITECTURE.md` around lines 120–170 and rewrite the cash-casino rows/paragraphs to match the shipped design:
- RTP row: `WAGER_RTP = 0.90` fixed — 10% house edge for every player; no skill term.
- Flow paragraph (~lines 161–163): BET → `place_wager(stake)` resolves instantly (pure RNG) → wheel shows a cosmetic band ring (`make_wager_display`) and auto-spins to the drawn band → `notify_wager_result` fires toast/sfx after landing. Remove all mention of `start_wager_round`, sweet spot, skill meter, and STOP-timing for the wager mode.

- [ ] **Step 2: Full verification sweep**

```powershell
python sim_gambling.py --wager --spins 200000
flake8 sim_gambling.py
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "E:\Downloads\Godot_v4.6.3-stable_win64.exe" }
& $godot --headless --path godot -s res://scripts/tools/wager_probe.gd
& $godot --headless --path godot -s res://scripts/tools/shell_smoke.gd
python -m graphify update .
```

Expected: sim PASS (EV ≈ 0.90), flake8 clean, probe PASS (RTP ≈ 0.90, exact-payout true), shell_smoke PASS, graph updated.

- [ ] **Step 3: Commit**

```powershell
git add docs/GAMBLING_ARCHITECTURE.md
git commit -m "docs(gambling): pure-random casino - fixed 0.90 RTP architecture"
```
