#!/usr/bin/env bash
# Mock `gh` for openspec-issue adapter tests. No network, no real GitHub.
# State lives under $MOCK_GH_STORE. Failure injection via $MOCK_GH_FAIL.
set -euo pipefail

STORE="${MOCK_GH_STORE:?MOCK_GH_STORE required}"
mkdir -p "$STORE/issues"
[[ -f "$STORE/counter" ]] || echo 0 >"$STORE/counter"
[[ -f "$STORE/perm" ]] || echo "WRITE" >"$STORE/perm"

fail_mode="${MOCK_GH_FAIL:-}"
case "$fail_mode" in
  connectivity) echo "dial tcp: lookup api.github.com: no such host" >&2; exit 1;;
  auth) echo "gh auth login required: not logged in to any GitHub hosts" >&2; exit 1;;
esac

# strip leading -R <repo>
if [[ "${1:-}" == "-R" ]]; then shift 2; fi

perm_check_write() {
  local p; p="$(cat "$STORE/perm")"
  case "$p" in ADMIN|MAINTAIN|WRITE) return 0;; *) return 1;; esac
}

# Stage-specific failure injection for atomic-rollback tests. Set MOCK_GH_FAIL_ON
# to one of: add-label, remove-label, body, close, reopen, corrupt-body.
# Set MOCK_GH_FAIL_ONCE=1 to inject the failure only on the first matching call
# (simulating a transient failure so restoration can proceed).
fail_on="${MOCK_GH_FAIL_ON:-}"
inject() {
  [[ "$fail_on" == "$1" ]] || return 1
  if [[ -n "${MOCK_GH_FAIL_ONCE:-}" ]]; then
    local marker="$STORE/.injected.$1"
    [[ -e "$marker" ]] && return 1   # already fired once
    : >"$marker"
  fi
  return 0
}

next_num() {
  local n; n="$(cat "$STORE/counter")"; n=$((n+1)); echo "$n" >"$STORE/counter"; echo "$n"
}

issue_dir() { printf '%s/issues/%s' "$STORE" "$1"; }

json_issue() {
  # json_issue <num> ; emits an issue object (labels as {name} array)
  local d; d="$(issue_dir "$1")"
  [[ -d "$d" ]] || { echo "issue not found" >&2; return 1; }
  local body title state labels
  body="$(cat "$d/body" 2>/dev/null || true)"
  title="$(cat "$d/title" 2>/dev/null || true)"
  state="$(cat "$d/state" 2>/dev/null || echo OPEN)"
  labels="$(cat "$d/labels" 2>/dev/null || true)"
  jq -nc --argjson number "$1" --arg body "$body" --arg title "$title" \
     --arg state "$state" --arg labels "$labels" '
     {number:$number, title:$title, body:$body, state:$state,
      labels: ($labels|split("\n")|map(select(length>0))|map({name:.}))}'
}

# REST-shaped issue object for the `api` endpoint (state lowercase).
rest_issue() {
  local d; d="$(issue_dir "$1")"
  [[ -d "$d" ]] || return 1
  local body state labels
  body="$(cat "$d/body" 2>/dev/null || true)"
  state="$(cat "$d/state" 2>/dev/null || echo OPEN)"
  labels="$(cat "$d/labels" 2>/dev/null || true)"
  jq -nc --argjson number "$1" --arg body "$body" \
     --arg state "$(printf '%s' "$state" | tr '[:upper:]' '[:lower:]')" --arg labels "$labels" '
     {number:$number, body:$body, state:$state,
      labels: ($labels|split("\n")|map(select(length>0))|map({name:.}))}'
}

cmd="${1:-}"; shift || true
case "$cmd" in
  api)
    # api [-H h] "repos/o/r/issues?labels=..&state=..&per_page=N&page=P" [--jq expr]
    url=""; jqexpr=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -H|--method|-X|-f|-F) shift 2;;
        --jq) jqexpr="$2"; shift 2;;
        --paginate|--slurp) shift;;
        repos/*|/repos/*) url="$1"; shift;;
        *) shift;;
      esac
    done
    per="$(sed -n 's/.*[?&]per_page=\([0-9][0-9]*\).*/\1/p' <<<"$url")"; per="${per:-30}"
    page="$(sed -n 's/.*[?&]page=\([0-9][0-9]*\).*/\1/p' <<<"$url")"; page="${page:-1}"
    # collect all issue numbers sorted numerically
    nums=()
    for d in "$STORE"/issues/*/; do [[ -d "$d" ]] && nums+=("$(basename "$d")"); done
    IFS=$'\n' sorted=($(printf '%s\n' "${nums[@]}" | sort -n)); unset IFS
    total="${#sorted[@]}"
    start=$(( (page-1) * per ))
    arr="[]"
    idx=0
    for n in "${sorted[@]}"; do
      if [[ $idx -ge $start && $idx -lt $((start+per)) ]]; then
        obj="$(rest_issue "$n")" && arr="$(jq -c --argjson o "$obj" '. + [$o]' <<<"$arr")"
      fi
      idx=$((idx+1))
    done
    if [[ -n "$jqexpr" ]]; then jq -r "$jqexpr" <<<"$arr"; else printf '%s' "$arr"; fi
    exit 0;;
  auth)
    # auth status
    echo "Logged in to github.com (mock)"; exit 0;;
  repo)
    # repo view --json <fields> --jq <expr>
    shift || true # 'view'
    local_json=""; jqexpr=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --json) shift 2;;
        --jq) jqexpr="$2"; shift 2;;
        *) shift;;
      esac
    done
    obj="$(jq -nc --arg p "$(cat "$STORE/perm")" \
      '{nameWithOwner:"mock/repo", viewerPermission:$p}')"
    if [[ -n "$jqexpr" ]]; then jq -r "$jqexpr" <<<"$obj"; else printf '%s' "$obj"; fi
    exit 0;;
  label)
    sub="${1:-}"; shift || true
    [[ -f "$STORE/labels" ]] || : >"$STORE/labels"
    case "$sub" in
      list)
        jqexpr=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --json|--limit) shift 2;;
            --jq) jqexpr="$2"; shift 2;;
            *) shift;;
          esac
        done
        arr="$(jq -R -s -c 'split("\n")|map(select(length>0))|map({name:.})' <"$STORE/labels")"
        if [[ -n "$jqexpr" ]]; then jq -r "$jqexpr" <<<"$arr"; else printf '%s' "$arr"; fi
        exit 0;;
      create)
        perm_check_write || { echo "403 permission denied creating label" >&2; exit 1; }
        name="$1"; shift
        if grep -qxF "$name" "$STORE/labels" 2>/dev/null; then
          echo "label already exists" >&2; exit 1
        fi
        echo "$name" >>"$STORE/labels"
        exit 0;;
      edit)
        perm_check_write || { echo "403 permission denied editing label" >&2; exit 1; }
        name="$1"
        grep -qxF "$name" "$STORE/labels" 2>/dev/null || { echo "label not found" >&2; exit 1; }
        exit 0;;
      *) exit 0;;
    esac;;
  issue)
    sub="${1:-}"; shift || true
    case "$sub" in
      list)
        # --label X --state Y --limit N --json f1,f2 [--jq expr]
        state="all"; jqexpr=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --label|--limit|--json) shift 2;;
            --state) state="$2"; shift 2;;
            --jq) jqexpr="$2"; shift 2;;
            *) shift;;
          esac
        done
        arr="[]"
        for d in "$STORE"/issues/*/; do
          [[ -d "$d" ]] || continue
          num="$(basename "$d")"
          st="$(cat "$d/state" 2>/dev/null || echo OPEN)"
          stl="$(printf '%s' "$st" | tr '[:upper:]' '[:lower:]')"
          if [[ "$state" != "all" && "$stl" != "$state" ]]; then continue; fi
          obj="$(json_issue "$num")"
          arr="$(jq -c --argjson o "$obj" '. + [$o]' <<<"$arr")"
        done
        if [[ -n "$jqexpr" ]]; then jq -r "$jqexpr" <<<"$arr"; else printf '%s' "$arr"; fi
        exit 0;;
      view)
        num="$1"; shift
        jqexpr=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --json) shift 2;;
            --jq) jqexpr="$2"; shift 2;;
            *) shift;;
          esac
        done
        obj="$(json_issue "$num")" || { echo "no issue $num" >&2; exit 1; }
        if [[ -n "$jqexpr" ]]; then jq -r "$jqexpr" <<<"$obj"; else printf '%s' "$obj"; fi
        exit 0;;
      create)
        perm_check_write || { echo "403 you do not have permission to create issues" >&2; exit 1; }
        title=""; bodyfile=""; labels=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --title) title="$2"; shift 2;;
            --body-file) bodyfile="$2"; shift 2;;
            --body) bodyfile=""; body_inline="$2"; shift 2;;
            --label) labels="$2"; shift 2;;
            *) shift;;
          esac
        done
        num="$(next_num)"; d="$(issue_dir "$num")"; mkdir -p "$d"
        printf '%s' "$title" >"$d/title"
        if [[ -n "$bodyfile" ]]; then cat "$bodyfile" >"$d/body"; else printf '%s' "${body_inline:-}" >"$d/body"; fi
        echo "OPEN" >"$d/state"
        printf '%s\n' "${labels//,/$'\n'}" | sed '/^$/d' >"$d/labels"
        echo "https://github.com/mock/repo/issues/$num"
        exit 0;;
      edit)
        perm_check_write || { echo "403 permission denied editing issue" >&2; exit 1; }
        num="$1"; shift; d="$(issue_dir "$num")"
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --body-file)
              inject body && { echo "mock injected failure: body edit" >&2; exit 1; }
              if inject corrupt-body; then
                # Write a corrupted body (drop a section end marker) to trigger
                # the caller's post-write validation failure + rollback.
                sed 's/<!-- openspec:section:tasks:end -->//' "$2" >"$d/body"
              else
                cat "$2" >"$d/body"
              fi
              shift 2;;
            --add-label)
              inject add-label && { echo "mock injected failure: add-label" >&2; exit 1; }
              grep -qxF "$2" "$d/labels" 2>/dev/null || echo "$2" >>"$d/labels"; shift 2;;
            --remove-label)
              inject remove-label && { echo "mock injected failure: remove-label" >&2; exit 1; }
              if [[ -f "$d/labels" ]]; then grep -vxF "$2" "$d/labels" >"$d/labels.tmp" || true; mv "$d/labels.tmp" "$d/labels"; fi
              shift 2;;
            *) shift;;
          esac
        done
        echo "https://github.com/mock/repo/issues/$num"
        exit 0;;
      close)
        perm_check_write || { echo "403 permission denied" >&2; exit 1; }
        inject close && { echo "mock injected failure: close" >&2; exit 1; }
        num="$1"; echo "CLOSED" >"$(issue_dir "$num")/state"; exit 0;;
      reopen)
        perm_check_write || { echo "403 permission denied" >&2; exit 1; }
        inject reopen && { echo "mock injected failure: reopen" >&2; exit 1; }
        num="$1"; echo "OPEN" >"$(issue_dir "$num")/state"; exit 0;;
      *) echo "mock gh: unknown issue subcommand: $sub" >&2; exit 1;;
    esac;;
  *)
    echo "mock gh: unknown command: $cmd" >&2; exit 1;;
esac
