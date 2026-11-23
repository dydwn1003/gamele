extends RefCounted
## PurchaseService — 인앱 결제 인터페이스.
## 첫 프로토타입은 실제 결제를 구현하지 않는다. SDK가 없으면 모든 구매 요청은 실패한다.
## (가짜 결제 성공 금지)
##
## TODO(결제): Google Play Billing(GodotGooglePlayBilling) / StoreKit 플러그인 연결 →
##   1) purchase() 에서 플랫폼 결제 시작
##   2) 플랫폼 영수증(purchase token)을 서버로 전송해 서버 측 영수증 검증
##   3) 서버 검증 성공 응답에서만 _grant() 호출 → 지급 후 acknowledge/consume

signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, reason: String)

var products: Array = []
var _billing = null


func setup(bm_data: Dictionary) -> void:
	products = bm_data.get("products", [])
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing = Engine.get_singleton("GodotGooglePlayBilling") # TODO: 실제 초기화


func is_available() -> bool:
	return false # TODO: _billing 연결 및 서버 검증 구현 후 true


func status_text() -> String:
	return "결제 준비 중 (테스트 빌드)"


func purchase(product_id: String) -> void:
	purchase_failed.emit(product_id, "결제 기능이 아직 연결되지 않았습니다.")


## 서버 검증을 통과한 영수증만 이 함수에 도달해야 한다.
func _on_server_verified(product_id: String) -> void:
	purchase_completed.emit(product_id)
