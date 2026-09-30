extends GutTest
## Google OAuth through Supabase with PKCE (platform A4, PRD-AUTH-01): verifier, challenge,
## authorize URL, loopback request line and web query parsing.

## Reference challenge computed independently (Python hashlib + urlsafe_b64encode, no padding).
const VERIFIER := "dBjftJeZ4CVP-mJ92K9pqyqhHqNRGSKOaThQ8EkASKE"
const CHALLENGE := "lpTdxOF1pK_bqZF4VOfTNxcJ9YUc3d1himIDFzVdwSM"
const UNRESERVED := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"


func test_verifier_is_64_unreserved_characters() -> void:
	var v := Pkce.new_verifier()
	assert_eq(v.length(), Pkce.VERIFIER_LENGTH)
	assert_eq(Pkce.VERIFIER_LENGTH, 64)
	for c: String in v:
		assert_true(UNRESERVED.contains(c), "'%s' is URL-safe" % c)
	assert_ne(Pkce.new_verifier(), v, "random per sign-in")


func test_verifier_from_bytes_is_deterministic() -> void:
	var bytes := PackedByteArray()
	for i: int in 64:
		bytes.append(i)
	var v := Pkce.verifier_from_bytes(bytes)
	assert_eq(v, Pkce.verifier_from_bytes(bytes))
	assert_eq(v.substr(0, 3), "ABC")


func test_s256_challenge_matches_reference() -> void:
	assert_eq(Pkce.challenge(VERIFIER), CHALLENGE)


func test_authorize_url() -> void:
	var url := AuthUrls.authorize("https://proj.supabase.co", "google", AuthUrls.loopback_redirect(54321), "CH")
	assert_eq(url, "https://proj.supabase.co/auth/v1/authorize?provider=google"
			+ "&redirect_to=http%3A%2F%2F127.0.0.1%3A54321%2Fcallback"
			+ "&code_challenge=CH&code_challenge_method=s256")


func test_loopback_redirect_carries_the_state_nonce() -> void:
	assert_eq(AuthUrls.loopback_redirect(54321, "n0nce"), "http://127.0.0.1:54321/callback?state=n0nce")
	assert_eq(AuthUrls.loopback_redirect(54321), "http://127.0.0.1:54321/callback")
	var url := AuthUrls.authorize("https://p.supabase.co", "google", AuthUrls.loopback_redirect(54321, "n0nce"), "CH")
	assert_string_contains(url, "redirect_to=http%3A%2F%2F127.0.0.1%3A54321%2Fcallback%3Fstate%3Dn0nce&")


func test_new_state_is_random_and_url_safe() -> void:
	var a := AuthUrls.new_state()
	assert_eq(a.length(), AuthUrls.STATE_LENGTH)
	assert_ne(a, AuthUrls.new_state())
	assert_eq(a.uri_encode(), a, "no escaping needed")


func test_loopback_accepts_only_the_expected_state() -> void:
	var ok := LoopbackServer.parse_request_line("GET /callback?state=n0nce&code=abc HTTP/1.1", "n0nce")
	assert_eq(ok, {"code": "abc"})
	assert_eq(LoopbackServer.parse_request_line("GET /callback?code=abc HTTP/1.1", "n0nce"), {},
			"a request without our nonce is ignored, the sign-in keeps waiting")
	assert_eq(LoopbackServer.parse_request_line("GET /callback?state=other&code=abc HTTP/1.1", "n0nce"), {})
	assert_eq(LoopbackServer.parse_request_line("GET /callback?state=other&error=access_denied HTTP/1.1", "n0nce"),
			{}, "a forged error cannot end the sign-in early")
	assert_eq(LoopbackServer.parse_request_line("GET /callback?state=n0nce&error=access_denied HTTP/1.1", "n0nce"),
			{"error": "access_denied"})


func test_loopback_request_line_with_code() -> void:
	var r := LoopbackServer.parse_request_line("GET /callback?code=abc-123&state=x HTTP/1.1")
	assert_eq(r, {"code": "abc-123"})


func test_loopback_request_line_with_error() -> void:
	var r := LoopbackServer.parse_request_line(
			"GET /callback?error=access_denied&error_description=User%20cancelled HTTP/1.1")
	assert_eq(r, {"error": "access_denied"})


func test_loopback_ignores_other_requests() -> void:
	assert_eq(LoopbackServer.parse_request_line("GET /favicon.ico HTTP/1.1"), {})
	assert_eq(LoopbackServer.parse_request_line("POST /callback?code=x HTTP/1.1"), {})
	assert_eq(LoopbackServer.parse_request_line("garbage"), {})
	assert_eq(LoopbackServer.parse_request_line("GET /callback HTTP/1.1"), {"error": "missing_code"})


func test_loopback_reply_is_small_utf8_html() -> void:
	var reply := LoopbackServer.http_response(200, CallbackPage.html(true))
	assert_true(reply.begins_with("HTTP/1.1 200 OK\r\n"))
	assert_string_contains(reply, "charset=utf-8")
	assert_string_contains(reply, CallbackPage.DONE_TITLE)
	var body := reply.get_slice("\r\n\r\n", 1)
	assert_string_contains(reply, "Content-Length: %d" % body.to_utf8_buffer().size())


func test_query_parsing() -> void:
	assert_eq(WebCallback.parse_query("?code=a%20b&x=1"), {"code": "a b", "x": "1"})
	assert_eq(WebCallback.parse_query(""), {})
	assert_eq(WebCallback.parse_query("?flag"), {"flag": ""})
