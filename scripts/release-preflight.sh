#!/usr/bin/env bash
#
# Shared green gate for the Userpilot iOS SDK.
#
# Local (release-sdk / pre-release-check) and GitHub Actions (ci.yml) run the
# same steps via this script so a PR cannot skip a check that a release needs.
#
#   scripts/release-preflight.sh
#   scripts/release-preflight.sh --only environment|test|lint|xcframework
#
# Shared steps (CI jobs and a full local run):
#   environment  Environment.swift is .PRODUCTION with placeholders; SocketManager
#                routes through Environment and contains no NX- string (no hardcoded
#                token/socket). Version.swift == Userpilot.podspec spec.version.
#   test         xcodebuild test — compiles the SDK and runs UserpilotTests.
#   lint         swiftlint --strict
#   xcframework  scripts/build-xcframework.sh (device + simulator Release)
#
# Local-only extras (full run, not CI): CocoaPods trunk vs Version.swift. Needs the
# network; about whether a release would collide, not whether the code is safe to merge.
#
# Exit code: 0 = PASS, 1 = FAIL. Every requested step runs; failures aggregate
# so the summary lists every step that failed, not only the first.

set -uo pipefail   # deliberately NOT -e: every check runs, failures aggregate

cd "$(git rev-parse --show-toplevel)"

ENVIRONMENT_FILE="Sources/Userpilot/Utilities/Config/Environment.swift"
SOCKET_MANAGER_FILE="Sources/Userpilot/Socket/SocketManager.swift"
VERSION_FILE="Sources/Userpilot/Version.swift"
PODSPEC="Userpilot.podspec"
TRUNK_API="https://trunk.cocoapods.org/api/v1/pods/Userpilot"
XCFRAMEWORK_SCRIPT="scripts/build-xcframework.sh"

FAILURES=()
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

ONLY=""

usage() {
  cat <<EOF
Shared green gate (environment, unit tests, SwiftLint, xcframework).

Usage: scripts/release-preflight.sh [--only STEP]

  --only environment   Environment.swift is .PRODUCTION with placeholders
  --only test          xcodebuild test (compiles + UserpilotTests)
  --only lint          swiftlint --strict
  --only xcframework   build-xcframework.sh
  (no --only)          all shared steps, then local version extras

Exit 0 on PASS, 1 on FAIL. Failed steps are listed at the end.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --only)
      ONLY="${2:?--only needs a step name}"
      case "$ONLY" in
        environment|test|lint|xcframework) ;;
        *) echo "Unknown step: $ONLY" >&2; usage >&2; exit 1 ;;
      esac
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

should_run() {
  [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]
}

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
pass() { printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail() {
  printf "  \033[31m✗\033[0m %s\n" "$1"
  FAILURES+=("$1")
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::error::$1"
  fi
}
info() { printf "    %s\n" "$1"; }

# NX- is the Userpilot app-token prefix. A literal in SocketManager / Environment
# means someone pasted a real token or socket into source instead of going through
# Environment.getSocketURL / getClientToken. Runtime tokens are NX- too — this
# only scans source, never the value of config.token.
assert_no_nx() {
  local file="$1" label="$2"
  local hits
  hits="$(grep -n 'NX-' "$file" || true)"
  if [ -n "$hits" ]; then
    fail "$label must not contain NX- (hardcoded token/socket would ship to customers)"
    echo "$hits" | sed 's/^/    /'
  else
    pass "$label has no NX- string"
  fi
}

read_swift_version() {
  local major minor patch
  major=$(grep 'private let versionMajor' "$VERSION_FILE" | grep -oE '[0-9]+')
  minor=$(grep 'private let versionMinor' "$VERSION_FILE" | grep -oE '[0-9]+')
  patch=$(grep 'private let versionPatch' "$VERSION_FILE" \
          | grep -oE '[0-9]+(-(beta|rc)\.[0-9]+)?')
  printf '%s.%s.%s' "$major" "$minor" "$patch"
}

read_podspec_version() {
  grep -E '^\s*spec\.version' "$PODSPEC" \
    | sed -E 's/.*=[[:space:]]*["'"'"']([^"'"'"']+)["'"'"'].*/\1/'
}

run_step() {
  local label="$1"; shift
  local log="$LOG_DIR/$(echo "$label" | tr -c '[:alnum:]' '_').log"
  if "$@" > "$log" 2>&1; then
    pass "$label"
  else
    fail "$label"
    echo "    ── last 15 lines ──"
    tail -15 "$log" | sed 's/^/    /'
  fi
}

pick_simulator() {
  xcrun simctl list devices available 2>/dev/null \
    | grep -oE 'iPhone [0-9]+[^(]*' | sed 's/ *$//' | sort -V | tail -1
}

# ── Steps ────────────────────────────────────────────────────────────────────

check_environment() {
  bold "Environment config"

  local env_type_line
  env_type_line="$(grep 'environmentType' "$ENVIRONMENT_FILE" | head -1)"
  if [[ "$env_type_line" == *".PRODUCTION"* ]]; then
    pass "environmentType is .PRODUCTION"
  else
    fail "environmentType must be .PRODUCTION"
    info "found: ${env_type_line:-<no environmentType line>}"
  fi

  if grep 'socketUrl' "$ENVIRONMENT_FILE" | grep -q '<#'; then
    pass "socketUrl is still a placeholder"
  else
    fail "socketUrl must be a placeholder <#SOCKET_URL#> (a real dev URL would ship to customers)"
    info "found: $(grep 'socketUrl' "$ENVIRONMENT_FILE" | head -1)"
  fi

  if grep 'clientToken' "$ENVIRONMENT_FILE" | grep -q '<#'; then
    pass "clientToken is still a placeholder"
  else
    fail "clientToken must be a placeholder <#TOKEN#> (a real token would ship to customers)"
  fi

  if grep -q "Environment.getSocketURL" "$SOCKET_MANAGER_FILE" \
    && grep -q "Environment.getClientToken" "$SOCKET_MANAGER_FILE"; then
    pass "SocketManager routes through Environment"
  else
    fail "SocketManager must use Environment.getSocketURL(...) and Environment.getClientToken(...)"
  fi

  assert_no_nx "$SOCKET_MANAGER_FILE" "SocketManager.swift"
  assert_no_nx "$ENVIRONMENT_FILE" "Environment.swift"

  local swift_version podspec_version
  swift_version="$(read_swift_version)"
  podspec_version="$(read_podspec_version)"
  printf "    SPM       %-44s \033[1m%s\033[0m\n" "($VERSION_FILE)" "$swift_version"
  printf "    CocoaPods %-44s \033[1m%s\033[0m\n" "($PODSPEC)" "$podspec_version"
  if [ "$swift_version" = "$podspec_version" ]; then
    pass "podspec version matches Version.swift"
  else
    fail "podspec version ($podspec_version) != Version.swift ($swift_version)"
    info "SPM resolves by git tag and CocoaPods by spec.version — drift ships different code"
  fi
  echo
}

check_test() {
  bold "Build & unit tests"

  local simulator
  simulator="$(pick_simulator)"
  if [ -z "$simulator" ]; then
    fail "no iPhone simulator available to run tests"
    xcrun simctl list devices available 2>/dev/null | sed 's/^/    /' || true
    echo
    return
  fi
  info "simulator: $simulator"

  local -a cmd=(
    xcodebuild test -quiet
    -scheme Userpilot
    -destination "platform=iOS Simulator,name=$simulator"
  )
  if [ -n "${RESULT_BUNDLE_PATH:-}" ]; then
    cmd+=(-resultBundlePath "$RESULT_BUNDLE_PATH")
  fi
  run_step "xcodebuild test (compile + UserpilotTests)" "${cmd[@]}"
  echo
}

check_lint() {
  bold "SwiftLint"

  if ! command -v swiftlint >/dev/null 2>&1; then
    fail "swiftlint not installed (brew install swiftlint)"
    echo
    return
  fi

  local -a cmd=(swiftlint lint --strict)
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    cmd+=(--reporter github-actions-logging)
  fi
  run_step "swiftlint --strict" "${cmd[@]}"
  echo
}

check_xcframework() {
  bold "XCFramework"

  if [ ! -f "$XCFRAMEWORK_SCRIPT" ]; then
    fail "$XCFRAMEWORK_SCRIPT is missing"
    echo
    return
  fi

  # Stream the builder's own output — a hidden log is useless on a 5-minute archive.
  if bash "$XCFRAMEWORK_SCRIPT"; then
    pass "build-xcframework.sh (device + simulator Release)"
  else
    fail "build-xcframework.sh (device + simulator Release)"
  fi
  echo
}

check_versions() {
  bold "Version status (local only — not part of the CI green gate)"

  local local_version deployed
  local_version="$(read_swift_version)"

  deployed="$(curl -sS -m 25 "$TRUNK_API" 2>/dev/null \
    | python3 -c 'import json,sys
try:
    vs=[v["name"] for v in json.load(sys.stdin).get("versions",[])]
    print(vs[-1] if vs else "")
except Exception:
    print("")' 2>/dev/null)"

  if [ -z "$deployed" ]; then
    info "⚠ could not query CocoaPods trunk — skipping the comparison"
    printf "    Latest deployed version is  \033[1m%s\033[0m\n" "unknown"
    printf "    The new one is              \033[1m%s\033[0m\n" "$local_version"
  else
    printf "    Latest deployed version is  \033[1m%s\033[0m   (CocoaPods trunk)\n" "$deployed"
    printf "    The new one is              \033[1m%s\033[0m   (%s)\n" "$local_version" "$VERSION_FILE"
    echo
    if [ "$local_version" = "$deployed" ]; then
      pass "not yet bumped — the release workflow will bump this for you"
    else
      local oldest
      oldest="$(printf '%s\n%s\n' "$local_version" "$deployed" | sort -V | head -1)"
      if [ "$oldest" = "$local_version" ]; then
        fail "local version ($local_version) is OLDER than what is published ($deployed)"
        info "CocoaPods rejects re-publishing an existing version."
      else
        pass "already bumped ahead of the published version"
      fi
    fi
  fi
  echo

  local latest_tag
  latest_tag="$(git tag --list --sort=-v:refname | head -1)"
  if [ -n "$latest_tag" ]; then
    if [ "$latest_tag" = "$local_version" ]; then
      pass "latest git tag ($latest_tag) matches Version.swift — SPM consumers get this code"
    else
      info "latest git tag is $latest_tag (Version.swift is $local_version)"
      info "expected before a release: the workflow creates the new tag."
    fi
  fi
  echo
}

# ── Run ──────────────────────────────────────────────────────────────────────

echo
bold "Userpilot iOS SDK — Green gate"
echo

should_run environment && check_environment
should_run test        && check_test
should_run lint        && check_lint
should_run xcframework && check_xcframework

# Version extras are for a human about to dispatch a release, not for every PR.
if [ -z "$ONLY" ] && [ -z "${GITHUB_ACTIONS:-}" ]; then
  check_versions
fi

if [ ${#FAILURES[@]} -eq 0 ]; then
  printf "\033[1;32m═══ PASS ═══\033[0m  all requested steps succeeded\n\n"
  exit 0
fi

printf "\033[1;31m═══ FAIL ═══\033[0m  %d step(s) failed:\n" "${#FAILURES[@]}"
for f in "${FAILURES[@]}"; do printf "  • %s\n" "$f"; done
echo
exit 1
