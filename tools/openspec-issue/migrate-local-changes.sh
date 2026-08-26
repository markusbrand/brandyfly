#!/usr/bin/env bash
# Migrate repository-local OpenSpec changes into GitHub issues via the adapter.
#
#   migrate-local-changes.sh dry-run   # build + scan payloads, no writes (default)
#   migrate-local-changes.sh apply     # create/validate issues, record mapping
#
# Idempotent by stable change name: an existing issue is reused, not duplicated.
# Active changes become open issues; archived changes become closed completed
# issues. A local directory is NEVER removed by this script (cutover is separate).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
ADAPTER="$HERE/openspec-issue.sh"
CHANGES="${OPENSPEC_MIGRATION_CHANGES_DIR:-$ROOT/openspec/changes}"
OUT="${OPENSPEC_MIGRATION_OUT:-$HERE/.migration}"
MAP="$OUT/mapping.tsv"
MODE="${1:-dry-run}"

mkdir -p "$OUT"
: >"$OUT/summary.txt"

adapter() { bash "$ADAPTER" "$@"; }

# Read the source change's created date from its .openspec.yaml, falling back to
# the archived date prefix, then to today. Never fabricate a date when the
# source records one.
source_created_date() {
  local dir="$1" archived="${2:-}" d=""
  if [[ -f "$dir/.openspec.yaml" ]]; then
    d="$(grep -E '^created:' "$dir/.openspec.yaml" | head -1 \
      | sed -E 's/^created:[[:space:]]*//; s/["'"'"']//g' | tr -d '[:space:]')"
  fi
  [[ -z "$d" && -n "$archived" ]] && d="$archived"
  [[ -z "$d" ]] && d="$(date -u +%Y-%m-%d)"
  printf '%s' "$d"
}

# title-case a kebab change name into a readable issue title
title_for() {
  local name="$1"
  printf 'OpenSpec: %s' "$name"
}

# Build the requirements section from a change's delta specs, preserving the
# capability path as a heading.
build_requirements() {
  local dir="$1" out="$2"
  : >"$out"
  if [[ -d "$dir/specs" ]]; then
    local sp cap
    while IFS= read -r sp; do
      [[ -z "$sp" ]] && continue
      cap="$(dirname "${sp#"$dir"/specs/}")"
      printf '### Capability: %s\n\n' "$cap" >>"$out"
      cat "$sp" >>"$out"
      printf '\n' >>"$out"
    done < <(find "$dir/specs" -name 'spec.md' | sort)
  fi
  [[ -s "$out" ]] || printf '_No requirement deltas._\n' >>"$out"
}

# Determine lifecycle for an active change from task completion.
lifecycle_for_active() {
  local tasks="$1"
  if [[ -f "$tasks" ]]; then
    local done
    done="$(grep -cE '^[[:space:]]*- \[[xX]\]' "$tasks" || true)"
    if [[ "${done:-0}" -gt 0 ]]; then
      echo implementing; return
    fi
  fi
  echo proposed
}

process_change() {
  # process_change <dir> <changeName> <state:active|archived> <archivedDate|"">
  local dir="$1" name="$2" state="$3" archived_date="$4"
  local metaf="$OUT/$name.meta.json" bodyf="$OUT/$name.body.md"
  local reqf="$OUT/$name.requirements.md"
  local proposal="$dir/proposal.md" design="$dir/design.md" tasks="$dir/tasks.md"
  [[ -f "$proposal" ]] || proposal=""
  [[ -f "$design" ]] || design=""
  [[ -f "$tasks" ]] || tasks=""

  build_requirements "$dir" "$reqf"

  local lifecycle
  if [[ "$state" == "archived" ]]; then
    lifecycle="completed"
  else
    lifecycle="$(lifecycle_for_active "$tasks")"
  fi

  # verification section: capture archive/verification evidence plus any
  # supplementary Markdown artifacts (decision records, checklists, unresolved
  # limitations) that are not the standard proposal/design/tasks or delta specs.
  local verif="$OUT/$name.verification.md"
  : >"$verif"
  if [[ "$state" == "archived" ]]; then
    printf '**Archived:** %s\n\n' "${archived_date:-unknown}" >>"$verif"
  fi
  local extra found_extra=0 base
  while IFS= read -r extra; do
    [[ -z "$extra" ]] && continue
    base="$(basename "$extra")"
    case "$base" in
      proposal.md|design.md|tasks.md) continue;;
    esac
    printf '### Artifact: %s\n\n' "$base" >>"$verif"
    cat "$extra" >>"$verif"
    printf '\n' >>"$verif"
    found_extra=1
  done < <(find "$dir" -maxdepth 1 -name '*.md' | sort)
  if [[ $found_extra -eq 0 ]]; then
    if [[ "$state" == "archived" ]]; then
      printf '_No separate verification artifacts were captured in the original local files._\n' >>"$verif"
    else
      printf '_No verification evidence recorded yet._\n' >>"$verif"
    fi
  fi

  # metadata (created preserved from source .openspec.yaml / archive prefix)
  local created_date; created_date="$(source_created_date "$dir" "${archived_date:-}")"
  jq -nc \
    --arg name "$name" --arg schema "spec-driven" --arg lc "$lifecycle" \
    --arg created "$created_date" \
    --arg arch "${archived_date:-}" '
    {schemaVersion:1, changeName:$name, specSchema:$schema, lifecycle:$lc,
     created:$created, archivedDate: (if $arch=="" then null else $arch end)}' >"$metaf"

  # render body
  adapter render-body --meta "$metaf" \
    ${proposal:+--proposal "$proposal"} \
    --requirements "$reqf" \
    ${design:+--design "$design"} \
    ${tasks:+--tasks "$tasks"} \
    --verification "$verif" >"$bodyf"

  # sensitive-content scan (fails loudly)
  if ! adapter scan-content --body-file "$bodyf" >/dev/null 2>"$OUT/$name.scan.err"; then
    printf 'SENSITIVE  %-40s %s\n' "$name" "$(cat "$OUT/$name.scan.err")" | tee -a "$OUT/summary.txt"
    return 1
  fi

  local size; size="$(wc -c <"$bodyf")"
  printf '%-10s %-9s %-40s body=%sB\n' "$state" "$lifecycle" "$name" "$size" | tee -a "$OUT/summary.txt"

  if [[ "$MODE" == "apply" ]]; then
    # idempotency: reuse existing issue only when it matches the generated payload
    local existing rc
    set +e
    existing="$(adapter find "$name" 2>/dev/null)"; rc=$?
    set -e
    if [[ $rc -eq 0 && -n "$existing" ]]; then
      if ! payload_matches_issue "$bodyf" "$existing" 2>"$OUT/$name.conflict.err"; then
        printf 'CONFLICT   %-40s #%s differs from generated payload: %s\n' "$name" "$existing" "$(tr '\n' ' ' <"$OUT/$name.conflict.err")" | tee -a "$OUT/summary.txt"
        return 1
      fi
      if ! adapter validate "$existing" >/dev/null 2>"$OUT/$name.val.err"; then
        printf 'ERROR      %-40s #%s existing issue invalid: %s\n' "$name" "$existing" "$(tr '\n' ' ' <"$OUT/$name.val.err")" | tee -a "$OUT/summary.txt"
        return 1
      fi
      printf '%s\t%s\t%s\t%s\treused\n' "$name" "$existing" "$state" "$lifecycle" >>"$MAP"
      printf 'REUSED     %-40s #%s\n' "$name" "$existing" | tee -a "$OUT/summary.txt"
      return 0
    fi
    local created_json num
    if ! created_json="$(adapter create --name "$name" --title "$(title_for "$name")" \
        --schema spec-driven --lifecycle "$lifecycle" --created "$created_date" \
        --body-file "$bodyf" 2>"$OUT/$name.create.err")"; then
      printf 'ERROR      %-40s create failed: %s\n' "$name" "$(tr '\n' ' ' <"$OUT/$name.create.err")" | tee -a "$OUT/summary.txt"
      return 1
    fi
    num="$(jq -r '.number' <<<"$created_json")"
    if ! adapter validate "$num" >/dev/null 2>"$OUT/$name.val.err"; then
      printf 'ERROR      %-40s #%s post-write validation failed: %s\n' "$name" "$num" "$(tr '\n' ' ' <"$OUT/$name.val.err")" | tee -a "$OUT/summary.txt"
      return 1
    fi
    printf '%s\t%s\t%s\t%s\tcreated\n' "$name" "$num" "$state" "$lifecycle" >>"$MAP"
    printf 'CREATED    %-40s #%s\n' "$name" "$num" | tee -a "$OUT/summary.txt"
  fi
}

# Normalize section text for comparison (strip trailing whitespace + leading and
# trailing blank lines) so cosmetic differences do not cause false conflicts.
_norm() {
  awk '
    { sub(/[[:space:]]+$/, ""); lines[NR] = $0 }
    END {
      start = 1
      while (start <= NR && lines[start] == "") start++
      end = NR
      while (end >= start && lines[end] == "") end--
      for (i = start; i <= end; i++) print lines[i]
    }
  '
}

# Compare the generated payload against an existing issue's managed sections and
# key metadata. Returns nonzero (conflict) if they differ. This protects against
# silently reusing an issue whose content has diverged from the source change.
payload_matches_issue() {
  local bodyf="$1" issue="$2"
  local expected_body actual_body sec
  expected_body="$(cat "$bodyf")"
  actual_body="$(adapter read "$issue")"
  # metadata fields that must match at migration time
  local ef af k
  for k in changeName specSchema created archivedDate lifecycle; do
    ef="$(printf '%s' "$expected_body" | awk '/<!-- openspec:metadata/{f=1;next} /openspec:metadata-end -->/{f=0} f' | jq -r --arg k "$k" '.[$k]|tostring')"
    af="$(printf '%s' "$actual_body"   | awk '/<!-- openspec:metadata/{f=1;next} /openspec:metadata-end -->/{f=0} f' | jq -r --arg k "$k" '.[$k]|tostring')"
    if [[ "$ef" != "$af" ]]; then
      printf '  metadata.%s differs (expected=%s actual=%s)\n' "$k" "$ef" "$af" >&2
      return 1
    fi
  done
  for sec in proposal requirements design tasks verification; do
    local e a
    e="$(printf '%s' "$expected_body" | awk -v s="$sec" '$0 ~ "<!-- openspec:section:" s ":start -->"{f=1;next} $0 ~ "<!-- openspec:section:" s ":end -->"{f=0} f' | _norm)"
    a="$(printf '%s' "$actual_body"   | awk -v s="$sec" '$0 ~ "<!-- openspec:section:" s ":start -->"{f=1;next} $0 ~ "<!-- openspec:section:" s ":end -->"{f=0} f' | _norm)"
    if [[ "$e" != "$a" ]]; then
      printf '  section %s differs from generated payload\n' "$sec" >&2
      return 1
    fi
  done
  return 0
}

main() {
  case "$MODE" in dry-run|apply) : ;; *) echo "usage: $0 [dry-run|apply]" >&2; exit 2;; esac

  if [[ "$MODE" == "apply" ]]; then
    adapter preflight --write >/dev/null
    adapter ensure-labels >/dev/null
    : >"$MAP"
  fi

  local failures=0 processed=0

  echo "== migration ($MODE) =="
  # active changes (direct children of changes/, excluding archive/)
  local d name
  for d in "$CHANGES"/*/; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    [[ "$name" == "archive" ]] && continue
    [[ -f "$d/proposal.md" || -f "$d/tasks.md" ]] || continue
    processed=$((processed+1))
    if ! process_change "$d" "$name" active ""; then
      failures=$((failures+1))
      printf 'FAILED     %-40s (see diagnostics above)\n' "$name" | tee -a "$OUT/summary.txt"
    fi
  done
  # archived changes
  if [[ -d "$CHANGES/archive" ]]; then
    for d in "$CHANGES/archive"/*/; do
      [[ -d "$d" ]] || continue
      local base; base="$(basename "$d")"
      # strip leading YYYY-MM-DD- date prefix to recover the stable change name
      local date_prefix="" stable="$base"
      if [[ "$base" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-(.+)$ ]]; then
        date_prefix="${BASH_REMATCH[1]}"; stable="${BASH_REMATCH[2]}"
      fi
      processed=$((processed+1))
      if ! process_change "$d" "$stable" archived "$date_prefix"; then
        failures=$((failures+1))
        printf 'FAILED     %-40s (see diagnostics above)\n' "$stable" | tee -a "$OUT/summary.txt"
      fi
    done
  fi

  echo
  echo "== summary =="
  cat "$OUT/summary.txt"
  if [[ "$MODE" == "apply" ]]; then
    echo
    echo "== mapping (change-name  issue  state  lifecycle  action) =="
    cat "$MAP"
  fi
  echo
  echo "processed=$processed failures=$failures"
  # An incomplete migration must not look successful.
  [[ "$failures" -eq 0 ]] || exit 1
}

main
