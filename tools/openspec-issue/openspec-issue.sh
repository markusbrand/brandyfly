#!/usr/bin/env bash
# OpenSpec GitHub-issue change adapter.
#
# Single repository-owned integration surface for storing OpenSpec change state
# in GitHub issues. See CONTRACT.md for the schema, labels, and operations.
#
# There is no local Markdown fallback: every failure is explicit and leaves
# remote state unchanged.
set -euo pipefail

OPENSPEC_ISSUE_SCHEMA_VERSION=1
GH_BIN="${OPENSPEC_ISSUE_GH:-gh}"
BODY_LIMIT="${OPENSPEC_ISSUE_BODY_LIMIT:-65536}"

DISCOVERY_LABEL="openspec"
LIFECYCLE_LABELS=("openspec:proposed" "openspec:ready" "openspec:implementing" "openspec:completed")
SECTIONS=(proposal requirements design tasks verification)

# Exit codes
EX_USAGE=2
EX_NOT_FOUND=3
EX_DUPLICATE=4
EX_MALFORMED=5
EX_SENSITIVE=6
EX_BODYSIZE=7
EX_PERMISSION=8
EX_CONNECTIVITY=9
EX_AUTH=10
EX_VALIDATE=11

err() { printf 'openspec-issue: %s\n' "$*" >&2; }
die() { local code="$1"; shift; err "$*"; exit "$code"; }

WORKDIR=""
cleanup() { [[ -n "$WORKDIR" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR" || true; }
trap cleanup EXIT
ensure_workdir() {
  if [[ -z "$WORKDIR" ]]; then
    WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/openspec-issue.XXXXXX")"
  fi
}

repo_args() {
  if [[ -n "${OPENSPEC_ISSUE_REPO:-}" ]]; then
    printf -- '-R\n%s\n' "$OPENSPEC_ISSUE_REPO"
  fi
}

gh_call() {
  # Run gh, classifying connectivity/auth failures explicitly.
  local out rc
  mapfile -t _repo < <(repo_args)
  set +e
  out="$("$GH_BIN" "${_repo[@]}" "$@" 2>&1)"
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    if grep -qiE 'could not resolve|network is unreachable|dial tcp|timeout|connection refused|no such host' <<<"$out"; then
      err "$out"; exit "$EX_CONNECTIVITY"
    fi
    if grep -qiE 'authentication|not logged|bad credentials|401|gh auth login' <<<"$out"; then
      err "$out"; exit "$EX_AUTH"
    fi
    if grep -qiE 'permission|403|must have admin|resource not accessible|not authorized' <<<"$out"; then
      err "$out"; exit "$EX_PERMISSION"
    fi
    err "$out"; return $rc
  fi
  printf '%s' "$out"
}

# ---- sensitive content -------------------------------------------------------

scan_content_file() {
  local file="$1" hit=""
  # Credentials / tokens
  if grep -nEi 'ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[A-Za-z0-9-]+' "$file" >/dev/null; then
    hit="credential/token"
  elif grep -nEi '(password|passwd|secret|api[_-]?key|access[_-]?token|client[_-]?secret)[[:space:]]*[:=][[:space:]]*[^[:space:]"'"'"']{6,}' "$file" >/dev/null; then
    hit="embedded secret assignment"
  elif grep -nEi 'private[_-]?flight|flight[_-]?log[[:space:]]*[:=]|pilot[_-]?(gps|position|track)|\.igc\b' "$file" >/dev/null; then
    hit="private flight data"
  fi
  if [[ -n "$hit" ]]; then
    die "$EX_SENSITIVE" "refusing to publish: detected $hit; remove it before publishing (value not echoed)"
  fi
}

# ---- body rendering / parsing -----------------------------------------------

render_body() {
  # render_body <metadata-json> <section-file:proposal> ... builds a full body.
  # Args after metadata are section files in the fixed SECTIONS order (may be
  # empty string to emit an empty section).
  local meta="$1"; shift
  printf '<!-- openspec:metadata\n'
  printf '%s\n' "$meta"
  printf 'openspec:metadata-end -->\n\n'
  local i=0 sec file
  for sec in "${SECTIONS[@]}"; do
    file="${1:-}"; shift || true
    printf '<!-- openspec:section:%s:start -->\n' "$sec"
    if [[ -n "$file" && -f "$file" && -s "$file" ]]; then
      cat "$file"
      # ensure the section content ends with a newline before the end marker
      [[ $(tail -c1 "$file" | wc -l) -eq 0 ]] && printf '\n'
    fi
    printf '<!-- openspec:section:%s:end -->\n\n' "$sec"
    i=$((i+1))
  done
}

extract_metadata() {
  # stdin: full body -> stdout: metadata JSON (content of the first block)
  awk '/^<!-- openspec:metadata$/{f=1;next} /^openspec:metadata-end -->$/{f=0} f'
}

extract_section() {
  # extract_section <section> ; stdin body -> inner content
  local sec="$1"
  awk -v s="$sec" '
    $0 ~ "<!-- openspec:section:" s ":start -->" {f=1;next}
    $0 ~ "<!-- openspec:section:" s ":end -->" {f=0}
    f {print}
  '
}

is_date() {
  # strict YYYY-MM-DD calendar date
  [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
  date -d "$1" +%Y-%m-%d >/dev/null 2>&1 || return 1
  return 0
}

validate_metadata_json() {
  # validate_metadata_json <json> [context]  -> die EX_MALFORMED on any problem
  local meta="$1" ctx="${2:-issue body}"
  jq -e 'type=="object"' >/dev/null 2>&1 <<<"$meta" \
    || die "$EX_MALFORMED" "$ctx: metadata is not a JSON object"
  local sv cn ss lc cr adkey ad
  sv="$(jq -r '.schemaVersion|tostring' <<<"$meta")"
  cn="$(jq -r '.changeName // ""' <<<"$meta")"
  ss="$(jq -r '.specSchema // ""' <<<"$meta")"
  lc="$(jq -r '.lifecycle // ""' <<<"$meta")"
  cr="$(jq -r '.created // ""' <<<"$meta")"
  adkey="$(jq -r 'has("archivedDate")' <<<"$meta")"
  ad="$(jq -r '.archivedDate // "null"' <<<"$meta")"
  [[ "$sv" == "1" ]] || die "$EX_MALFORMED" "$ctx: schemaVersion must be exactly 1 (got '$sv')"
  [[ "$cn" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] \
    || die "$EX_MALFORMED" "$ctx: changeName must be nonempty kebab-case (got '$cn')"
  [[ -n "$ss" ]] || die "$EX_MALFORMED" "$ctx: specSchema must be nonempty"
  printf '%s\n' " ${LIFECYCLE_LABELS[*]} " | grep -qF " openspec:$lc " \
    || die "$EX_MALFORMED" "$ctx: lifecycle invalid (got '$lc')"
  is_date "$cr" || die "$EX_MALFORMED" "$ctx: created must be a valid YYYY-MM-DD date (got '$cr')"
  [[ "$adkey" == "true" ]] \
    || die "$EX_MALFORMED" "$ctx: archivedDate key is required (null or YYYY-MM-DD)"
  if [[ "$ad" != "null" ]]; then
    is_date "$ad" || die "$EX_MALFORMED" "$ctx: archivedDate must be null or a valid YYYY-MM-DD date (got '$ad')"
  fi
}

validate_body_string() {
  # validate_body_string <body>  -> die EX_MALFORMED on any structural problem
  local body="$1" meta
  # Exactly one metadata block, correctly delimited, no duplicates/nesting.
  local mstart mend
  mstart="$(grep -cE '^<!-- openspec:metadata$' <<<"$body" || true)"
  mend="$(grep -cE '^openspec:metadata-end -->$' <<<"$body" || true)"
  [[ "$mstart" == "1" ]] || die "$EX_MALFORMED" "issue body must contain exactly one metadata block start (found $mstart)"
  [[ "$mend" == "1" ]] || die "$EX_MALFORMED" "issue body must contain exactly one metadata block end (found $mend)"
  # The end must come after the start.
  local sline eline
  sline="$(grep -nE '^<!-- openspec:metadata$' <<<"$body" | head -1 | cut -d: -f1)"
  eline="$(grep -nE '^openspec:metadata-end -->$' <<<"$body" | head -1 | cut -d: -f1)"
  [[ "$sline" -lt "$eline" ]] || die "$EX_MALFORMED" "issue metadata block markers are out of order"
  meta="$(printf '%s' "$body" | extract_metadata)"
  validate_metadata_json "$meta"
  # The full sequence of section markers must exactly equal the expected order,
  # which rejects missing, duplicate, out-of-order, overlapping, or nested markers.
  local seq expected s
  seq="$(printf '%s\n' "$body" | grep -oE '<!-- openspec:section:[a-z]+:(start|end) -->' \
    | sed -E 's/<!-- openspec:section:([a-z]+):(start|end) -->/\1:\2/')"
  expected="$(for s in "${SECTIONS[@]}"; do printf '%s:start\n%s:end\n' "$s" "$s"; done)"
  [[ "$seq" == "$expected" ]] || die "$EX_MALFORMED" \
    "issue section markers are missing, duplicated, out of order, overlapping, or nested"
}

check_body_size() {
  local file="$1" size
  size="$(wc -c <"$file")"
  if [[ "$size" -gt "$BODY_LIMIT" ]]; then
    die "$EX_BODYSIZE" "rendered issue body is ${size} bytes, exceeding limit ${BODY_LIMIT}; keep sections concise"
  fi
}

# ---- gh helpers --------------------------------------------------------------

issue_body() {
  gh_call issue view "$1" --json body --jq '.body'
}

issue_labels() {
  gh_call issue view "$1" --json labels --jq '.labels[].name'
}

issue_state() {
  gh_call issue view "$1" --json state --jq '.state'
}

# ---- commands ----------------------------------------------------------------

cmd_preflight() {
  local write=0
  [[ "${1:-}" == "--write" ]] && write=1
  gh_call auth status >/dev/null 2>&1 || true
  # Resolve repo (also validates connectivity + auth via classification).
  local repo
  repo="$(gh_call repo view --json nameWithOwner --jq '.nameWithOwner')"
  if [[ $write -eq 1 ]]; then
    local perm
    perm="$(gh_call repo view --json viewerPermission --jq '.viewerPermission')"
    case "$perm" in
      ADMIN|MAINTAIN|WRITE) : ;;
      *) die "$EX_PERMISSION" "authenticated user lacks issue write permission on $repo (viewerPermission=$perm)";;
    esac
  fi
  jq -nc --arg repo "$repo" '{ok:true, repo:$repo}'
}

label_color_desc() {
  case "$1" in
    openspec) printf '5319e7\tOpenSpec change tracked as a GitHub issue';;
    openspec:proposed) printf 'fbca04\tOpenSpec change: proposal/planning';;
    openspec:ready) printf '0e8a16\tOpenSpec change: planned, ready to apply';;
    openspec:implementing) printf '1d76db\tOpenSpec change: implementation in progress';;
    openspec:completed) printf '6f42c1\tOpenSpec change: verified and archived';;
    *) printf 'ededed\t';;
  esac
}

cmd_ensure_labels() {
  local l existing color desc cd
  # Discover existing labels once. gh_call classifies connectivity/auth/permission.
  existing="$(gh_call label list --limit 200 --json name --jq '.[].name')"
  for l in "$DISCOVERY_LABEL" "${LIFECYCLE_LABELS[@]}"; do
    cd="$(label_color_desc "$l")"; color="${cd%%$'\t'*}"; desc="${cd#*$'\t'}"
    if grep -qxF "$l" <<<"$existing"; then
      # Already present; keep colour/description current (non-fatal if edit fails).
      gh_call label edit "$l" --color "$color" --description "$desc" >/dev/null 2>&1 || true
    else
      # Create through classified handling so permission/connectivity errors surface.
      gh_call label create "$l" --color "$color" --description "$desc" >/dev/null
    fi
  done
  # Verify every required label now exists; fail explicitly otherwise.
  existing="$(gh_call label list --limit 200 --json name --jq '.[].name')"
  for l in "$DISCOVERY_LABEL" "${LIFECYCLE_LABELS[@]}"; do
    grep -qxF "$l" <<<"$existing" || die "$EX_VALIDATE" "label '$l' missing after ensure-labels"
  done
  jq -nc '{ok:true}'
}

OPENSPEC_ISSUES_JSON=""
load_openspec_issues() {
  # Populate the global OPENSPEC_ISSUES_JSON with EVERY OpenSpec-labeled issue
  # (all pages) as a normalized array of {number, body, state, labels[]}. Call
  # this as a BARE statement (never inside $(...)) so gh_call connectivity/auth/
  # permission exits propagate instead of being swallowed by a subshell.
  # Pages are accumulated via files (not argv) because issue bodies are large.
  local owner_repo per page count pagesdir
  if [[ -n "${OPENSPEC_ISSUE_REPO:-}" ]]; then
    owner_repo="$OPENSPEC_ISSUE_REPO"
  else
    owner_repo="$(gh_call repo view --json nameWithOwner --jq '.nameWithOwner')"
  fi
  ensure_workdir
  pagesdir="$WORKDIR/pages"; rm -rf "$pagesdir"; mkdir -p "$pagesdir"
  per="${OPENSPEC_ISSUE_PER_PAGE:-100}"; page=1
  while :; do
    gh_call api -H "Accept: application/vnd.github+json" \
      "repos/$owner_repo/issues?labels=$DISCOVERY_LABEL&state=all&per_page=$per&page=$page" \
      >"$pagesdir/p$(printf '%05d' "$page").json"
    count="$(jq 'length' <"$pagesdir/p$(printf '%05d' "$page").json")"
    [[ "$count" -eq 0 ]] && break
    [[ "$count" -lt "$per" ]] && break
    page=$((page+1))
    [[ "$page" -gt 10000 ]] && break   # safety valve
  done
  local pagefiles=("$pagesdir"/p*.json)
  if [[ "${#pagefiles[@]}" -eq 0 || ! -e "${pagefiles[0]}" ]]; then
    OPENSPEC_ISSUES_JSON="[]"
  else
    OPENSPEC_ISSUES_JSON="$(jq -s '
      (add // [])
      | [ .[] | select(has("pull_request")|not)
          | {number, body:(.body // ""), state:(.state|ascii_upcase),
             labels:[.labels[].name]} ]' "${pagefiles[@]}")"
  fi
}

assert_issues_wellformed() {
  # Parse/validate every labeled issue; stop explicitly on the first malformed
  # one (the spec requires refusing malformed OpenSpec issues, and a malformed
  # duplicate must still block creation).
  local json="$1" n body msg rc
  while IFS= read -r n; do
    [[ -z "$n" ]] && continue
    body="$(jq -r --argjson N "$n" '.[] | select(.number==$N) | .body' <<<"$json")"
    set +e
    msg="$( ( validate_body_string "$body" ) 2>&1 1>/dev/null )"; rc=$?
    set -e
    if [[ $rc -ne 0 ]]; then
      die "$EX_MALFORMED" "issue #$n is labeled '$DISCOVERY_LABEL' but is malformed: ${msg#openspec-issue: }"
    fi
  done < <(jq -r '.[].number' <<<"$json")
}

filter_issue_numbers() {
  # filter_issue_numbers <name> <json> -> matching issue numbers
  local name="$1" json="$2"
  jq -r --arg n "$name" '
    .[] | . as $i
    | ($i.body // "")
    | capture("<!-- openspec:metadata\\n(?<m>[\\s\\S]*?)\\nopenspec:metadata-end -->"; "m")?.m as $meta
    | select($meta != null)
    | ($meta | fromjson? // {}) as $md
    | select($md.changeName == $n)
    | $i.number
  ' <<<"$json" 2>/dev/null | grep -E '^[0-9]+$' || true
}

cmd_find() {
  local name="${1:?change name required}" out
  load_openspec_issues
  assert_issues_wellformed "$OPENSPEC_ISSUES_JSON"
  out="$(filter_issue_numbers "$name" "$OPENSPEC_ISSUES_JSON")"
  mapfile -t nums < <(printf '%s' "$out" | grep -E '^[0-9]+$' || true)
  if [[ "${#nums[@]}" -eq 0 ]]; then
    die "$EX_NOT_FOUND" "no OpenSpec issue found for change '$name'"
  elif [[ "${#nums[@]}" -gt 1 ]]; then
    die "$EX_DUPLICATE" "duplicate OpenSpec issues for change '$name': ${nums[*]}"
  fi
  printf '%s\n' "${nums[0]}"
}

cmd_list() {
  local state="all"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --state) state="$2"; shift 2;;
      *) die "$EX_USAGE" "unknown arg to list: $1";;
    esac
  done
  load_openspec_issues
  assert_issues_wellformed "$OPENSPEC_ISSUES_JSON"
  jq -r --arg state "$state" '
    def meta: (capture("<!-- openspec:metadata\\n(?<m>[\\s\\S]*?)\\nopenspec:metadata-end -->"; "m")?.m // "{}") | (fromjson? // {});
    def tasks($b): [ ($b | [scan("(?m)^[[:space:]]*- \\[[xX]\\]")] | length),
                     ($b | [scan("(?m)^[[:space:]]*- \\[( |x|X)\\]")] | length) ];
    [ .[]
      | select($state=="all" or (.state|ascii_downcase)==$state)
      | . as $i | (.body // "") as $b | ($b | meta) as $md
      | { number: $i.number, name: ($md.changeName // "?"),
          lifecycle: ($md.lifecycle // "?"), state: ($i.state|ascii_downcase),
          tasksDone: (tasks($b)[0]), tasksTotal: (tasks($b)[1]) } ]
  ' <<<"$OPENSPEC_ISSUES_JSON"
}

cmd_create() {
  local name="" title="" schema="" lifecycle="" created="" bodyfile=""
  local schema_supplied=0 lifecycle_supplied=0 created_supplied=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2;;
      --title) title="$2"; shift 2;;
      --schema) schema="$2"; schema_supplied=1; shift 2;;
      --lifecycle) lifecycle="$2"; lifecycle_supplied=1; shift 2;;
      --created) created="$2"; created_supplied=1; shift 2;;
      --body-file) bodyfile="$2"; shift 2;;
      *) die "$EX_USAGE" "unknown arg to create: $1";;
    esac
  done
  [[ -n "$name" && -n "$title" && -n "$bodyfile" ]] || die "$EX_USAGE" "create requires --name, --title, --body-file"
  [[ -f "$bodyfile" ]] || die "$EX_USAGE" "body file not found: $bodyfile"

  # Duplicate detection (idempotency): refuse if the change name already exists.
  # Discovery validates every labeled issue, so a malformed duplicate still blocks.
  local existing_out
  load_openspec_issues
  assert_issues_wellformed "$OPENSPEC_ISSUES_JSON"
  existing_out="$(filter_issue_numbers "$name" "$OPENSPEC_ISSUES_JSON")"
  mapfile -t existing < <(printf '%s' "$existing_out" | grep -E '^[0-9]+$' || true)
  if [[ "${#existing[@]}" -gt 0 ]]; then
    die "$EX_DUPLICATE" "change '$name' already has issue(s): ${existing[*]}"
  fi

  scan_content_file "$bodyfile"
  validate_body_string "$(cat "$bodyfile")"

  # Reconcile the CLI flags with the authoritative body metadata so the created
  # labels can never disagree with the body.
  local meta bodyname meta_schema meta_lifecycle meta_created
  meta="$(extract_metadata <"$bodyfile")"
  bodyname="$(jq -r '.changeName // ""' <<<"$meta")"
  meta_schema="$(jq -r '.specSchema // ""' <<<"$meta")"
  meta_lifecycle="$(jq -r '.lifecycle // ""' <<<"$meta")"
  meta_created="$(jq -r '.created // ""' <<<"$meta")"

  [[ "$bodyname" == "$name" ]] || die "$EX_USAGE" \
    "--name '$name' does not match body metadata changeName '$bodyname'"
  # metadata lifecycle must be a known lifecycle
  printf '%s\n' " ${LIFECYCLE_LABELS[*]} " | grep -qF " openspec:$meta_lifecycle " \
    || die "$EX_USAGE" "body metadata lifecycle '$meta_lifecycle' is not a valid lifecycle"
  if [[ $schema_supplied -eq 1 && "$schema" != "$meta_schema" ]]; then
    die "$EX_USAGE" "--schema '$schema' does not match body metadata specSchema '$meta_schema'"
  fi
  if [[ $lifecycle_supplied -eq 1 && "$lifecycle" != "$meta_lifecycle" ]]; then
    die "$EX_USAGE" "--lifecycle '$lifecycle' does not match body metadata lifecycle '$meta_lifecycle'"
  fi
  if [[ $created_supplied -eq 1 && "$created" != "$meta_created" ]]; then
    die "$EX_USAGE" "--created '$created' does not match body metadata created '$meta_created'"
  fi
  # Labels always derive from the authoritative metadata lifecycle.
  lifecycle="$meta_lifecycle"

  check_body_size "$bodyfile"

  local num url
  if [[ "$lifecycle" == "completed" ]]; then
    # A completed issue must be closed. Create it in a valid OPEN staged state
    # first, then complete it through the safe, atomically-recoverable
    # implementing -> completed transition. This guarantees we never leave a
    # created-but-invalid (label=completed/state=open) issue that blocks retry.
    ensure_workdir
    local staged="$WORKDIR/create.staged.md"
    rewrite_metadata_field "$bodyfile" lifecycle implementing >"$staged"
    validate_body_string "$(cat "$staged")"
    url="$(gh_call issue create --title "$title" --body-file "$staged" \
      --label "$DISCOVERY_LABEL,openspec:implementing")"
    num="$(grep -oE '[0-9]+$' <<<"$url" | tail -1)"
    [[ -n "$num" ]] || die "$EX_VALIDATE" "could not determine created issue number from: $url"
    # Confirm the staged issue is valid before attempting completion.
    if ! validate_issue_quiet "$num"; then
      die "$EX_VALIDATE" "issue #$num was created but the staged state is invalid"
    fi
    # Complete via the transition (atomic rollback restores implementing/open on failure).
    if ! ( cmd_set_lifecycle "$num" completed ) >/dev/null 2>"$WORKDIR/complete.err"; then
      err "$(cat "$WORKDIR/complete.err")"
      die "$EX_VALIDATE" "issue #$num created and left in a valid recoverable 'implementing' (open) state, but completion failed; re-run 'set-lifecycle $num completed' to finish (creation did NOT succeed)"
    fi
    _validate_issue "$num" >/dev/null
    jq -nc --argjson n "$num" --arg url "$url" '{ok:true, number:$n, url:$url, staged:true}'
    return 0
  fi

  local labels="$DISCOVERY_LABEL,openspec:$lifecycle"
  url="$(gh_call issue create --title "$title" --body-file "$bodyfile" --label "$labels")"
  num="$(grep -oE '[0-9]+$' <<<"$url" | tail -1)"
  [[ -n "$num" ]] || die "$EX_VALIDATE" "could not determine created issue number from: $url"
  # post-write validation
  _validate_issue "$num" >/dev/null
  jq -nc --argjson n "$num" --arg url "$url" '{ok:true, number:$n, url:$url}'
}

rewrite_metadata_field() {
  # rewrite_metadata_field <bodyfile> <key> <value> ; stdout: body with the one
  # metadata field replaced (value treated as a JSON string; 'null' -> null).
  local bodyfile="$1" key="$2" value="$3" meta newmeta
  meta="$(extract_metadata <"$bodyfile")"
  if [[ "$value" == "null" ]]; then
    newmeta="$(jq -c --arg k "$key" '.[$k]=null' <<<"$meta")"
  else
    newmeta="$(jq -c --arg k "$key" --arg v "$value" '.[$k]=$v' <<<"$meta")"
  fi
  ensure_workdir
  printf '%s\n' "$newmeta" >"$WORKDIR/rmf.meta"
  awk -v mf="$WORKDIR/rmf.meta" '
    BEGIN { while ((getline line < mf) > 0) m = m line "\n" }
    /^<!-- openspec:metadata$/ { print; printf "%s", m; skip=1; next }
    /^openspec:metadata-end -->$/ { skip=0; print; next }
    skip { next }
    { print }
  ' "$bodyfile"
}

cmd_read() { issue_body "${1:?issue number required}"; }

cmd_get_section() {
  local num="${1:?issue}" sec="${2:?section}"
  issue_body "$num" | extract_section "$sec"
}

cmd_set_section() {
  local num="${1:?issue}" sec="${2:?section}"; shift 2
  local bodyfile=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --body-file) bodyfile="$2"; shift 2;;
      *) die "$EX_USAGE" "unknown arg: $1";;
    esac
  done
  [[ -n "$bodyfile" && -f "$bodyfile" ]] || die "$EX_USAGE" "set-section requires --body-file"
  printf '%s\n' " ${SECTIONS[*]} " | grep -qF " $sec " || die "$EX_USAGE" "unknown section: $sec"

  scan_content_file "$bodyfile"
  # read latest immediately before mutation
  local body
  body="$(issue_body "$num")"
  validate_body_string "$body"

  ensure_workdir; local work="$WORKDIR"
  printf '%s' "$body" >"$work/body"
  cp "$bodyfile" "$work/new"

  # Rebuild: everything before start marker + new content + everything after end marker.
  awk -v s="$sec" -v nf="$work/new" '
    BEGIN { while ((getline line < nf) > 0) newc = newc line "\n" }
    $0 ~ "<!-- openspec:section:" s ":start -->" { print; printf "%s", newc; skip=1; next }
    $0 ~ "<!-- openspec:section:" s ":end -->" { skip=0; print; next }
    skip { next }
    { print }
  ' "$work/body" >"$work/rebuilt"

  validate_body_string "$(cat "$work/rebuilt")"
  check_body_size "$work/rebuilt"
  edit_body_or_rollback "$num" "$work/rebuilt" "$work/body" || return $?
  jq -nc --argjson n "$num" --arg s "$sec" '{ok:true, number:$n, section:$s}'
}

cmd_set_metadata() {
  local num="${1:?issue}"; shift
  local key="" value=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --key) key="$2"; shift 2;;
      --value) value="$2"; shift 2;;
      *) die "$EX_USAGE" "unknown arg: $1";;
    esac
  done
  [[ -n "$key" ]] || die "$EX_USAGE" "set-metadata requires --key"
  local body meta newmeta
  body="$(issue_body "$num")"
  validate_body_string "$body"
  meta="$(printf '%s' "$body" | extract_metadata)"
  if [[ "$value" == "null" ]]; then
    newmeta="$(jq --arg k "$key" '.[$k]=null' <<<"$meta")"
  else
    newmeta="$(jq --arg k "$key" --arg v "$value" '.[$k]=$v' <<<"$meta")"
  fi
  ensure_workdir; local work="$WORKDIR"
  printf '%s' "$body" >"$work/body"
  printf '%s\n' "$newmeta" >"$work/meta"
  awk -v mf="$work/meta" '
    BEGIN { while ((getline line < mf) > 0) m = m line "\n" }
    /<!-- openspec:metadata/ { print; printf "%s", m; skip=1; next }
    /openspec:metadata-end -->/ { skip=0; print; next }
    skip { next }
    { print }
  ' "$work/body" >"$work/rebuilt"
  validate_body_string "$(cat "$work/rebuilt")"
  check_body_size "$work/rebuilt"
  edit_body_or_rollback "$num" "$work/rebuilt" "$work/body" || return $?
  jq -nc --argjson n "$num" '{ok:true, number:$n}'
}

lifecycle_transition_allowed() {
  # lifecycle_transition_allowed <current> <target>
  local cur="$1" tgt="$2"
  [[ "$cur" == "$tgt" ]] && return 0   # idempotent no-op
  case "$cur" in
    proposed)     [[ "$tgt" == "ready" ]] ;;
    ready)        [[ "$tgt" == "proposed" || "$tgt" == "implementing" ]] ;;
    implementing) [[ "$tgt" == "proposed" || "$tgt" == "ready" || "$tgt" == "completed" ]] ;;
    completed)    return 1 ;;  # terminal
    *)            return 1 ;;
  esac
}

cmd_set_lifecycle() {
  local num="${1:?issue}" lifecycle="${2:?lifecycle}"
  printf '%s\n' " ${LIFECYCLE_LABELS[*]} " | grep -qF " openspec:$lifecycle " \
    || die "$EX_USAGE" "unknown lifecycle: $lifecycle"

  # Read current lifecycle and enforce the documented transition rules.
  local body cur
  body="$(issue_body "$num")"
  validate_body_string "$body"
  cur="$(printf '%s' "$body" | extract_metadata | jq -r '.lifecycle // ""')"
  if ! lifecycle_transition_allowed "$cur" "$lifecycle"; then
    die "$EX_USAGE" "invalid lifecycle transition '$cur' -> '$lifecycle' (allowed: proposed->ready; ready->proposed|implementing; implementing->proposed|ready|completed; completed is terminal)"
  fi
  if [[ "$cur" == "$lifecycle" ]]; then
    _validate_issue "$num" >/dev/null
    jq -nc --argjson n "$num" --arg l "$lifecycle" '{ok:true, number:$n, lifecycle:$l, noop:true}'
    return 0
  fi

  # Capture the full prior state so any failure across label / body / state /
  # post-validation stages can be atomically rolled back.
  ensure_workdir
  local prior_body_file="$WORKDIR/lc.prior.body"
  printf '%s' "$body" >"$prior_body_file"
  local prior_state prior_lifecycle
  prior_state="$(issue_state "$num" | tr '[:upper:]' '[:lower:]')"
  prior_lifecycle="$cur"

  restore_lifecycle_state() {
    # Best-effort restoration of body, labels, and open/closed state.
    gh_call issue edit "$num" --body-file "$prior_body_file" >/dev/null 2>&1 || true
    local x
    for x in "${LIFECYCLE_LABELS[@]}"; do
      [[ "$x" == "openspec:$prior_lifecycle" ]] && continue
      gh_call issue edit "$num" --remove-label "$x" >/dev/null 2>&1 || true
    done
    gh_call issue edit "$num" --add-label "openspec:$prior_lifecycle" >/dev/null 2>&1 || true
    if [[ "$prior_state" == "closed" ]]; then
      gh_call issue close "$num" >/dev/null 2>&1 || true
    else
      gh_call issue reopen "$num" >/dev/null 2>&1 || true
    fi
  }

  do_transition() {
    # Explicit failure propagation: do NOT rely on set -e here, because this
    # runs inside a subshell that is the left operand of '||', where bash
    # ignores errexit.
    local l
    for l in "${LIFECYCLE_LABELS[@]}"; do
      [[ "$l" == "openspec:$lifecycle" ]] && continue
      gh_call issue edit "$num" --remove-label "$l" >/dev/null || return $?
    done
    gh_call issue edit "$num" --add-label "openspec:$lifecycle" >/dev/null || return $?
    if [[ "$lifecycle" == "completed" ]]; then
      gh_call issue close "$num" >/dev/null || return $?
    else
      gh_call issue reopen "$num" >/dev/null || return $?
    fi
    cmd_set_metadata "$num" --key lifecycle --value "$lifecycle" >/dev/null || return $?
    _validate_issue "$num" >/dev/null || return $?
  }

  local rc=0
  ( do_transition ) >/dev/null 2>"$WORKDIR/lc.err" || rc=$?
  if [[ $rc -ne 0 ]]; then
    restore_lifecycle_state
    err "$(cat "$WORKDIR/lc.err" 2>/dev/null || true)"
    die "$rc" "set-lifecycle '$cur' -> '$lifecycle' failed for issue #$num; restored prior label/body/state"
  fi
  jq -nc --argjson n "$num" --arg l "$lifecycle" '{ok:true, number:$n, lifecycle:$l}'
}

_validate_issue() {
  local num="${1:?issue}"
  local body labels state meta lifecycle lifecount=0 l present_lifecycle=""
  body="$(issue_body "$num")"
  validate_body_string "$body"
  meta="$(printf '%s' "$body" | extract_metadata)"
  lifecycle="$(jq -r '.lifecycle // ""' <<<"$meta")"
  mapfile -t labels < <(issue_labels "$num")
  printf '%s\n' "${labels[@]}" | grep -qxF "$DISCOVERY_LABEL" \
    || die "$EX_VALIDATE" "issue #$num missing '$DISCOVERY_LABEL' label"
  for l in "${LIFECYCLE_LABELS[@]}"; do
    if printf '%s\n' "${labels[@]}" | grep -qxF "$l"; then
      lifecount=$((lifecount+1)); present_lifecycle="${l#openspec:}"
    fi
  done
  [[ "$lifecount" -eq 1 ]] || die "$EX_VALIDATE" "issue #$num must carry exactly one lifecycle label (found $lifecount)"
  # The sole lifecycle label MUST equal the metadata lifecycle.
  [[ -n "$lifecycle" ]] || die "$EX_VALIDATE" "issue #$num metadata has no lifecycle"
  [[ "$present_lifecycle" == "$lifecycle" ]] || die "$EX_VALIDATE" \
    "issue #$num lifecycle label 'openspec:$present_lifecycle' does not match metadata lifecycle '$lifecycle'"
  state="$(issue_state "$num" | tr '[:upper:]' '[:lower:]')"
  if [[ "$lifecycle" == "completed" && "$state" != "closed" ]]; then
    die "$EX_VALIDATE" "issue #$num lifecycle 'completed' but state is '$state'"
  fi
  if [[ "$lifecycle" != "completed" && "$state" == "closed" ]]; then
    die "$EX_VALIDATE" "issue #$num state 'closed' but lifecycle is '$lifecycle'"
  fi
  jq -nc --argjson n "$num" --arg lc "$lifecycle" --arg st "$state" \
    '{ok:true, number:$n, lifecycle:$lc, state:$st}'
}

# Validate an issue without dying; returns nonzero on failure. Used by callers
# that need to roll back a bad write before reporting failure.
validate_issue_quiet() {
  ( _validate_issue "$1" ) >/dev/null 2>&1
}

# Write a rebuilt body, validate, and roll back to the prior valid body on
# failure so a known-malformed body is never left in place.
edit_body_or_rollback() {
  local num="$1" newbody="$2" priorbody="$3" rc=0
  gh_call issue edit "$num" --body-file "$newbody" >/dev/null || rc=$?
  if [[ $rc -ne 0 ]]; then
    # The write itself failed; the body is unchanged, so there is nothing to
    # roll back. Propagate the failure without claiming success.
    return "$rc"
  fi
  if ! validate_issue_quiet "$num"; then
    gh_call issue edit "$num" --body-file "$priorbody" >/dev/null 2>&1 || true
    die "$EX_VALIDATE" "issue #$num failed post-write validation; restored the previous valid body"
  fi
}

cmd_validate() { _validate_issue "$@"; }

cmd_scan_content() {
  local bodyfile=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --body-file) bodyfile="$2"; shift 2;;
      *) die "$EX_USAGE" "unknown arg: $1";;
    esac
  done
  [[ -n "$bodyfile" && -f "$bodyfile" ]] || die "$EX_USAGE" "scan-content requires --body-file"
  scan_content_file "$bodyfile"
  jq -nc '{ok:true, sensitive:false}'
}

cmd_render_body() {
  # render-body --meta <file> --proposal <f> --requirements <f> --design <f> --tasks <f> --verification <f>
  local meta="" p="" r="" d="" t="" v=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --meta) meta="$2"; shift 2;;
      --proposal) p="$2"; shift 2;;
      --requirements) r="$2"; shift 2;;
      --design) d="$2"; shift 2;;
      --tasks) t="$2"; shift 2;;
      --verification) v="$2"; shift 2;;
      *) die "$EX_USAGE" "unknown arg: $1";;
    esac
  done
  [[ -f "$meta" ]] || die "$EX_USAGE" "render-body requires --meta <file>"
  render_body "$(cat "$meta")" "$p" "$r" "$d" "$t" "$v"
}

usage() {
  cat >&2 <<'EOF'
usage: openspec-issue.sh <command> [args]
  preflight [--write]
  ensure-labels
  find <change-name>
  list [--state open|closed|all]
  create --name <n> --title <t> [--schema <s>] [--lifecycle <l>] [--created <d>] --body-file <f>
  read <issue>
  get-section <issue> <section>
  set-section <issue> <section> --body-file <f>
  set-metadata <issue> --key <k> --value <v>
  set-lifecycle <issue> <lifecycle>
  validate <issue>
  scan-content --body-file <f>
  render-body --meta <f> [--proposal <f>] [--requirements <f>] [--design <f>] [--tasks <f>] [--verification <f>]
See tools/openspec-issue/CONTRACT.md.
EOF
  exit "$EX_USAGE"
}

main() {
  [[ $# -ge 1 ]] || usage
  local cmd="$1"; shift
  case "$cmd" in
    preflight) cmd_preflight "$@";;
    ensure-labels) cmd_ensure_labels "$@";;
    find) cmd_find "$@";;
    list) cmd_list "$@";;
    create) cmd_create "$@";;
    read) cmd_read "$@";;
    get-section) cmd_get_section "$@";;
    set-section) cmd_set_section "$@";;
    set-metadata) cmd_set_metadata "$@";;
    set-lifecycle) cmd_set_lifecycle "$@";;
    validate) cmd_validate "$@";;
    scan-content) cmd_scan_content "$@";;
    render-body) cmd_render_body "$@";;
    -h|--help|help) usage;;
    *) die "$EX_USAGE" "unknown command: $cmd";;
  esac
}

main "$@"
