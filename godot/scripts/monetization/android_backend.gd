extends RefCounted
## Android native plugin wrapper — Poing AdMob (`MobileAds`) + Play Billing (`BillingClient`).

signal ad_loaded(placement: String)
signal ad_rewarded(placement: String)
signal ad_failed(placement: String, reason: String)
signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal products_queried(products: Array)

const PLUGIN_BILLING_CLASS := "BillingClient"
# Device-only helper. load()ed lazily so its Poing-AdMob class deps are never
# instantiated off-device (desktop/editor use MockBackend).
const ADMOB_HELPER_PATH := "res://scripts/monetization/admob_rewarded.gd"

var _admob: RefCounted = null  # AdMobRewarded helper instance (Android only)
var _billing: Object = null
var _billing_ready := false


func _init() -> void:
	if OS.get_name() == "Android":
		var helper_script := load(ADMOB_HELPER_PATH)
		if helper_script != null:
			_admob = helper_script.new()
			_admob.loaded.connect(func(p): ad_loaded.emit(p))
			_admob.rewarded.connect(func(p): ad_rewarded.emit(p))
			_admob.failed.connect(func(p, r): ad_failed.emit(p, r))
			_admob.initialize()
	if ClassDB.class_exists(PLUGIN_BILLING_CLASS):
		_billing = ClassDB.instantiate(PLUGIN_BILLING_CLASS)
		_wire_billing(_billing)


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
	if _billing == null or not _billing_ready:
		products_queried.emit(Monetization.PRODUCT_IDS.duplicate())
		return
	if _billing.has_method("query_product_details"):
		# BillingClient.ProductType.INAPP — use 0 so editor works without addon loaded.
		_billing.query_product_details(Monetization.PRODUCT_IDS, 0)
	else:
		products_queried.emit(Monetization.PRODUCT_IDS.duplicate())


func purchase(product_id: String) -> void:
	if _billing == null or not _billing_ready:
		purchase_failed.emit(product_id, "billing_unavailable")
		return
	if _billing.has_method("purchase"):
		_billing.purchase(product_id)
	else:
		purchase_failed.emit(product_id, "billing_no_purchase_method")


func restore() -> void:
	if _billing == null or not _billing_ready:
		return
	if _billing.has_method("query_purchases"):
		_billing.query_purchases(0)


func _wire_billing(client: Object) -> void:
	if client == null:
		return
	if client.has_signal("connected"):
		client.connected.connect(_on_billing_connected)
	if client.has_signal("on_purchase_updated"):
		client.on_purchase_updated.connect(_on_purchase_updated)
	if client.has_signal("connect_error"):
		client.connect_error.connect(_on_billing_connect_error)
	if client.has_method("start_connection"):
		client.start_connection()


func _on_billing_connected() -> void:
	_billing_ready = true
	products_queried.emit(Monetization.PRODUCT_IDS.duplicate())


func _on_billing_connect_error(_code: int, reason: String) -> void:
	_billing_ready = false
	if OS.is_debug_build():
		print("[Monetization:android] billing connect_error: %s" % reason)


func _on_purchase_updated(response: Dictionary) -> void:
	var purchases: Array = response.get("purchases", [])
	for purchase_data in purchases:
		var pid: String = str(purchase_data.get("product_id", ""))
		if pid.is_empty():
			continue
		purchase_completed.emit(pid)
