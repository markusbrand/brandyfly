## 1. Event and Trace Contracts

- [ ] 1.1 Define versioned sensor-event, stage-timestamp, counter, and benchmark-result schemas
- [ ] 1.2 Add Rust validation that rejects malformed events with counted reasons
- [ ] 1.3 Create synthetic replay fixtures covering normal input, bursts, gaps, stale events, and malformed records
- [ ] 1.4 Add deterministic Rust tests that repeat each replay three times and compare outputs and counters

## 2. Bounded Pipeline Prototype

- [ ] 2.1 Implement Android and iOS prototype acquisition adapters that timestamp events in the native monotonic clock domain
- [ ] 2.2 Connect native events to Rust through a finite-capacity queue with documented overflow behaviour
- [ ] 2.3 Add latest-value native audio control independent of Flutter scheduling
- [ ] 2.4 Add rate-limited replaceable KPI snapshots for Flutter and expose drop, replace, stale, and rejection counters
- [ ] 2.5 Add automated stress tests that stall Flutter and overrun each queue without unbounded memory growth

## 3. Durable Prototype Recording

- [ ] 3.1 Implement versioned length-delimited append records with checksums and bounded write buffering
- [ ] 3.2 Implement restart recovery that preserves complete records and reports an incomplete tail
- [ ] 3.3 Add termination-at-each-write-boundary tests and verify recovered records and discarded-byte counts

## 4. Lifecycle and Latency Evidence

- [ ] 4.1 Instrument native receipt, Rust processing, native audio reaction, visible KPI, queue pressure, memory, and thermal state
- [ ] 4.2 Exercise foreground, permitted background, interruption, resume, and termination scenarios on physical Android hardware
- [ ] 4.3 Exercise foreground, permitted background, interruption, resume, and termination scenarios on physical iOS hardware
- [ ] 4.4 Run the documented sensor-plus-map load and report p50, p95, and maximum latency for every stage on each platform
- [ ] 4.5 Record pass or fail against the 50 ms core, 80 ms audio, and 100 ms visible-KPI p95 gates
- [ ] 4.6 Verify replay, stress, recovery, platform build tests, and OpenSpec strict validation pass
