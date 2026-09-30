class_name LoginMessages
extends RefCounted
## One-line Korean messages for the login screen (design.md DS-CMP-14 error state): why sign-in
## is unavailable here, and the cause of a failed attempt (AuthService / LoginGate reasons).

const RESTORING := "로그인 정보를 확인하고 있어요"
const WAITING := "브라우저에서 Google 로그인을 마쳐 주세요"
const MOBILE := "모바일 로그인은 준비 중이에요"
const NOT_CONFIGURED := "로그인 설정이 없어요 (config/secrets.local.cfg)"
const FALLBACK := "로그인하지 못했어요 · 다시 시도해 주세요"
const BY_REASON := {
	"timeout": "시간이 지나 로그인이 취소됐어요",
	"access_denied": "로그인이 취소됐어요",
	"loopback_port_busy": "로그인 포트가 사용 중이에요 · 다른 창을 닫고 다시 시도해 주세요",
	"browser_open_failed": "브라우저를 열 수 없어요",
	"missing_code": "로그인 응답이 비어 있어요 · 다시 시도해 주세요",
	"missing_verifier": "로그인 정보가 사라졌어요 · 다시 시도해 주세요",
}
const PREFIXES := {
	"exchange_": "로그인을 확인하지 못했어요 · 다시 시도해 주세요",
	"refresh_": "저장된 로그인을 갱신하지 못했어요 · 다시 로그인해 주세요",
}


## Message for a LoginGate.availability() reason ("" = available).
static func unavailable(reason: String) -> String:
	match reason:
		LoginGate.REASON_MOBILE:
			return MOBILE
		LoginGate.REASON_NOT_CONFIGURED:
			return NOT_CONFIGURED
	return ""


static func for_failure(reason: String) -> String:
	if BY_REASON.has(reason):
		return String(BY_REASON[reason])
	for prefix: String in PREFIXES:
		if reason.begins_with(prefix):
			return String(PREFIXES[prefix])
	var why := unavailable(reason)
	return why if not why.is_empty() else FALLBACK
