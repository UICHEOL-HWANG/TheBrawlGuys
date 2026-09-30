class_name LoginMessages
extends RefCounted
## One-line Korean messages for the login screen (design.md DS-CMP-14 error state): why sign-in
## is unavailable here, the cause of a failed attempt (AuthService / LoginGate reasons) and the
## email code results (EmailOtp.RESULT_*).

const RESTORING := "로그인 정보를 확인하고 있어요"
const WAITING := "브라우저에서 Google 로그인을 마쳐 주세요"
## Only Google waits for mobile deep links; email codes work on mobile.
const MOBILE := "모바일은 Google 로그인을 준비 중이에요 · 이메일로 계속해 주세요"
const CODE_SENT := "메일로 인증코드를 보냈어요 · 받은편지함을 확인해 주세요"
const INVALID_EMAIL := "잘못된 이메일이에요 · 주소를 다시 확인해 주세요"
const INVALID_CODE := "6자리 숫자 코드를 입력해 주세요"
const WRONG_CODE := "코드가 틀렸거나 만료됐어요"
const RATE_LIMITED := "잠시 후 다시 시도해 주세요"
const EMAIL_FAILED := "연결하지 못했어요 · 잠시 후 다시 시도해 주세요"
const BY_EMAIL_RESULT := {
	"invalid_email": INVALID_EMAIL, "invalid_code": INVALID_CODE, "wrong_code": WRONG_CODE,
	"rate_limited": RATE_LIMITED, "error": EMAIL_FAILED,
}
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


## Message for an email code result ("" for ok / busy).
static func for_email(result: String) -> String:
	if BY_EMAIL_RESULT.has(result):
		return String(BY_EMAIL_RESULT[result])
	return unavailable(result)


static func for_failure(reason: String) -> String:
	if BY_REASON.has(reason):
		return String(BY_REASON[reason])
	for prefix: String in PREFIXES:
		if reason.begins_with(prefix):
			return String(PREFIXES[prefix])
	var why := unavailable(reason)
	return why if not why.is_empty() else FALLBACK
