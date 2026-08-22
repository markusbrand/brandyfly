## 2024-05-18 - Timing Attack Vulnerability in Authentication Token Check
**Vulnerability:** The health endpoint authorization token check (`BRANDYFLY_HEALTH_TOKEN`) was using simple string inequality (`!=`), which is vulnerable to timing attacks as it fails fast on the first mismatched character.
**Learning:** String comparison operators (`==`, `!=`) in Go evaluate character-by-character and can leak information about the expected token length and contents via timing measurements. This is especially dangerous for authentication checks.
**Prevention:** Always use `crypto/subtle.ConstantTimeCompare` when comparing secrets or authentication tokens to ensure comparison takes a constant amount of time regardless of the input.

## 2024-03-24 - Timing Attack Risk with ConstantTimeCompare
**Vulnerability:** Comparing `actualAuth` and `expectedAuth` headers using `crypto/subtle.ConstantTimeCompare` without hashing.
**Learning:** In Go, `crypto/subtle.ConstantTimeCompare` returns immediately if input lengths differ, leaking length information and exposing the system to a timing attack.
**Prevention:** Always hash both strings (e.g., using `crypto/sha256`) before comparison to ensure inputs are identical in length.
