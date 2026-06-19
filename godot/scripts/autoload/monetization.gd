extends Node
## Monetization autoload — ads + IAP with mock-first backend seam.
##
## Decoupled from gameplay via signals. Editor/headless use MockBackend; device
## swaps to AndroidBackend when native plugin singletons are present (§5).

const MockBackend = preload("res://scripts/monetization/mock_backend.gd")
const AndroidBackend = preload("res://scripts/monetization/android_backend.gd")

const PRODUCT_REMOVE_ADS := "remove_ads"
const PRODUCT_STARTER := "starter_pack"
const PRODUCT_INCOME_X2 := "income_x2"
const PRODUCT_IDS := [PRODUCT_REMOVE_ADS, PRODUCT_STARTER, PRODUCT_INCOME_X2]

const PLACEMENT_OFFLINE_DOUBLE := "offline_double"
const PLACEMENT_FREE_COIN := "free_coin"
const PLACEMENT_TIME_SKIP := "time_skip"

const INTERSTITIAL_MIN_SECS := 180.0
const INTERSTITIAL_SESSION_CAP := 3

signal ad_reward_granted(placement: String)
signal ad_failed(placement: String, reason: String)
signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, reason: String)

var _backend: RefCounted
var _enabled := true
var _rewarded_ready: Dictionary = {}
var _pending_placement: String = ""
var _interstitial_count: int = 0
var _last_interstitial_at: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		_enabled = false
		return
	_pick_backend()
	if GameState != null and GameState.has_signal("prestiged"):
		GameState.prestiged.connect(_on_prestiged)


func _pick_backend() -> void:
	var android := AndroidBackend.new()
	if android.is_available():
		_backend = android
	else:
		_backend = MockBackend.new()
	_wire_backend(_backend)


func _wire_backend(backend: RefCounted) -> void:
	if backend.has_signal("ad_loaded"):
		backend.ad_loaded.connect(_on_ad_loaded)
	if backend.has_signal("ad_rewarded"):
		backend.ad_rewarded.connect(_on_ad_rewarded)
	if backend.has_signal("ad_failed"):
		backend.ad_failed.connect(_on_ad_failed)
	if backend.has_signal("purchase_completed"):
		backend.purchase_completed.connect(_on_purchase_completed)
	if backend.has_signal("purchase_failed"):
		backend.purchase_failed.connect(_on_purchase_failed)


func ads_available() -> bool:
	return _enabled and not GameState.remove_ads


func load_rewarded(placement: String) -> void:
	if not _enabled or not ads_available():
		return
	_log_ad_event("ad_opportunity", placement)
	if _backend != null:
		_backend.load_rewarded(placement)


func show_rewarded(placement: String) -> void:
	if not _enabled or not ads_available():
		ad_failed.emit(placement, "ads_disabled")
		return
	_pending_placement = placement
	_log_ad_event("ad_shown", placement)
	if _backend != null:
		_backend.show_rewarded(placement)


func maybe_show_interstitial(trigger: String) -> void:
	if not _enabled or not ads_available():
		return
	if _interstitial_count >= INTERSTITIAL_SESSION_CAP:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_interstitial_at < INTERSTITIAL_MIN_SECS:
		return
	_interstitial_count += 1
	_last_interstitial_at = now
	_log_ad_event("ad_shown", "interstitial:%s" % trigger)
	if _backend != null:
		_backend.show_interstitial(trigger)


func query_products() -> void:
	if not _enabled or _backend == null:
		return
	_backend.query_products()


func purchase(product_id: String) -> void:
	if not _enabled or _backend == null:
		purchase_failed.emit(product_id, "disabled")
		return
	_backend.purchase(product_id)


func restore() -> void:
	if not _enabled or _backend == null:
		return
	_backend.restore()


func product_owned(product_id: String) -> bool:
	return product_id in GameState.entitlements or (
		product_id == PRODUCT_REMOVE_ADS and GameState.remove_ads
	)


func _on_ad_loaded(placement: String) -> void:
	_rewarded_ready[placement] = true


func _on_ad_rewarded(placement: String) -> void:
	_rewarded_ready.erase(placement)
	_log_ad_event("ad_reward", placement)
	ad_reward_granted.emit(placement)
	match placement:
		PLACEMENT_OFFLINE_DOUBLE:
			GameState.grant_offline_ad_double()
		PLACEMENT_FREE_COIN:
			GameState.grant_free_golden_coin()
		PLACEMENT_TIME_SKIP:
			BuffSystem.add_buff(GameState, "syndicate_income", 300.0, 2.0)
			GameState.notification.emit("Time skip! 2× income for 5 min", GameTheme.GOLD)


func _on_ad_failed(placement: String, reason: String) -> void:
	_rewarded_ready.erase(placement)
	ad_failed.emit(placement, reason)


func _on_purchase_completed(product_id: String) -> void:
	_log_iap_event(product_id, true)
	purchase_completed.emit(product_id)
	GameState.apply_iap_entitlement(product_id)


func _on_purchase_failed(product_id: String, reason: String) -> void:
	_log_iap_event(product_id, false, reason)
	purchase_failed.emit(product_id, reason)


func _on_prestiged(_info: Dictionary) -> void:
	maybe_show_interstitial("prestige")


func _log_ad_event(ev: String, placement: String) -> void:
	if Telemetry != null:
		Telemetry.log_event(ev, {"placement": placement})


func _log_iap_event(product_id: String, ok: bool, reason: String = "") -> void:
	if Telemetry == null:
		return
	var props := {"product_id": product_id, "ok": ok}
	if not reason.is_empty():
		props["reason"] = reason
	Telemetry.log_event("iap_purchase", props)
