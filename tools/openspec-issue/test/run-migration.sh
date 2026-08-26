#!/usr/bin/env bash
# Fixture-backed tests for migrate-local-changes.sh using the mock gh.
# No network, no permanent GitHub issues. Exercises created-date preservation,
# conflict detection on reuse, and nonzero exit on per-item failure.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCK="$HERE/mock-gh.sh"
MIGRATE="$HERE/../migrate-local-changes.sh"
chmod +x "$MOCK" "$MIGRATE" 2>/dev/null || true

pass=0; fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
no() { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

WORK="$HERE/.migtest.$$"
mkdir -p "$WORK"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# --- build a fake local changes tree ----------------------------------------
CH="$WORK/changes"
mkdir -p "$CH/active-one" "$CH/archive/2026-08-07-archived-one"
cat >"$CH/active-one/.openspec.yaml" <<'EOF'
schema: spec-driven
created: 2026-08-07
EOF
cat >"$CH/active-one/proposal.md" <<'EOF'
## Why
Fixture active change.
EOF
cat >"$CH/active-one/tasks.md" <<'EOF'
## 1. Work
- [x] 1.1 done
- [ ] 1.2 todo
EOF
cat >"$CH/archive/2026-08-07-archived-one/.openspec.yaml" <<'EOF'
schema: spec-driven
created: 2026-08-07
EOF
cat >"$CH/archive/2026-08-07-archived-one/proposal.md" <<'EOF'
## Why
Fixture archived change.
EOF
cat >"$CH/archive/2026-08-07-archived-one/tasks.md" <<'EOF'
## 1. Work
- [x] 1.1 done
EOF

run_migrate() { # run_migrate <store> <mode> [FAIL]
  local store="$1" mode="$2" failmode="${3:-}"
  export MOCK_GH_STORE="$store" OPENSPEC_ISSUE_GH="$MOCK" \
    OPENSPEC_MIGRATION_CHANGES_DIR="$CH" OPENSPEC_MIGRATION_OUT="$store/out" \
    MOCK_GH_FAIL="${failmode:-}"
  bash "$MIGRATE" "$mode"
}

echo "== migration tests =="

# 1. Apply creates issues and preserves the source created date (2026-08-07)
store="$WORK/store1"; mkdir -p "$store"
run_migrate "$store" apply >"$store/log" 2>&1; rc=$?
[[ $rc -eq 0 ]] && ok "apply exits 0 when all items succeed" || no "apply exits 0 (rc=$rc)"
# find the archived issue and check its metadata.created
an="$(MOCK_GH_STORE="$store" OPENSPEC_ISSUE_GH="$MOCK" bash "$HERE/../openspec-issue.sh" find archived-one)"
created="$(MOCK_GH_STORE="$store" OPENSPEC_ISSUE_GH="$MOCK" bash "$HERE/../openspec-issue.sh" read "$an" | awk '/openspec:metadata$/{f=1;next} /openspec:metadata-end/{f=0} f' | jq -r '.created')"
[[ "$created" == "2026-08-07" ]] && ok "created date preserved from .openspec.yaml" || no "created preserved ($created)"
# archived issue is closed/completed
MOCK_GH_STORE="$store" OPENSPEC_ISSUE_GH="$MOCK" bash "$HERE/../openspec-issue.sh" validate "$an" | jq -e '.state=="closed" and .lifecycle=="completed"' >/dev/null 2>&1 \
  && ok "archived migrates to closed/completed" || no "archived closed/completed"

# 2. Idempotent re-run reuses issues (no duplicates) and exits 0
run_migrate "$store" apply >"$store/log2" 2>&1; rc=$?
{ [[ $rc -eq 0 ]] && grep -q "REUSED" "$store/log2" && ! grep -q "CREATED" "$store/log2"; } \
  && ok "idempotent re-run reuses, no new issues" || no "idempotent re-run (rc=$rc)"

# 3. Conflict detection: mutate an existing issue's managed content, re-run -> fail
an2="$(MOCK_GH_STORE="$store" OPENSPEC_ISSUE_GH="$MOCK" bash "$HERE/../openspec-issue.sh" find active-one)"
# tamper the proposal section content in the stored issue body
sed -i.bak 's/Fixture active change./TAMPERED content./' "$store/issues/$an2/body" && rm -f "$store/issues/$an2/body.bak"
run_migrate "$store" apply >"$store/log3" 2>&1; rc=$?
{ [[ $rc -ne 0 ]] && grep -q "CONFLICT" "$store/log3"; } \
  && ok "conflict detected on divergent reuse (nonzero exit)" || no "conflict detection (rc=$rc)"
grep -q "failures=" "$store/log3" && grep -q "failures=1" "$store/log3" \
  && ok "conflict counted as a failure" || no "conflict counted as failure"

# 4. Per-item failure surfaces and forces nonzero exit (permission denied on create)
store4="$WORK/store4"; mkdir -p "$store4"
# preflight/ensure-labels need write; allow those, then drop to READ before creates?
# Simpler: use a store with READ permission so create fails -> preflight --write fails first.
echo "READ" >"$store4/perm"
run_migrate "$store4" apply >"$store4/log" 2>&1; rc=$?
[[ $rc -ne 0 ]] && ok "apply refuses without write permission (nonzero)" || no "apply refuses w/o write (rc=$rc)"

# 5. Dry-run never writes and exits 0
store5="$WORK/store5"; mkdir -p "$store5"
run_migrate "$store5" dry-run >"$store5/log" 2>&1; rc=$?
{ [[ $rc -eq 0 ]] && [[ ! -d "$store5/issues" || -z "$(ls -A "$store5/issues" 2>/dev/null)" ]]; } \
  && ok "dry-run writes no issues and exits 0" || no "dry-run no writes (rc=$rc)"

echo
echo "migration tests: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
