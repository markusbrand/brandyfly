#!/usr/bin/env bash
# Fixture-backed tests for the openspec-issue adapter using a mock gh.
# No network access and no permanent GitHub issues are created.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
ADAPTER="$HERE/../openspec-issue.sh"
MOCK="$HERE/mock-gh.sh"
FIX="$HERE/fixtures"

chmod +x "$ADAPTER" "$MOCK" 2>/dev/null || true

pass=0; fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
no() { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

new_store() {
  local s="$HERE/.store.$$.$RANDOM"
  mkdir -p "$s"
  printf '%s' "$s"
}

run() {
  # run <store> [FAIL=mode] -- adapter args...
  local store="$1"; shift
  MOCK_GH_STORE="$store" OPENSPEC_ISSUE_GH="$MOCK" bash "$ADAPTER" "$@"
}

# ---- fixtures ---------------------------------------------------------------
mkdir -p "$FIX"
cat >"$FIX/proposal.md" <<'EOF'
## Why
Demonstrate the adapter round trip.
## What Changes
- Add a sample managed section.
EOF
cat >"$FIX/tasks.md" <<'EOF'
## 1. Work
- [x] 1.1 Completed task
- [ ] 1.2 Pending task
EOF
cat >"$FIX/meta.json" <<'EOF'
{"schemaVersion":1,"changeName":"sample-change","specSchema":"spec-driven","lifecycle":"proposed","created":"2026-08-07","archivedDate":null}
EOF

section_file() { local f="$HERE/.sec.$RANDOM"; printf '%s\n' "$1" >"$f"; printf '%s' "$f"; }
meta_file() { # meta_file <changeName> <lifecycle>
  local f="$HERE/.meta.$RANDOM"
  jq -nc --arg n "$1" --arg l "${2:-proposed}" \
    '{schemaVersion:1,changeName:$n,specSchema:"spec-driven",lifecycle:$l,created:"2026-08-07",archivedDate:null}' >"$f"
  printf '%s' "$f"
}

echo "== adapter tests =="

# 1. Round trip: render + create + read + validate + section extraction
store="$(new_store)"
BODY="$HERE/.body.$$"
run "$store" render-body --meta "$FIX/meta.json" --proposal "$FIX/proposal.md" --tasks "$FIX/tasks.md" >"$BODY"
out="$(run "$store" create --name sample-change --title "Sample change" --schema spec-driven --lifecycle proposed --body-file "$BODY")"
num="$(jq -r '.number' <<<"$out")"
[[ "$num" == "1" ]] && ok "create returns issue number" || no "create returns issue number ($out)"
run "$store" validate "$num" >/dev/null 2>&1 && ok "post-create validate passes" || no "post-create validate passes"
got="$(run "$store" get-section "$num" proposal)"
grep -q "Demonstrate the adapter round trip" <<<"$got" && ok "proposal section round trips" || no "proposal section round trips"
found="$(run "$store" find sample-change)"
[[ "$found" == "$num" ]] && ok "find resolves change name to issue" || no "find resolves change name ($found)"

# 2. Section-preserving update keeps unmanaged text and other sections
# inject user-authored text outside managed sections
d="$store/issues/$num"
printf '\n\nHUMAN-NOTE-KEEP-ME\n' >>"$d/body"
sf="$(section_file "## Why
Updated rationale here.")"
run "$store" set-section "$num" proposal --body-file "$sf" >/dev/null
body="$(run "$store" read "$num")"
grep -q "Updated rationale here" <<<"$body" && ok "update replaces target section" || no "update replaces target section"
grep -q "HUMAN-NOTE-KEEP-ME" <<<"$body" && ok "update preserves user-authored text" || no "update preserves user-authored text"
grep -q "1.1 Completed task" <<<"$body" && ok "update preserves other sections (tasks)" || no "update preserves other sections"
run "$store" validate "$num" >/dev/null 2>&1 && ok "validate after update passes" || no "validate after update passes"
rm -f "$sf"

# 3. Duplicate change name refused
dup="$(run "$store" create --name sample-change --title "dup" --body-file "$BODY" 2>&1; echo "rc=$?")"
grep -q "rc=4" <<<"$dup" && ok "duplicate change name refused (exit 4)" || no "duplicate change name refused ($dup)"

# 4. Malformed issue detection (missing markers)
store2="$(new_store)"
mkdir -p "$store2/issues/1"
printf 'no metadata here, no markers\n' >"$store2/issues/1/body"
echo OPEN >"$store2/issues/1/state"
printf 'openspec\nopenspec:proposed\n' >"$store2/issues/1/labels"
echo 1 >"$store2/counter"
run "$store2" validate 1 >/dev/null 2>&1; rc=$?
[[ $rc -eq 5 ]] && ok "malformed issue rejected (exit 5)" || no "malformed issue rejected (rc=$rc)"
run "$store2" set-section 1 proposal --body-file "$FIX/proposal.md" >/dev/null 2>&1; rc=$?
[[ $rc -eq 5 ]] && ok "update refuses malformed issue without rewrite" || no "update refuses malformed issue (rc=$rc)"

# 5. Sensitive content refused before publish
store3="$(new_store)"
sec="$store3/secret-body"
run "$store3" render-body --meta "$FIX/meta.json" --proposal <(:) >"$sec" 2>/dev/null || true
run "$store3" render-body --meta "$FIX/meta.json" >"$sec"
# splice a fake token into a section
python3 - "$sec" <<'PY' 2>/dev/null || sed -i 's#</proposal>##' "$sec"
import sys
p=sys.argv[1]
s=open(p).read().replace("<!-- openspec:section:proposal:start -->\n","<!-- openspec:section:proposal:start -->\ntoken ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\n")
open(p,"w").write(s)
PY
run "$store3" scan-content --body-file "$sec" >/dev/null 2>&1; rc=$?
[[ $rc -eq 6 ]] && ok "sensitive content refused (exit 6)" || no "sensitive content refused (rc=$rc)"

# 6. Body-size limit enforced (valid but oversized rendered body)
store4="$(new_store)"
bigprop="$store4/bigprop.md"; head -c 200000 /dev/zero | tr '\0' 'a' >"$bigprop"
bm="$(meta_file big-change)"
big="$store4/big.md"
run "$store4" render-body --meta "$bm" --proposal "$bigprop" >"$big"
OPENSPEC_ISSUE_BODY_LIMIT=1000 run "$store4" create --name big-change --title big --body-file "$big" >/dev/null 2>&1; rc=$?
[[ $rc -eq 7 ]] && ok "body-size limit refused (exit 7)" || no "body-size limit refused (rc=$rc)"
rm -f "$bm"

# 7. Explicit GitHub failure behavior (connectivity + auth) leaves no artifact
store5="$(new_store)"
MOCK_GH_STORE="$store5" OPENSPEC_ISSUE_GH="$MOCK" MOCK_GH_FAIL=connectivity bash "$ADAPTER" create --name x --title x --body-file "$BODY" >/dev/null 2>&1; rc=$?
[[ $rc -eq 9 ]] && ok "connectivity failure reported (exit 9)" || no "connectivity failure (rc=$rc)"
[[ ! -d "$store5/issues/1" ]] && ok "no issue artifact created on connectivity failure" || no "no artifact on failure"
MOCK_GH_STORE="$store5" OPENSPEC_ISSUE_GH="$MOCK" MOCK_GH_FAIL=auth bash "$ADAPTER" preflight >/dev/null 2>&1; rc=$?
[[ $rc -eq 10 ]] && ok "auth failure reported (exit 10)" || no "auth failure (rc=$rc)"

# 8. Missing write permission leaves content unchanged
store6="$(new_store)"
pm="$(meta_file perm-change)"; pbody="$store6/pbody"
run "$store6" render-body --meta "$pm" --proposal "$FIX/proposal.md" >"$pbody"
run "$store6" create --name perm-change --title perm --body-file "$pbody" >/dev/null
echo "READ" >"$store6/perm"
before="$(run "$store6" read 1)"
sf="$(section_file "## Why
should not persist")"
run "$store6" set-section 1 proposal --body-file "$sf" >/dev/null 2>&1; rc=$?
[[ $rc -eq 8 ]] && ok "missing write permission reported (exit 8)" || no "missing write permission (rc=$rc)"
after="$(run "$store6" read 1)"
[[ "$before" == "$after" ]] && ok "issue content unchanged on permission failure" || no "content unchanged on permission failure"
rm -f "$sf"

# 9. Interrupted/partial update detection: post-write validate catches unbalanced body
store7="$(new_store)"
im="$(meta_file interrupt-change)"; ibody="$store7/ibody"
run "$store7" render-body --meta "$im" --proposal "$FIX/proposal.md" >"$ibody"
run "$store7" create --name interrupt-change --title int --body-file "$ibody" >/dev/null
# Simulate a corrupt remote write by damaging markers, then ensure validate fails
sed -i 's#<!-- openspec:section:tasks:end -->##' "$store7/issues/1/body"
run "$store7" validate 1 >/dev/null 2>&1; rc=$?
[[ $rc -eq 5 ]] && ok "interrupted/partial write detected by validate" || no "interrupted write detected (rc=$rc)"

# 10. list reports lifecycle + task progress
store8="$(new_store)"
lm="$(meta_file list-change)"
run "$store8" render-body --meta "$lm" --proposal "$FIX/proposal.md" --tasks "$FIX/tasks.md" >"$BODY"
run "$store8" create --name list-change --title list --lifecycle proposed --body-file "$BODY" >/dev/null
listout="$(run "$store8" list --state open)"
echo "$listout" | jq -e '.[0] | (.name=="list-change" and .tasksTotal==2 and .tasksDone==1)' >/dev/null 2>&1 \
  && ok "list reports name and task progress" || no "list reports progress ($listout)"

# 11. set-lifecycle to completed closes the issue and validates
run "$store8" find list-change >/dev/null
n="$(run "$store8" find list-change)"
# proposed -> completed is an invalid transition and must be refused
run "$store8" set-lifecycle "$n" completed >/dev/null 2>&1; rc=$?
[[ $rc -eq 2 ]] && ok "invalid transition proposed->completed refused (exit 2)" || no "invalid transition refused (rc=$rc)"
# walk the valid path proposed -> ready -> implementing -> completed
run "$store8" set-lifecycle "$n" ready >/dev/null 2>&1 && ok "transition proposed->ready" || no "transition proposed->ready"
run "$store8" set-lifecycle "$n" implementing >/dev/null 2>&1 && ok "transition ready->implementing" || no "transition ready->implementing"
run "$store8" set-lifecycle "$n" completed >/dev/null 2>&1 && ok "transition implementing->completed" || no "transition implementing->completed"
st="$(cat "$store8/issues/$n/state")"
[[ "$st" == "CLOSED" ]] && ok "completed lifecycle closes issue" || no "completed closes issue ($st)"
# completed is terminal
run "$store8" set-lifecycle "$n" implementing >/dev/null 2>&1; rc=$?
[[ $rc -eq 2 ]] && ok "completed is terminal (reopen transition refused)" || no "completed terminal (rc=$rc)"
# label/metadata consistency holds after transitions
run "$store8" validate "$n" >/dev/null 2>&1 && ok "issue valid after transition walk" || no "issue valid after transition walk"

# 12. Metadata/label consistency regression: corrupt the metadata lifecycle only
store9="$(new_store)"
cm="$(meta_file consistency-change proposed)"
run "$store9" render-body --meta "$cm" --proposal "$FIX/proposal.md" >"$BODY"
run "$store9" create --name consistency-change --title c --body-file "$BODY" >/dev/null
cn="$(run "$store9" find consistency-change)"
# Directly rewrite only the metadata lifecycle in the stored body (label stays proposed)
sed -i 's/"lifecycle":"proposed"/"lifecycle":"implementing"/' "$store9/issues/$cn/body"
run "$store9" validate "$cn" >/dev/null 2>&1; rc=$?
[[ $rc -eq 11 ]] && ok "validate rejects label!=metadata lifecycle (exit 11)" || no "label/metadata mismatch rejected (rc=$rc)"

# 13. set-metadata post-write validation + no success-shaped output on failure
store10="$(new_store)"
mm="$(meta_file meta-change proposed)"
run "$store10" render-body --meta "$mm" --proposal "$FIX/proposal.md" >"$BODY"
run "$store10" create --name meta-change --title m --body-file "$BODY" >/dev/null
mn="$(run "$store10" find meta-change)"
# a benign metadata write validates and succeeds
out="$(run "$store10" set-metadata "$mn" --key archivedDate --value 2026-08-07 2>&1)"; rc=$?
{ [[ $rc -eq 0 ]] && jq -e '.ok==true' >/dev/null 2>&1 <<<"$out"; } && ok "set-metadata benign field succeeds with validation" || no "set-metadata benign ($rc:$out)"
# changing lifecycle metadata alone breaks label consistency -> must fail (not success-shaped) and roll back
before="$(run "$store10" read "$mn")"
out="$(run "$store10" set-metadata "$mn" --key lifecycle --value completed 2>&1)"; rc=$?
{ [[ $rc -ne 0 ]] && ! jq -e '.ok==true' >/dev/null 2>&1 <<<"$out"; } && ok "set-metadata inconsistent lifecycle fails (no success output)" || no "set-metadata inconsistent fails ($rc:$out)"
after="$(run "$store10" read "$mn")"
[[ "$before" == "$after" ]] && ok "set-metadata rolls back to prior valid body on failure" || no "set-metadata rollback"

# 14. create validates flags against body metadata
store11="$(new_store)"
fm="$(meta_file flag-change proposed)"
run "$store11" render-body --meta "$fm" --proposal "$FIX/proposal.md" >"$BODY"
run "$store11" create --name flag-change --title f --lifecycle implementing --body-file "$BODY" >/dev/null 2>&1; rc=$?
[[ $rc -eq 2 ]] && ok "create refuses --lifecycle mismatch (exit 2)" || no "create lifecycle mismatch (rc=$rc)"
run "$store11" create --name flag-change --title f --schema other-schema --body-file "$BODY" >/dev/null 2>&1; rc=$?
[[ $rc -eq 2 ]] && ok "create refuses --schema mismatch (exit 2)" || no "create schema mismatch (rc=$rc)"
run "$store11" create --name flag-change --title f --created 2020-01-01 --body-file "$BODY" >/dev/null 2>&1; rc=$?
[[ $rc -eq 2 ]] && ok "create refuses --created mismatch (exit 2)" || no "create created mismatch (rc=$rc)"
run "$store11" create --name flag-change --title f --schema spec-driven --lifecycle proposed --created 2026-08-07 --body-file "$BODY" >/dev/null 2>&1 && ok "create accepts matching flags" || no "create matching flags"

# 15. ensure-labels: success creates labels; permission/connectivity classified
store12="$(new_store)"
run "$store12" ensure-labels >/dev/null 2>&1 && ok "ensure-labels succeeds and verifies" || no "ensure-labels succeeds"
run "$store12" ensure-labels >/dev/null 2>&1 && ok "ensure-labels idempotent" || no "ensure-labels idempotent"
labels_now="$(MOCK_GH_STORE="$store12" cat "$store12/labels" 2>/dev/null | tr '\n' ',')"
grep -q "openspec:completed" <<<"$labels_now" && ok "ensure-labels created lifecycle labels" || no "ensure-labels created labels ($labels_now)"
store13="$(new_store)"; echo "READ" >"$store13/perm"
run "$store13" ensure-labels >/dev/null 2>&1; rc=$?
[[ $rc -eq 8 ]] && ok "ensure-labels reports missing permission (exit 8)" || no "ensure-labels permission (rc=$rc)"
MOCK_GH_STORE="$store13" OPENSPEC_ISSUE_GH="$MOCK" MOCK_GH_FAIL=connectivity bash "$ADAPTER" ensure-labels >/dev/null 2>&1; rc=$?
[[ $rc -eq 9 ]] && ok "ensure-labels reports connectivity failure (exit 9)" || no "ensure-labels connectivity (rc=$rc)"

# 16. Full metadata validation (finding 7): reject bad schemaVersion/name/date/markers
store16="$(new_store)"
mkmeta_body() { # mkmeta_body <store> <json-meta> -> writes a body to $BODY
  local st="$1"
  local mj="$2"
  local mf="$st/.m"
  printf '%s' "$mj" >"$mf"
  run "$st" render-body --meta "$mf" --proposal "$FIX/proposal.md" >"$BODY" || {
    echo "fixture setup failed: render-body for $st" >&2
    exit 1
  }
}
# schemaVersion must be exactly 1
mkmeta_body "$store16" '{"schemaVersion":2,"changeName":"v2-change","specSchema":"spec-driven","lifecycle":"proposed","created":"2026-08-07","archivedDate":null}'
run "$store16" create --name v2-change --title x --body-file "$BODY" >/dev/null 2>&1; rc=$?
[[ $rc -eq 5 ]] && ok "reject schemaVersion!=1 (exit 5)" || no "schemaVersion (rc=$rc)"
# changeName must be kebab-case
mkmeta_body "$store16" '{"schemaVersion":1,"changeName":"Not_Kebab","specSchema":"spec-driven","lifecycle":"proposed","created":"2026-08-07","archivedDate":null}'
run "$store16" create --name Not_Kebab --title x --body-file "$BODY" >/dev/null 2>&1; rc=$?
[[ $rc -eq 5 ]] && ok "reject non-kebab changeName (exit 5)" || no "kebab (rc=$rc)"
# created must be a valid date
mkmeta_body "$store16" '{"schemaVersion":1,"changeName":"bad-date","specSchema":"spec-driven","lifecycle":"proposed","created":"2026-13-40","archivedDate":null}'
run "$store16" create --name bad-date --title x --body-file "$BODY" >/dev/null 2>&1; rc=$?
[[ $rc -eq 5 ]] && ok "reject invalid created date (exit 5)" || no "created date (rc=$rc)"
# archivedDate must be null or valid date
mkmeta_body "$store16" '{"schemaVersion":1,"changeName":"bad-arch","specSchema":"spec-driven","lifecycle":"completed","created":"2026-08-07","archivedDate":"nope"}'
run "$store16" create --name bad-arch --title x --body-file "$BODY" >/dev/null 2>&1; rc=$?
[[ $rc -eq 5 ]] && ok "reject invalid archivedDate (exit 5)" || no "archivedDate (rc=$rc)"
# duplicate metadata block
gm="$(meta_file dup-meta proposed)"
run "$store16" render-body --meta "$gm" --proposal "$FIX/proposal.md" >"$BODY"
cat "$BODY" "$BODY" >"$BODY.2"; mv "$BODY.2" "$BODY"
run "$store16" create --name dup-meta --title x --body-file "$BODY" >/dev/null 2>&1; rc=$?
[[ $rc -eq 5 ]] && ok "reject duplicate metadata block (exit 5)" || no "dup metadata (rc=$rc)"
# out-of-order / nested section markers
gm2="$(meta_file order-change proposed)"
run "$store16" render-body --meta "$gm2" --proposal "$FIX/proposal.md" >"$BODY"
# swap: move a design:start before requirements by duplicating incorrectly
python3 - "$BODY" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
# nest a tasks marker inside proposal to break order
s=s.replace("<!-- openspec:section:proposal:start -->",
            "<!-- openspec:section:proposal:start -->\n<!-- openspec:section:tasks:start -->",1)
open(p,"w").write(s)
PY
run "$store16" create --name order-change --title x --body-file "$BODY" >/dev/null 2>&1; rc=$?
[[ $rc -eq 5 ]] && ok "reject out-of-order/nested markers (exit 5)" || no "marker order (rc=$rc)"

# 17. Malformed labeled issue blocks discovery + duplicate creation (finding 6)
store17="$(new_store)"
gm3="$(meta_file good-change proposed)"
run "$store17" render-body --meta "$gm3" --proposal "$FIX/proposal.md" >"$BODY"
run "$store17" create --name good-change --title g --body-file "$BODY" >/dev/null
# inject a malformed labeled issue directly into the store
mkdir -p "$store17/issues/999"; printf 'garbage, no metadata\n' >"$store17/issues/999/body"; echo OPEN >"$store17/issues/999/state"; printf 'openspec\nopenspec:proposed\n' >"$store17/issues/999/labels"
run "$store17" list >/dev/null 2>&1; rc=$?
[[ $rc -eq 5 ]] && ok "list halts on malformed labeled issue (exit 5)" || no "list malformed (rc=$rc)"
run "$store17" find good-change >/dev/null 2>&1; rc=$?
[[ $rc -eq 5 ]] && ok "find halts on malformed labeled issue (exit 5)" || no "find malformed (rc=$rc)"
# duplicate creation blocked even though a malformed issue exists
run "$store17" render-body --meta "$(meta_file another-change proposed)" --proposal "$FIX/proposal.md" >"$BODY"
run "$store17" create --name another-change --title a --body-file "$BODY" >/dev/null 2>&1; rc=$?
[[ $rc -eq 5 ]] && ok "create halts when any labeled issue malformed (exit 5)" || no "create malformed halt (rc=$rc)"

# 18. Pagination beyond 200 (finding 5): find item #201 with small per_page
store18="$(new_store)"
# seed 205 issues cheaply, one of them our target
tmeta="$(meta_file target-change proposed)"
run "$store18" render-body --meta "$tmeta" --proposal "$FIX/proposal.md" >"$BODY"
for i in $(seq 1 205); do
  d="$store18/issues/$i"; mkdir -p "$d"; echo OPEN >"$d/state"; printf 'openspec\nopenspec:proposed\n' >"$d/labels"
  if [[ $i -eq 201 ]]; then cp "$BODY" "$d/body"; else
    mj="$store18/.m$i"; printf '{"schemaVersion":1,"changeName":"filler-%s","specSchema":"spec-driven","lifecycle":"proposed","created":"2026-08-07","archivedDate":null}' "$i" >"$mj"
    run "$store18" render-body --meta "$mj" --proposal "$FIX/proposal.md" >"$d/body"; rm -f "$mj"
  fi
done
echo 205 >"$store18/counter"
found201="$(OPENSPEC_ISSUE_PER_PAGE=50 run "$store18" find target-change 2>/dev/null)"
[[ "$found201" == "201" ]] && ok "pagination finds issue #201 beyond page limit" || no "pagination find (#$found201)"
dupout="$(OPENSPEC_ISSUE_PER_PAGE=50 run "$store18" create --name target-change --title t --body-file "$BODY" 2>&1; echo rc=$?)"
grep -q "rc=4" <<<"$dupout" && ok "duplicate detection covers issue #201 (exit 4)" || no "pagination duplicate ($dupout)"

# 19. Atomic set-lifecycle rollback at each stage (finding 3)
setup_impl_issue() { # -> echoes issue number in ready state, store arg
  local st="$1" mf; mf="$(meta_file "$2" proposed)"
  run "$st" render-body --meta "$mf" --proposal "$FIX/proposal.md" >"$BODY"
  run "$st" create --name "$2" --title x --body-file "$BODY" >/dev/null
  local nn; nn="$(run "$st" find "$2")"
  run "$st" set-lifecycle "$nn" ready >/dev/null
  printf '%s' "$nn"
}
for stage in add-label body close post; do
  st="$(new_store)"
  nn="$(setup_impl_issue "$st" "atomic-$stage")"
  # capture prior valid state
  before_body="$(run "$st" read "$nn")"
  before_state="$(cat "$st/issues/$nn/state")"
  before_labels="$(sort "$st/issues/$nn/labels")"
  case "$stage" in
    add-label) failenv="add-label";;
    body) failenv="body";;
    close) failenv="close";;
    post) failenv="corrupt-body";;
  esac
  # transition ready->implementing (uses add-label/remove-label/reopen/body/validate);
  # for 'close' stage use implementing->completed which performs a close.
  if [[ "$stage" == "close" ]]; then
    run "$st" set-lifecycle "$nn" implementing >/dev/null
    before_body="$(run "$st" read "$nn")"; before_state="$(cat "$st/issues/$nn/state")"; before_labels="$(sort "$st/issues/$nn/labels")"
    MOCK_GH_STORE="$st" OPENSPEC_ISSUE_GH="$MOCK" MOCK_GH_FAIL_ON="$failenv" MOCK_GH_FAIL_ONCE=1 bash "$ADAPTER" set-lifecycle "$nn" completed >/dev/null 2>&1; rc=$?
  else
    MOCK_GH_STORE="$st" OPENSPEC_ISSUE_GH="$MOCK" MOCK_GH_FAIL_ON="$failenv" MOCK_GH_FAIL_ONCE=1 bash "$ADAPTER" set-lifecycle "$nn" implementing >/dev/null 2>&1; rc=$?
  fi
  after_body="$(run "$st" read "$nn")"
  after_state="$(cat "$st/issues/$nn/state")"
  after_labels="$(sort "$st/issues/$nn/labels")"
  okstage=1
  [[ $rc -ne 0 ]] || okstage=0
  [[ "$before_body" == "$after_body" ]] || okstage=0
  [[ "$before_state" == "$after_state" ]] || okstage=0
  [[ "$before_labels" == "$after_labels" ]] || okstage=0
  # issue must still be valid after rollback
  run "$st" validate "$nn" >/dev/null 2>&1 || okstage=0
  [[ $okstage -eq 1 ]] && ok "set-lifecycle rollback at '$stage' stage restores prior state" || no "set-lifecycle rollback at '$stage' (rc=$rc)"
done

# 20. Completed-create staged recovery (finding 4)
store20="$(new_store)"
cmeta="$(meta_file completed-change completed)"
# render with archivedDate set (archived-style)
printf '{"schemaVersion":1,"changeName":"completed-change","specSchema":"spec-driven","lifecycle":"completed","created":"2026-08-07","archivedDate":"2026-08-07"}' >"$store20/.cm"
run "$store20" render-body --meta "$store20/.cm" --proposal "$FIX/proposal.md" >"$BODY"
out="$(run "$store20" create --name completed-change --title c --body-file "$BODY" 2>&1)"; rc=$?
{ [[ $rc -eq 0 ]] && jq -e '.staged==true' >/dev/null 2>&1 <<<"$out"; } && ok "completed create via staged transition succeeds" || no "completed create staged ($rc:$out)"
cn="$(run "$store20" find completed-change)"
run "$store20" validate "$cn" | jq -e '.state=="closed" and .lifecycle=="completed"' >/dev/null 2>&1 && ok "completed create yields closed/completed issue" || no "completed create final state"
# failure injection during completion: issue must be left VALID (recoverable) and no success
store21="$(new_store)"
printf '{"schemaVersion":1,"changeName":"completed-fail","specSchema":"spec-driven","lifecycle":"completed","created":"2026-08-07","archivedDate":"2026-08-07"}' >"$store21/.cm"
run "$store21" render-body --meta "$store21/.cm" --proposal "$FIX/proposal.md" >"$BODY"
out="$(MOCK_GH_STORE="$store21" OPENSPEC_ISSUE_GH="$MOCK" MOCK_GH_FAIL_ON=close bash "$ADAPTER" create --name completed-fail --title c --body-file "$BODY" 2>&1)"; rc=$?
{ [[ $rc -ne 0 ]] && ! jq -e '.ok==true' >/dev/null 2>&1 <<<"$out"; } && ok "completed create does not claim success on completion failure" || no "completed create failure ($rc)"
cfn="$(run "$store21" find completed-fail 2>/dev/null)"
run "$store21" validate "$cfn" >/dev/null 2>&1 && ok "failed completed create leaves a valid recoverable issue" || no "recoverable issue invalid"
# retry: completing the recoverable staged issue succeeds
run "$store21" set-lifecycle "$cfn" completed >/dev/null 2>&1 && ok "recoverable staged issue can be completed on retry" || no "retry completion"

# 21. Guard self-test (finding 8)
if bash "$HERE/../check-local-change-storage.sh" --self-test >/dev/null 2>&1; then
  ok "local-storage guard self-test passes"
else
  no "local-storage guard self-test"
fi

rm -f "$BODY"
# cleanup stores
rm -rf "$HERE"/.store.$$* "$HERE"/.sec.$$* "$HERE"/.body.$$ "$HERE"/.meta.$$* 2>/dev/null || true

echo
echo "== repository local-storage guard (informational: passes post-cutover) =="
if bash "$HERE/../check-local-change-storage.sh" >/dev/null 2>&1; then
  echo "  ok   check-local-change-storage passes"
else
  echo "  info check-local-change-storage still reports local change dirs (expected before cutover)"
fi

echo
echo "adapter tests: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]] || exit 1

echo
bash "$HERE/run-migration.sh"
