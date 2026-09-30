class_name AuthUrls
extends RefCounted
## Supabase Auth URLs (platform A4): the provider authorize URL with a PKCE challenge and the
## desktop loopback redirect. Both redirect targets must be allowed in Supabase Auth settings.
## The loopback redirect carries a per-sign-in `state` nonce (B1 hardening): Supabase keeps the
## query of redirect_to and appends ?code=, so the callback proves it belongs to this sign-in.

const LOOPBACK_HOST := "127.0.0.1"
const CALLBACK_PATH := "/callback"
const STATE_PARAM := "state"
const STATE_LENGTH := 32


static func authorize(supabase_url: String, provider: String, redirect_to: String, code_challenge: String) -> String:
	return "%s/auth/v1/authorize?provider=%s&redirect_to=%s&code_challenge=%s&code_challenge_method=s256" % [
		supabase_url.trim_suffix("/"), provider.uri_encode(), redirect_to.uri_encode(), code_challenge]


static func loopback_redirect(port: int, state: String = "") -> String:
	var url := "http://%s:%d%s" % [LOOPBACK_HOST, port, CALLBACK_PATH]
	return url if state.is_empty() else "%s?%s=%s" % [url, STATE_PARAM, state]


## Random URL-safe nonce (same unreserved alphabet as the PKCE verifier).
static func new_state() -> String:
	return Pkce.verifier_from_bytes(Crypto.new().generate_random_bytes(STATE_LENGTH))
