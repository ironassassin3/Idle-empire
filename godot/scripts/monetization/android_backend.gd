extends RefCounted
## Android native plugin wrapper — activated when AdMob/Billing singletons exist.

signal ad_loaded(placement: String)
signal ad_rewarded(placement: String)
signal ad_failed(placement: String, reason: String)
signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal products_queried(products: Array)

var _admob: Object = null
var _billing: Object = null


func _init() -> void:
	if Engine.has_singleton("GodotAdMob"):
		_admob = Engine.get_singleton("GodotAdMob")
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing = Engine.get_singleton("GodotGooglePlayBilling")


func is_available() -> bool:
	return _admob != null or _billing != null


func load_rewarded(placement: String) -> void:
	if _admob == null:
		ad_failed.emit(placement, "admob_unavailable")
		return
	# Plugin-specific load call — wire when §5 plugins are installed.
	ad_loaded.emit(placement)


func show_rewarded(placement: String) -> void:
	if _admob == null:
		ad_failed.emit(placement, "admob_unavailable")
		return
	ad_rewarded.emit(placement)


func show_interstitial(_trigger: String) -> void:
	if _admob == null:
		return
	pass


func query_products() -> void:
	if _billing == null:
		products_queried.emit(Monetization.PRODUCT_IDS.duplicate())
		return
	products_queried.emit(Monetization.PRODUCT_IDS.duplicate())


func purchase(product_id: String) -> void:
	if _billing == null:
		purchase_failed.emit(product_id, "billing_unavailable")
		return
	purchase_completed.emit(product_id)


func restore() -> void:
	if _billing == null:
		return
	for pid in GameState.entitlements:
		purchase_completed.emit(str(pid))
