#!/usr/bin/env bash
# Repository validation: fail when a workflow reintroduces per-change Markdown
# storage under openspec/changes/, or when workflow docs treat that directory as
# the authoritative change store.
#
# GitHub issues are the authoritative OpenSpec change store (see
# openspec/specs/github-issue-change-management/spec.md). Durable capability
# specs under openspec/specs/ and openspec/config.yaml remain source-controlled
# and are NOT change storage.
#
# Usage: check-local-change-storage.sh [--self-test]
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# A line that references openspec/changes is EXEMPT only when it explicitly
# prohibits local storage or describes migration history. Merely mentioning
# "GitHub issue" or "instead of" does NOT exempt a positive local-storage
# instruction.
ALLOW_RE="(never|do not|don't|must not|cannot|no longer|removed|migrat|prohibit|reintroduc|not authoritative|not the authoritative|is not a change store|are not change|guard against)"

# A line references local change storage when it names openspec/changes exactly
# or as a path prefix (child paths included).
STORAGE_RE='openspec/changes(/|[^a-zA-Z0-9_-]|$)'

line_is_allowed() {
  # line_is_allowed <text> ; returns 0 (allowed/exempt) or 1 (positive assumption)
  grep -qiE "$ALLOW_RE" <<<"$1"
}

self_test() {
  local failures=0 t
  local -a POS=(
    'Read the authoritative tasks from openspec/changes/foo/tasks.md'
    'Create a new directory openspec/changes/<name> and add proposal.md'
    'The change lives in openspec/changes and is the source of truth'
    'Store the proposal under openspec/changes/ for review'
  )
  local -a NEG=(
    'Never create a per-change directory under openspec/changes/'
    'Do not create Markdown under openspec/changes/; use the GitHub issue'
    'Change state was migrated from openspec/changes/ to GitHub issues'
    'openspec/changes/ is no longer the authoritative change store'
    'The guard fails if a workflow reintroduces openspec/changes/ storage'
  )
  for t in "${POS[@]}"; do
    if ! grep -qiE "$STORAGE_RE" <<<"$t"; then echo "self-test: POS did not match storage regex: $t" >&2; failures=$((failures+1)); continue; fi
    if line_is_allowed "$t"; then echo "self-test: POSITIVE wording wrongly exempted: $t" >&2; failures=$((failures+1)); fi
  done
  for t in "${NEG[@]}"; do
    if ! grep -qiE "$STORAGE_RE" <<<"$t"; then echo "self-test: NEG did not match storage regex (unexpected): $t" >&2; failures=$((failures+1)); continue; fi
    if ! line_is_allowed "$t"; then echo "self-test: prohibition/history wording wrongly flagged: $t" >&2; failures=$((failures+1)); fi
  done
  if [[ $failures -eq 0 ]]; then
    echo "local-storage-guard: self-test ok"; return 0
  fi
  echo "local-storage-guard: self-test FAILED ($failures)" >&2; return 1
}

if [[ "${1:-}" == "--self-test" ]]; then
  self_test; exit $?
fi

cd "$ROOT"
status=0
note() { printf 'local-storage-guard: %s\n' "$*" >&2; }

# 1. No per-change artifact directories may exist under openspec/changes/.
if [[ -d openspec/changes ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    note "per-change Markdown storage reintroduced: $f"
    status=1
  done < <(find openspec/changes -mindepth 1 \( -name 'proposal.md' -o -name 'tasks.md' -o -name 'design.md' -o -name '.openspec.yaml' \) 2>/dev/null)
  if find openspec/changes -mindepth 2 -type f 2>/dev/null | grep -q .; then
    note "openspec/changes/ still contains change artifacts; changes belong in GitHub issues"
    status=1
  fi
fi

# 2. Workflow instruction files must not treat openspec/changes/ as the
#    authoritative change store. Explicit prohibition / migration-history
#    wording is allowed.
scan_paths=(.github/skills .github/prompts .github/agents README.md CONTRIBUTING.md docs openspec/config.yaml)
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  text="${line#*:}"; text="${text#*:}"   # strip file:line: prefix from grep -n
  if line_is_allowed "$text"; then continue; fi
  note "authoritative local-change assumption: $line"
  status=1
done < <(grep -rniE "$STORAGE_RE" "${scan_paths[@]}" 2>/dev/null || true)

if [[ $status -eq 0 ]]; then
  echo "local-storage-guard: ok — no per-change Markdown storage assumptions found"
fi
exit $status
