extends RefCounted
## Real AdMob rewarded-ad flow (Poing AdMob v4).
##
## Instantiated ONLY on Android by android_backend.gd, so the Poing class deps
## (MobileAds / RewardedAdLoader / RewardedAd / RequestConfiguration) are exercised
## only on device. Desktop + editor use MockBackend and never load this script.
##
## Single-slot design: keep one rewarded ad warmed; show() serves it and immediately
## warms the next. AdMob requires load-then-show, but the callers (gambling / offline
## / coin) call show directly — the warm loop bridges that.

signal loaded(placement: String)
signal rewarded(placement: String)
signal failed(placement: String, reason: String)

# Google public TEST rewarded unit (Android) — always fills, safe to click.
# Swap for your real ca-app-pub-…/… unit(s) at launch. The App ID lives in
# addons/admob/android/config.gd (APPLICATION_ID) and is injected into the manifest
# by Poing's Android export plugin.
const TEST_REWARDED_UNIT := "ca-app-pub-3940256099942544/5224354917"

var _ad: RewardedAd = null
var _ready := false
var _warming := false


func initialize() -> void:
	# Compliance (B1): simulated-gambling + crime theme → cap ad maturity and never
	# declare child-directed. Set before initialize so the first request honours it.
	var cfg := RequestConfiguration.new()
	cfg.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_MA
	cfg.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.FALSE
	cfg.tag_for_under_age_of_consent = RequestConfiguration.TagForUnderAgeOfConsent.FALSE
	MobileAds.set_request_configuration(cfg)
	MobileAds.initialize()
	_warm()


func has_ready_ad() -> bool:
	return _ready and _ad != null


func warm() -> void:
	_warm()


func _warm() -> void:
	if _warming or _ready:
		return
	_warming = true
	var loader := RewardedAdLoader.new()
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_ad = ad
		_ready = true
		_warming = false
		loaded.emit("")
	cb.on_ad_failed_to_load = func(_err) -> void:
		_ad = null
		_ready = false
		_warming = false
		failed.emit("", "load_failed")
	loader.load(TEST_REWARDED_UNIT, AdRequest.new(), cb)


func show(placement: String) -> void:
	if not has_ready_ad():
		failed.emit(placement, "not_ready")
		_warm()
		return
	var ad := _ad
	# Release the slot up front so a re-entrant show can't serve the same ad twice.
	_ready = false
	_ad = null
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item) -> void:
		rewarded.emit(placement)
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_warm()  # preload the next one
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err) -> void:
		ad.destroy()
		failed.emit(placement, "show_failed")
		_warm()
	ad.show(listener)
