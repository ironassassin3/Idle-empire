extends RefCounted
## Real Google Play Billing (GodotGooglePlayBilling plugin).
##
## Instantiated ONLY on Android by android_backend.gd; desktop/editor use
## MockBackend. BillingClient is a GDScript class (class_name … extends Node), so it
## must be constructed with .new() — NOT ClassDB.instantiate (that only finds native
## classes, which is why the old scaffold never activated billing on device).
##
## All three products (remove_ads, starter_pack, income_x2) are one-time
## NON-consumable entitlements → acknowledge on purchase. Unacknowledged purchases
## are auto-refunded by Google after ~3 days, so acknowledgement is mandatory.
##
## The native response Dictionary keys ("purchases", "products", "purchase_token",
## "purchase_state", "is_acknowledged") are parsed defensively and the raw response is
## logged in debug builds — verify against the real device response and tighten later.

signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal products_ready(products: Array)

var _client: BillingClient = null
var _ready := false


func _init() -> void:
	if not Engine.has_singleton("GodotGooglePlayBilling"):
		return  # native plugin absent → helper stays inert, backend falls back
	_client = BillingClient.new()
	_client.connected.connect(_on_connected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_products)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.query_purchases_response.connect(_on_purchase_updated)  # restore reuses the same apply+ack
	_client.start_connection()


func available() -> bool:
	return _client != null


func _on_connected() -> void:
	_ready = true
	query_products()


func _on_connect_error(_code: int, reason: String) -> void:
	_ready = false
	if OS.is_debug_build():
		print("[Billing] connect_error: %s" % reason)


func query_products() -> void:
	if _ready and _client:
		_client.query_product_details(PackedStringArray(Monetization.PRODUCT_IDS), BillingClient.ProductType.INAPP)


func _on_products(response: Dictionary) -> void:
	if OS.is_debug_build():
		print("[Billing] products: %s" % str(response))
	products_ready.emit(response.get("product_details", response.get("products", [])))


func purchase(product_id: String) -> void:
	if not _ready or _client == null:
		purchase_failed.emit(product_id, "billing_unavailable")
		return
	var res: Dictionary = _client.purchase(product_id)
	var code := int(res.get("response_code", res.get("status", BillingClient.BillingResponseCode.OK)))
	# Already owned → run restore so the entitlement re-applies. Otherwise the real
	# outcome arrives asynchronously via on_purchase_updated, so don't fail here.
	if code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
		restore()


func restore() -> void:
	if _ready and _client:
		_client.query_purchases(BillingClient.ProductType.INAPP)


func _on_purchase_updated(response: Dictionary) -> void:
	if OS.is_debug_build():
		print("[Billing] purchase_updated: %s" % str(response))
	for entry in response.get("purchases", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var state := int(entry.get("purchase_state", BillingClient.PurchaseState.PURCHASED))
		if state != BillingClient.PurchaseState.PURCHASED:
			continue  # ignore PENDING / unspecified — no entitlement until PURCHASED
		var pid := _product_id_of(entry)
		if pid.is_empty():
			continue
		var token := str(entry.get("purchase_token", ""))
		var acked := bool(entry.get("is_acknowledged", entry.get("acknowledged", false)))
		if not acked and not token.is_empty():
			_client.acknowledge_purchase(token)  # mandatory or Google auto-refunds
		purchase_completed.emit(pid)


func _product_id_of(entry: Dictionary) -> String:
	var products = entry.get("products", null)
	if products is Array and not (products as Array).is_empty():
		return str(products[0])
	return str(entry.get("product_id", ""))
