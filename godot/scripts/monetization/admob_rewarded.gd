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

# Rewarded ad units. DEBUG builds (editor + sideloaded debug APK) use Google's
# public TEST unit — always fills, safe to click. RELEASE builds use the real unit,
# so you can never accidentally click a live ad during development (= AdMob ban).
# App ID (real): ca-app-pub-7658776587792417~1656634507 — set in
# addons/admob/android/config.gd (gitignored) and injected into the manifest by Poing.
const TEST_REWARDED_UNIT := "ca-app-pub-3940256099942544/5224354917"
const REAL_REWARDED_UNIT := "ca-app-pub-7658776587792417/4834260941"


func _rewarded_unit() -> String:
	return TEST_REWARDED_UNIT if OS.is_debug_build() else REAL_REWARDED_UNIT

var _ad: RewardedAd = null
var _ready := false
var _warming := false
var _ads_started := false


func initialize() -> void:
	# Compliance (B1): simulated-gambling + crime theme → cap ad maturity and never
	# declare child-directed. Set before init so the first request honours it.
	var cfg := RequestConfiguration.new()
	cfg.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_MA
	cfg.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.FALSE
	cfg.tag_for_under_age_of_consent = RequestConfiguration.TagForUnderAgeOfConsent.FALSE
	MobileAds.set_request_configuration(cfg)
	# GDPR/CCPA (B2): resolve UMP consent BEFORE starting the ads SDK, so EU/California
	# users get the consent form and no ad is ever requested pre-consent. UMP ships
	# inside Poing's "ads" library, so it's present whenever AdMob is.
	_request_consent()


# ── UMP consent gate (B2) ────────────────────────────────────────────────────

func _request_consent() -> void:
	# No debug_geography here — forcing EEA would show the form to everyone. Real
	# geography detection applies; the form appears only where legally required.
	var params := ConsentRequestParameters.new()
	params.tag_for_under_age_of_consent = false
	UserMessagingPlatform.consent_information.update(
		params, _on_consent_updated, _on_consent_failed)


func _on_consent_updated() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_form_loaded, _on_form_failed)
	else:
		_start_ads()


func _on_consent_failed(_error: FormError) -> void:
	# Consent lookup failed (e.g. no network). Proceed — the SDK falls back to
	# non-personalized ads until consent can be gathered on a later launch.
	_start_ads()


func _on_form_loaded(form: ConsentForm) -> void:
	if UserMessagingPlatform.consent_information.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		form.show(_on_form_dismissed)
	else:
		_start_ads()


func _on_form_failed(_error: FormError) -> void:
	_start_ads()


func _on_form_dismissed(_error: FormError) -> void:
	# User has now answered (or the form errored). The SDK reads the stored consent.
	_start_ads()


func _start_ads() -> void:
	if _ads_started:
		return
	_ads_started = true
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
	loader.load(_rewarded_unit(), AdRequest.new(), cb)


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
