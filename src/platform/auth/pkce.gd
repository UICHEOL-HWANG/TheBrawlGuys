class_name Pkce
extends RefCounted
## PKCE (RFC 7636) for the Supabase Google sign-in (platform A4): a random code_verifier and its
## S256 code_challenge = base64url(sha256(verifier)) without padding.

const VERIFIER_LENGTH := 64
## RFC 7636 unreserved characters.
const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"


static func new_verifier() -> String:
	return verifier_from_bytes(Crypto.new().generate_random_bytes(VERIFIER_LENGTH))


## One character per byte (byte mod alphabet size); a slight bias is fine at 64 characters.
static func verifier_from_bytes(bytes: PackedByteArray) -> String:
	var out := ""
	for i: int in mini(bytes.size(), VERIFIER_LENGTH):
		out += ALPHABET[bytes[i] % ALPHABET.length()]
	return out


static func challenge(verifier: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(verifier.to_ascii_buffer())
	return base64url(ctx.finish())


static func base64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")
