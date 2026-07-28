extends CanvasLayer
## Luck Wheel overlay — free daily skill spin + cash-wager casino.
##
## Two ways to play, sharing one Wheel node but with two presentations:
##  • FREE SPIN — spends a banked free spin, positive-EV, never a cash loss.
##                Shows the wheel: a marker sweeps, the button becomes STOP and
##                the stop position (skill/timing) decides the payout.
##  • RISK $X   — stakes real balance on the pure-RNG casino; the house keeps a
##                fixed edge (RTP = 0.90) so it can lose. The wager resolves at
##                press — the Three-Card Monte shuffle-and-flip that follows is
##                a cosmetic reveal, and closing mid-reveal only skips the
##                toast, never the money.

const _Gambling = preload("res://scripts/systems/gambling_system.gd")
const GameFonts = preload("res://scripts/ui/game_fonts.gd")

enum Phase { READY, SWEEPING, DONE }
enum Mode { FREE, WAGER }

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _spins: Label = $Panel/Margin/VBox/SpinsLabel
@onready var _prompt: Label = $Panel/Margin/VBox/PromptLabel
@onready var _wheel: Control = $Panel/Margin/VBox/Wheel
@onready var _status: Label = $Panel/Margin/VBox/StatusLabel
@onready var _wager_row: HBoxContainer = $Panel/Margin/VBox/WagerRow
@onready var _stake_label: Label = $Panel/Margin/VBox/WagerRow/StakeLabel
@onready var _quarter_btn: Button = $Panel/Margin/VBox/WagerRow/QuarterBtn
@onready var _half_btn: Button = $Panel/Margin/VBox/WagerRow/HalfBtn
@onready var _max_btn: Button = $Panel/Margin/VBox/WagerRow/MaxBtn
@onready var _bet_btn: Button = $Panel/Margin/VBox/BetBtn
@onready var _spin_btn: Button = $Panel/Margin/VBox/SpinBtn
@onready var _ad_btn: Button = $Panel/Margin/VBox/AdBtn
@onready var _back_btn: Button = $Panel/Margin/VBox/BackBtn

var _phase: int = Phase.READY
var _mode: int = Mode.FREE
var _stake: float = 0.0
var _active_res: Dictionary = {}  # resolved wager awaiting its reveal


func _ready() -> void:
	layer = 11
	visible = false
	_apply_theme()
	_spin_btn.pressed.connect(_on_spin_pressed)
	_bet_btn.pressed.connect(_on_bet_pressed)
	_quarter_btn.pressed.connect(_set_stake_fraction.bind(0.25))
	_half_btn.pressed.connect(_set_stake_fraction.bind(0.5))
	_max_btn.pressed.connect(_set_stake_fraction.bind(1.0))
	_ad_btn.pressed.connect(_on_ad_pressed)
	_back_btn.pressed.connect(close)
	_wheel.stopped.connect(_on_wheel_stopped)
	_wheel.landed.connect(_on_wheel_landed)
	Monetization.ad_reward_granted.connect(_on_ad_reward)
	get_viewport().size_changed.connect(_fit_panel)
	_fit_panel()


## Fixed 680-wide centred box — fits a 720 phone, clips a 480 one.
func _fit_panel() -> void:
	GameTheme.fit_overlay_panel(_panel, Vector2(680, 520))


func _apply_theme() -> void:
	if GameTheme.is_city_v2_active():
		_panel.add_theme_stylebox_override("panel", GameTheme.overlay_ledger_style())
		_title.add_theme_font_override("font", GameFonts.heading())
	_title.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_title.add_theme_font_size_override("font_size", GameTheme.scaled_font(20))
	_spins.add_theme_color_override("font_color", GameTheme.TEXT)
	_spins.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	_prompt.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_prompt.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
	_status.add_theme_color_override("font_color", GameTheme.GOLD)
	_status.add_theme_font_size_override("font_size", GameTheme.scaled_font(15))
	GameTheme.apply_overlay_cta(_spin_btn, true)
	GameTheme.apply_overlay_cta(_bet_btn, true)
	for b in [_quarter_btn, _half_btn, _max_btn, _ad_btn, _back_btn]:
		GameTheme.apply_overlay_cta(b, false)


func open() -> void:
	visible = true
	_fit_panel()
	_status.text = ""
	_init_stake()
	_stage_free_round()  # ring shown when free spins exist; harmless otherwise
	if not GameState.stats_changed.is_connected(_refresh):
		GameState.stats_changed.connect(_refresh)
	_refresh()


func close() -> void:
	_wheel.reset()
	if GameState.stats_changed.is_connected(_refresh):
		GameState.stats_changed.disconnect(_refresh)
	visible = false


func _stage_free_round() -> void:
	_mode = Mode.FREE
	var segs: Array = GameState.start_gamble_round()
	_wheel.set_segments(segs)
	_wheel.reset()
	_phase = Phase.READY if not segs.is_empty() else Phase.DONE


func _init_stake() -> void:
	# Default to a quarter of balance, floored to the min stake.
	_stake = maxf(_Gambling.WAGER_MIN_STAKE, GameState.balance * 0.25)
	_stake = minf(_stake, GameState.balance)


func _set_stake_fraction(frac: float) -> void:
	_stake = clampf(GameState.balance * frac, _Gambling.WAGER_MIN_STAKE, maxf(GameState.balance, 0.0))
	_refresh()


func _can_wager() -> bool:
	return GameState.gambling_wager_enabled() and GameState.balance >= _Gambling.WAGER_MIN_STAKE


func _refresh() -> void:
	var spins: int = GameState.gambling_free_spins()
	_spins.text = "Spins: %d  ·  Cash: %s" % [spins, FormatUtil.format_money(GameState.balance)]
	_stake = minf(_stake, GameState.balance)  # balance may have shrunk

	if _phase == Phase.SWEEPING:
		_wager_row.visible = false
		_bet_btn.visible = false
		_ad_btn.visible = false
		if _mode == Mode.WAGER:
			# Pure RNG — no input during the reveal; the outcome is already drawn.
			_prompt.text = "Watch the cards — the dealer flips. Pure luck, no skill."
			_spin_btn.visible = false
		else:
			_prompt.text = "STOP on a high multiplier — timing is everything."
			_spin_btn.visible = true
			_spin_btn.text = "STOP"
			_spin_btn.disabled = false
		return

	# Idle / done state.
	var can_wager := _can_wager()
	_wager_row.visible = can_wager
	_bet_btn.visible = can_wager
	if can_wager:
		_bet_btn.text = "RISK  %s" % FormatUtil.format_money(_stake)
		_stake_label.text = "Risk: %s" % FormatUtil.format_money(_stake)

	if spins > 0:
		_spin_btn.visible = true
		_spin_btn.text = "SPIN AGAIN — free" if _phase == Phase.DONE else "SPIN — free"
		_spin_btn.disabled = false
		_ad_btn.visible = false
	else:
		_spin_btn.visible = not can_wager  # hide the dead free button if betting is offered
		_spin_btn.text = "SPIN"
		_spin_btn.disabled = true
		# Guardrail (origin/master 43bb862): ad→+1 spin is ineligible at cap OR on
		# max-streak days — can_gamble_ad_spin() covers both (was: spins < FREE_SPIN_CAP).
		_ad_btn.visible = not GameState.remove_ads and GameState.can_gamble_ad_spin()

	if _phase != Phase.DONE:
		if spins > 0:
			_prompt.text = "Tap SPIN for a free spin, or put cash on the line."
		elif can_wager:
			_prompt.text = "No free spins — put cash on the line to keep playing."
		else:
			_prompt.text = "No spins left — come back tomorrow for a free spin."


func _on_spin_pressed() -> void:
	if _phase == Phase.SWEEPING:
		_wheel.stop_sweep()  # → _on_wheel_stopped resolves the active mode
		return
	# Free spin.
	if GameState.gambling_free_spins() <= 0:
		return
	if _mode != Mode.FREE or _phase == Phase.DONE or not _wheel.has_round():
		_stage_free_round()
	if not _wheel.has_round():
		return
	_status.text = ""
	_wheel.start_sweep()
	_phase = Phase.SWEEPING
	_refresh()


func _on_bet_pressed() -> void:
	if _phase == Phase.SWEEPING or not _can_wager():
		return
	_stake = clampf(_stake, _Gambling.WAGER_MIN_STAKE, GameState.balance)
	var res: Dictionary = GameState.place_wager(_stake)
	if not res.get("ok", false):
		_status.text = str(res.get("reason", "Cannot bet"))
		return
	# Cash already settled — the Monte reveal below is cosmetic only.
	_active_res = res
	_mode = Mode.WAGER
	_status.text = ""
	_wheel.set_monte_round()
	_wheel.reset()
	_wheel.reveal_monte(float(res.get("band", 0.0)))
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


func _on_ad_pressed() -> void:
	# Rewarded +1 free spin, routed through the Monetization autoload. On device
	# this shows a real rewarded ad; the mock backend grants instantly in editor.
	Monetization.show_rewarded(Monetization.PLACEMENT_GAMBLE_SPIN)


func _on_ad_reward(placement: String) -> void:
	if placement != Monetization.PLACEMENT_GAMBLE_SPIN or not visible:
		return
	_status.text = "+1 spin"
	_stage_free_round()
	_refresh()
