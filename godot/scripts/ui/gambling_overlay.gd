extends CanvasLayer
## Luck Wheel overlay — skill/timing gambling (daily-spin engagement hook).
##
## Flow: open() stages a round (shuffled segments from GameState). SPIN starts the
## marker sweep; the button becomes STOP. STOP freezes the marker and resolves the
## spin at that position. One spin is consumed per resolve; when spins run out the
## CTA disables and (if ads are on) offers a rewarded +1 spin.

const _Gambling = preload("res://scripts/systems/gambling_system.gd")
const GameFonts = preload("res://scripts/ui/game_fonts.gd")

enum Phase { READY, SWEEPING, DONE }

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _spins: Label = $Panel/Margin/VBox/SpinsLabel
@onready var _prompt: Label = $Panel/Margin/VBox/PromptLabel
@onready var _wheel: Control = $Panel/Margin/VBox/Wheel
@onready var _status: Label = $Panel/Margin/VBox/StatusLabel
@onready var _spin_btn: Button = $Panel/Margin/VBox/SpinBtn
@onready var _ad_btn: Button = $Panel/Margin/VBox/AdBtn
@onready var _back_btn: Button = $Panel/Margin/VBox/BackBtn

var _phase: int = Phase.READY


func _ready() -> void:
	layer = 11
	visible = false
	_apply_theme()
	_spin_btn.pressed.connect(_on_spin_pressed)
	_ad_btn.pressed.connect(_on_ad_pressed)
	_back_btn.pressed.connect(close)
	_wheel.stopped.connect(_on_wheel_stopped)


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
	GameTheme.apply_overlay_cta(_ad_btn, false)
	GameTheme.apply_overlay_cta(_back_btn, false)


func open() -> void:
	visible = true
	_status.text = ""
	_stage_round()
	if not GameState.stats_changed.is_connected(_refresh):
		GameState.stats_changed.connect(_refresh)
	_refresh()


func close() -> void:
	_wheel.reset()
	if GameState.stats_changed.is_connected(_refresh):
		GameState.stats_changed.disconnect(_refresh)
	visible = false


func _stage_round() -> void:
	var segs: Array = GameState.start_gamble_round()
	_wheel.set_segments(segs)
	_wheel.reset()
	_phase = Phase.READY if not segs.is_empty() else Phase.DONE


func _refresh() -> void:
	var spins: int = GameState.gambling_free_spins()
	_spins.text = "Spins: %d" % spins
	match _phase:
		Phase.SWEEPING:
			_prompt.text = "STOP on a high multiplier — timing is everything."
			_spin_btn.text = "STOP"
			_spin_btn.disabled = false
			_ad_btn.visible = false
		_:
			if spins > 0:
				_prompt.text = "Tap SPIN, then STOP the marker on a high slot."
				_spin_btn.text = "SPIN AGAIN" if _phase == Phase.DONE else "SPIN"
				_spin_btn.disabled = false
				_ad_btn.visible = false
			else:
				_no_spins_state()


func _no_spins_state() -> void:
	_prompt.text = "No spins left — come back tomorrow for a free spin."
	_spin_btn.text = "SPIN"
	_spin_btn.disabled = true
	_ad_btn.visible = not GameState.remove_ads and GameState.gambling_free_spins() < _Gambling.FREE_SPIN_CAP
	_ad_btn.text = "Watch ad  +1 spin"


func _on_spin_pressed() -> void:
	if _phase == Phase.SWEEPING:
		_wheel.stop_sweep()  # → _on_wheel_stopped resolves the spin
		return
	if GameState.gambling_free_spins() <= 0:
		return
	if _phase == Phase.DONE or not _wheel.has_round():
		_stage_round()  # fresh shuffled ring per spin
	if not _wheel.has_round():
		return
	_status.text = ""
	_wheel.start_sweep()
	_phase = Phase.SWEEPING
	_refresh()


func _on_wheel_stopped(position: float) -> void:
	_status.text = GameState.resolve_gamble(position)
	_phase = Phase.DONE
	_refresh()


func _on_ad_pressed() -> void:
	# Rewarded-ad hook. A real build routes through the Monetization autoload's
	# rewarded-ad callback; granting directly here keeps the flow testable and the
	# +1 stays capped at FREE_SPIN_CAP inside GamblingSystem.
	if GameState.grant_gamble_ad_spin():
		_status.text = "+1 spin"
		_stage_round()
		_refresh()
