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
	var reply := LoopbackServer.http_response(200, LoopbackServer.DONE_MESSAGE)
	assert_true(reply.begins_with("HTTP/1.1 200 OK\r\n"))
	assert_string_contains(reply, "charset=utf-8")
	assert_string_contains(reply, "로그인 완료, 게임으로 돌아가세요")
	var body := reply.get_slice("\r\n\r\n", 1)
	assert_string_contains(reply, "Content-Length: %d" % body.to_utf8_buffer().size())


func test_query_parsing() -> void:
	assert_eq(WebCallback.parse_query("?code=a%20b&x=1"), {"code": "a b", "x": "1"})
	assert_eq(WebCallback.parse_query(""), {})
	assert_eq(WebCallback.parse_query("?flag"), {"flag": ""})
