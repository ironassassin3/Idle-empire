extends RefCounted
## Editor/headless monetization backend — instant fake ads and purchases.

signal ad_loaded(placement: String)
signal ad_rewarded(placement: String)
signal ad_failed(placement: String, reason: String)
signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal products_queried(products: Array)


func load_rewarded(_placement: String) -> void:
	ad_loaded.emit(_placement)


func show_rewarded(placement: String) -> void:
	# Simulate a short ad; reward immediately in mock mode.
	ad_rewarded.emit(placement)


func show_interstitial(_trigger: String) -> void:
	pass


func query_products() -> void:
	products_queried.emit(Monetization.PRODUCT_IDS.duplicate())


func purchase(product_id: String) -> void:
	if product_id in Monetization.PRODUCT_IDS:
		purchase_completed.emit(product_id)
	else:
		purchase_failed.emit(product_id, "unknown_product")


func restore() -> void:
	for pid in GameState.entitlements:
		purchase_completed.emit(str(pid))
