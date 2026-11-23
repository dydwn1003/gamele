extends RefCounted
## OfflineManager
## 오프라인 수익 = 최근 정상 영업 분당 평균 순수익 × 오프라인 시간(분, 최대 240) × 0.35
##
## 악용/중복 방지
## - max_seen_unix (지금까지 본 가장 늦은 시각)를 기준으로 경과 시간을 계산한다.
##   시스템 시각을 과거로 돌리면 경과 시간이 음수 → 보상 없음, 기준 시각도 내려가지 않는다.
## - 계산 직후 기준 시각을 현재로 갱신하므로 같은 구간이 두 번 계산되지 않는다.
## - 미수령 보상(pending)은 세이브에 기록되며 누적 분은 최대 240분으로 제한된다.
## - claim() 은 pending 을 0 으로 만든 뒤 지급 기록을 남긴다 (한 번만 지급).
## TODO: 시각 앞당기기(미래로 변경)는 로컬만으로 완전히 막을 수 없다 → 서버 시간 검증 도입 시 보완.

var state
var data


func setup(p_state, p_data) -> void:
	state = p_state
	data = p_data


func efficiency() -> float:
	return float(data.bal("offline_efficiency", 0.35))


func max_minutes() -> float:
	return float(data.bal("offline_max_minutes", 240.0))


## 플레이 중 주기적으로 호출: 현재 시각을 "본 시각"으로 기록.
func touch(now_unix: float) -> void:
	if now_unix >= state.max_seen_unix:
		state.max_seen_unix = now_unix
		state.last_seen_unix = now_unix


## 앱 시작/복귀 시 호출. 새로 쌓인 보상 정보를 반환.
## {"added": int, "pending_amount": int, "pending_minutes": float, "rollback": bool}
func compute_pending(now_unix: float) -> Dictionary:
	var ref := maxf(state.last_seen_unix, state.max_seen_unix)
	var info := {"added": 0, "pending_amount": int(state.offline["pending_amount"]),
		"pending_minutes": float(state.offline["pending_minutes"]), "rollback": false}
	if ref <= 0.0:
		touch(now_unix)
		return info
	var elapsed := now_unix - ref
	if elapsed < 0.0:
		# 시스템 시각이 과거로 변경됨: 보상 없음, 기준 시각 유지
		state.offline["clock_rollback_detected"] = true
		info["rollback"] = true
		return info
	touch(now_unix)
	var minutes := elapsed / 60.0
	if minutes < float(data.bal("offline_min_minutes", 1.0)):
		return info
	var per_min := maxf(0.0, float(state.last_session.get("per_minute", 0.0)))
	if per_min <= 0.0:
		return info
	var prev_amount := int(state.offline["pending_amount"])
	var total_minutes := minf(max_minutes(), float(state.offline["pending_minutes"]) + minutes)
	var total_amount := int(floor(per_min * total_minutes * efficiency()))
	total_amount = maxi(prev_amount, total_amount)
	state.offline["pending_minutes"] = total_minutes
	state.offline["pending_amount"] = total_amount
	info["added"] = total_amount - prev_amount
	info["pending_amount"] = total_amount
	info["pending_minutes"] = total_minutes
	return info


static func calculate(per_minute: float, minutes: float, eff: float, cap_minutes: float) -> int:
	return int(floor(maxf(0.0, per_minute) * clampf(minutes, 0.0, cap_minutes) * eff))


func has_pending() -> bool:
	return int(state.offline.get("pending_amount", 0)) > 0


## 보상 수령. 반환값: 지급된 코인 (이미 받았으면 0)
func claim(economy, now_unix: float, multiplier: float = 1.0) -> int:
	var amount := int(state.offline.get("pending_amount", 0))
	if amount <= 0:
		return 0
	var paid := int(floor(amount * maxf(1.0, multiplier)))
	state.offline["pending_amount"] = 0
	state.offline["pending_minutes"] = 0.0
	state.offline["last_claim_unix"] = now_unix
	state.offline["last_claim_amount"] = paid
	state.offline["total_claimed"] = int(state.offline.get("total_claimed", 0)) + paid
	state.offline["claim_count"] = int(state.offline.get("claim_count", 0)) + 1
	economy.earn(paid)
	return paid
