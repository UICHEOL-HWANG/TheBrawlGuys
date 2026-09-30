class_name LoginText
extends RefCounted
## Login card strings in Korean and English (design.md DS-CMP-14 language link). A stub until
## the game gets real localization: the card flips its own labels; status messages come from the
## caller already translated.

const KO := "ko"
const EN := "en"
const TITLE := "The Brawl Guys"
const TEXT := {
	KO: {
		"tagline": "치고, 날리고, 끝까지 버티기", "google": "Google로 시작하기", "retry": "다시 시도",
		"loading": "로그인 중…", "helper": "로그인하면 어느 기기에서든 기록이 이어집니다.",
		"language": "English", "skip": "건너뛰기 (디버그)",
		"email": "이메일로 계속하기", "email_title": "이메일로 로그인",
		"email_helper": "입력한 주소로 6자리 인증코드를 보내 드려요", "email_placeholder": "이메일 주소",
		"email_send": "인증코드 받기", "email_sending": "보내는 중…",
		"code_helper": "%s\n메일로 받은 6자리 코드를 입력해 주세요", "code_submit": "로그인", "code_checking": "확인 중…",
		"resend": "코드 다시 받기", "resend_wait": "코드 다시 받기 (%d초)", "back": "← 다른 방법으로",
	},
	EN: {
		"tagline": "punch · launch · last one standing", "google": "Continue with Google", "retry": "Try again",
		"loading": "Signing in…", "helper": "Sign in to keep your records on every device.",
		"language": "한국어", "skip": "Skip (debug)",
		"email": "Continue with email", "email_title": "Sign in with email",
		"email_helper": "We'll send a 6-digit code to this address", "email_placeholder": "Email address",
		"email_send": "Send code", "email_sending": "Sending…",
		"code_helper": "%s\nEnter the 6-digit code from the mail", "code_submit": "Sign in", "code_checking": "Checking…",
		"resend": "Resend code", "resend_wait": "Resend code (%ds)", "back": "← Other ways to sign in",
	},
}


static func of(lang: String, key: String) -> String:
	var table: Dictionary = TEXT.get(lang, TEXT[KO])
	return String(table.get(key, ""))


## The other language (what the language link switches to).
static func other(lang: String) -> String:
	return EN if lang == KO else KO
