## 2024-05-18 - Timing Attack Vulnerability in Authentication Token Check
**Vulnerability:** The health endpoint authorization token check (`BRANDYFLY_HEALTH_TOKEN`) was using simple string inequality (`!=`), which is vulnerable to timing attacks as it fails fast on the first mismatched character.
**Learning:** String comparison operators (`==`, `!=`) in Go evaluate character-by-character and can leak information about the expected token length and contents via timing measurements. This is especially dangerous for authentication checks.
**Prevention:** Always use `crypto/subtle.ConstantTimeCompare` when comparing secrets or authentication tokens to ensure comparison takes a constant amount of time regardless of the input.

## 2024-05-24 - Length-Based Timing Attack in Go subtle.ConstantTimeCompare
**Vulnerability:** The health check authentication token comparison used `subtle.ConstantTimeCompare` but failed to account for variable-length inputs. The `ConstantTimeCompare` function returns immediately if the lengths differ, leaking the exact length of the expected token.
**Learning:** `subtle.ConstantTimeCompare` only guarantees constant time if the slices provided are of equal length. Passing raw, variable-length inputs defeats the purpose of the function for length-based timing attacks.
**Prevention:** Before using `subtle.ConstantTimeCompare` to check authentication tokens of unknown or variable length, always hash both the expected and actual tokens (e.g., using `crypto/sha256.Sum256`) to ensure the byte slices being compared are always identical in length.