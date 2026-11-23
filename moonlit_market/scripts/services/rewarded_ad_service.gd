extends RefCounted
## RewardedAdService — 선택형 보상 광고 인터페이스.
## 실제 광고 SDK(AdMob 등)가 연결되지 않은 상태에서는 is_available() 이 false 이며,
## 절대로 보상이 지급된 것처럼 동작하지 않는다.
## 디버그 빌드 + balance.debug_rewards_enabled 일 때만 "[테스트]" 보상을 제공한다.
## 출시 빌드(OS.is_debug_build() == false)에서는 테스트 보상이 자동으로 비활성화된다.
##
## TODO(SDK): AdMob Godot 플러그인 연결 → _sdk 에 싱글톤 할당, show() 에서 실제 광고 호출,
##            보상 콜백은 SDK 의 onUserEarnedReward 에서만 호출.

signal reward_granted(placement: String)
signal reward_failed(placement: String, reason: String)

var debug_enabled: bool = false
var _sdk = null


func setup(debug_rewards_allowed: bool) -> void:
	debug_enabled = debug_rewards_allowed and OS.is_debug_build()
	if Engine.has_singleton("GodotAdMob"):
		_sdk = Engine.get_singleton("GodotAdMob") # TODO: 실제 초기화


func has_sdk() -> bool:
	return _sdk != null


func is_available(_placement: String) -> bool:
	return has_sdk() or debug_enabled


func status_text() -> String:
	if has_sdk():
		return "광고 준비됨"
	if debug_enabled:
		return "디버그 테스트 보상"
	return "광고 준비 중 (SDK 미연결)"


## 광고 표시 요청. 결과는 시그널로만 전달된다.
func show(placement: String) -> void:
	if has_sdk():
		# TODO(SDK): 실제 광고 표시. 현재는 SDK 미구현이므로 실패 처리.
		reward_failed.emit(placement, "광고 SDK 연동이 아직 구현되지 않았습니다.")
		return
	if debug_enabled:
		reward_granted.emit(placement)
		return
	reward_failed.emit(placement, "광고를 사용할 수 없습니다.")
