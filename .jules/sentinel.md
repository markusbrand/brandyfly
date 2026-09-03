## 2024-05-18 - Timing Attack Vulnerability in Authentication Token Check
**Vulnerability:** The health endpoint authorization token check (`BRANDYFLY_HEALTH_TOKEN`) was using simple string inequality (`!=`), which is vulnerable to timing attacks as it fails fast on the first mismatched character.
**Learning:** String comparison operators (`==`, `!=`) in Go evaluate character-by-character and can leak information about the expected token length and contents via timing measurements. This is especially dangerous for authentication checks.
**Prevention:** Always use `crypto/subtle.ConstantTimeCompare` when comparing secrets or authentication tokens to ensure comparison takes a constant amount of time regardless of the input.

## 2026-08-24 - Timing Attack Length Leakage in ConstantTimeCompare
**Vulnerability:** Comparing authentication tokens directly with `crypto/subtle.ConstantTimeCompare` leaks the length of the expected token because the function returns immediately if the lengths of the two inputs differ.
**Learning:** While `ConstantTimeCompare` protects against timing attacks during the actual byte comparison, it is not constant time when the lengths differ. This leaks information about the expected string's length, which is a vulnerability for secrets.
**Prevention:** Before using `crypto/subtle.ConstantTimeCompare`, hash both the expected and actual tokens (e.g., using `crypto/sha256.Sum256`). This ensures both inputs to `ConstantTimeCompare` are always exactly the same length, preventing length leakage.
## 2026-09-02 - Weak Hashing Algorithm (MD5) Used for Cache Keys
**Vulnerability:** The map tile service (`apps/mobile/lib/services/map_tile_service.dart`) used MD5 (`md5.convert`) to generate cache filenames for URLs.
**Learning:** While cache keys aren't typically a high-security context, using cryptographically broken algorithms like MD5 introduces collision risks and trips static security linters. If an attacker can control or influence the URL, they could potentially craft a URL that hashes to the same value as a legitimate tile, poisoning the cache.
**Prevention:** Always use a secure hashing algorithm like SHA-256 (`sha256.convert`) even for cache keys or seemingly non-cryptographic purposes to maintain strong security hygiene and prevent collision attacks.
