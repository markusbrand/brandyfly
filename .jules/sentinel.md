## 2024-05-18 - Timing Attack Vulnerability in Authentication Token Check
**Vulnerability:** The health endpoint authorization token check (`BRANDYFLY_HEALTH_TOKEN`) was using simple string inequality (`!=`), which is vulnerable to timing attacks as it fails fast on the first mismatched character.
**Learning:** String comparison operators (`==`, `!=`) in Go evaluate character-by-character and can leak information about the expected token length and contents via timing measurements. This is especially dangerous for authentication checks.
**Prevention:** Always use `crypto/subtle.ConstantTimeCompare` when comparing secrets or authentication tokens to ensure comparison takes a constant amount of time regardless of the input.

## 2024-05-18 - Additional Timing Attack Vulnerability in Authentication Token Check
**Vulnerability:** The fix to use `subtle.ConstantTimeCompare` introduced a subtle vulnerability where the function returns immediately if input lengths differ, leaking length information of the secret via timing.
**Learning:** `subtle.ConstantTimeCompare` does not compare strings of different lengths in constant time. It early returns if lengths do not match, which can be exploited by an attacker to deduce the expected token length.
**Prevention:** Always hash the input strings (e.g., using `crypto/sha256.Sum256`) *before* applying `subtle.ConstantTimeCompare`. This guarantees both inputs are exactly the same length (32 bytes for SHA256) regardless of the original string lengths, ensuring a true constant-time comparison.
