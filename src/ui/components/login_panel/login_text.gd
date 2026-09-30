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
	},
	EN: {
		"tagline": "punch · launch · last one standing", "google": "Continue with Google", "retry": "Try again",
		"loading": "Signing in…", "helper": "Sign in to keep your records on every device.",
		"language": "한국어", "skip": "Skip (debug)",
	},
}


static func of(lang: String, key: String) -> String:
	var table: Dictionary = TEXT.get(lang, TEXT[KO])
	return String(table.get(key, ""))


## The other language (what the language link switches to).
static func other(lang: String) -> String:
	return EN if lang == KO else KO
