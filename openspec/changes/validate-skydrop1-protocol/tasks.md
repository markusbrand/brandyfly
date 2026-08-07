## 1. Evidence and Contracts

- [ ] 1.1 Obtain and record permitted SkyDrop 1 transport and protocol evidence, including firmware scope and verification date
- [ ] 1.2 Define the versioned raw-frame, parse-result, and monotonic trace schemas
- [ ] 1.3 Document unresolved fields as blocked rather than assigning inferred units or semantics

## 2. Parser and Replay

- [ ] 2.1 Implement the transport-independent SkyDrop 1 frame parser against the verified protocol subset
- [ ] 2.2 Add sanitisation tooling that rejects secrets and unsanitised precise coordinates
- [ ] 2.3 Commit a small redistributable fixture with expected ordered parse results
- [ ] 2.4 Add deterministic replay tests for valid, malformed, truncated, duplicate, and out-of-order frames

## 3. Android Hardware Prototype

- [ ] 3.1 Add a developer-only Android Bluetooth Classic/SPP transport behind the native plugin boundary
- [ ] 3.2 Timestamp payloads at native receipt and propagate trace identifiers through parser and Rust-core acknowledgement
- [ ] 3.3 Expose explicit connection, stale-data, parse-error, sequence-gap, and reconnect events
- [ ] 3.4 Add Android adapter tests with a fake transport for connection interruption and buffer pressure

## 4. Device Evidence and Decision

- [ ] 4.1 Run and retain a 30-minute physical SkyDrop 1 test under documented device, firmware, thermal, and app-load conditions
- [ ] 4.2 Interrupt and restore the link during the hardware run and verify reconnect without process restart
- [ ] 4.3 Generate latency and integrity summaries with p50, p95, maximum, loss, duplicate, stale, and parse-failure metrics
- [ ] 4.4 Record the permitted Android and iOS support boundaries, including manufacturer or platform evidence
- [ ] 4.5 Publish the redacted gate report and verify all parser tests and OpenSpec strict validation pass
