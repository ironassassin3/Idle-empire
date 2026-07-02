extends RefCounted
## Android native plugin wrapper — Poing AdMob (`MobileAds`) + Play Billing (`BillingClient`).

signal ad_loaded(placement: String)
signal ad_rewarded(placement: String)
signal ad_failed(placement: String, reason: String)
signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal products_queried(products: Array)

# Device-only helpers. load()ed lazily so their plugin class deps (Poing AdMob /
# GodotGooglePlayBilling) are never instantiated off-device — desktop/editor use
# MockBackend and never touch these paths.
const ADMOB_HELPER_PATH := "res://scripts/monetization/admob_rewarded.gd"
const BILLING_HELPER_PATH := "res://scripts/monetization/play_billing.gd"

var _admob: RefCounted = null    # AdMobRewarded helper (Android only)
var _billing: RefCounted = null  # PlayBilling helper (Android only)


func _init() -> void:
	if OS.get_name() != "Android":
		return
	var admob_script := load(ADMOB_HELPER_PATH)
	if admob_script != null:
		_admob = admob_script.new()
		_admob.loaded.connect(func(p): ad_loaded.emit(p))
		_admob.rewarded.connect(func(p): ad_rewarded.emit(p))
		_admob.failed.connect(func(p, r): ad_failed.emit(p, r))
		_admob.initialize()
	var billing_script := load(BILLING_HELPER_PATH)
	if billing_script != null:
		var b = billing_script.new()
		if b.available():
			_billing = b
			_billing.purchase_completed.connect(func(pid): purchase_completed.emit(pid))
			_billing.purchase_failed.connect(func(pid, r): purchase_failed.emit(pid, r))
			_billing.products_ready.connect(func(items): products_queried.emit(items))


func is_available() -> bool:
	return _admob != null or _billing != null


func load_rewarded(placement: String) -> void:
	if _admob == null:
		ad_failed.emit(placement, "admob_unavailable")
		return
	_admob.warm()


func show_rewarded(placement: String) -> void:
	if _admob == null:
		ad_failed.emit(placement, "admob_unavailable")
		return
	_admob.show(placement)


func show_interstitial(_trigger: String) -> void:
	if _admob == null:
		return
	pass


func query_products() -> void:
	if _billing == null:
		products_queried.emit(Monetization.PRODUCT_IDS.duplicate())
		return
	_billing.query_products()


func purchase(product_id: String) -> void:
	if _billing == null:
		purchase_failed.emit(product_id, "billing_unavailable")
		return
	_billing.purchase(product_id)


func restore() -> void:
	if _billing != null:
		_billing.restore()
