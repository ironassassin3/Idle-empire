class_name DecoMotion
extends RefCounted
## Deco motion vocabulary — timing tokens + tween primitives shared by every
## moment-to-moment effect, so motion composes instead of scattering ad-hoc
## tweens. Spec: docs/superpowers/specs/2026-07-15-deco-motion-design.md.
## Reads GameState.show_particles directly (NOT GameTheme.ui_reduced_motion):
## GameTheme calls attach_press, so GameTheme -> DecoMotion -> GameTheme would
## be a class_name cycle.

const T_FAST := 0.12  # press, flash — sub-perception "snap"
const T_MED := 0.25   # state wipes, sheens
const T_ARC := 0.45   # travel (coin arc)
const EASE := Tween.EASE_OUT
const TRANS := Tween.TRANS_CUBIC


static func _reduced() -> bool:
	return not GameState.show_particles


## Depress on button_down (scale 0.96), release ease-out on button_up.
## `pressed` fires on RELEASE — hooking it would mean the button never
## visibly sinks. Pivot must be centered or container buttons scale lopsided.
## Idempotent: apply_row_buy_button runs on every row rebuild.
static func attach_press(btn: BaseButton) -> void:
	if btn == null or btn.has_meta("deco_press"):
		return
	btn.set_meta("deco_press", true)
	btn.pivot_offset = btn.size * 0.5
	btn.resized.connect(DecoMotion._press_pivot.bind(btn))
	btn.button_down.connect(DecoMotion._press_down.bind(btn))
	btn.button_up.connect(DecoMotion._press_up.bind(btn))


static func _press_pivot(btn: BaseButton) -> void:
	btn.pivot_offset = btn.size * 0.5


static func _press_down(btn: BaseButton) -> void:
	if _reduced():
		return
	btn.scale = Vector2(0.96, 0.96)


static func _press_up(btn: BaseButton) -> void:
	if btn.scale.is_equal_approx(Vector2.ONE):
		return
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, T_FAST).set_ease(EASE).set_trans(TRANS)
