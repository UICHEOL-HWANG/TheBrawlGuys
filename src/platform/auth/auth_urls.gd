class_name AuthUrls
extends RefCounted
## Supabase Auth URLs (platform A4): the provider authorize URL with a PKCE challenge and the
## desktop loopback redirect. Both redirect targets must be allowed in Supabase Auth settings.

const LOOPBACK_HOST := "127.0.0.1"
const CALLBACK_PATH := "/callback"


static func authorize(supabase_url: String, provider: String, redirect_to: String, code_challenge: String) -> String:
	return "%s/auth/v1/authorize?provider=%s&redirect_to=%s&code_challenge=%s&code_challenge_method=s256" % [
		supabase_url.trim_suffix("/"), provider.uri_encode(), redirect_to.uri_encode(), code_challenge]


static func loopback_redirect(port: int) -> String:
	return "http://%s:%d%s" % [LOOPBACK_HOST, port, CALLBACK_PATH]
