#!/usr/bin/env bash
# css_box's suite and analyzer on each Flutter of the tested range.
#
#   tool/test_range.sh                  both ends of the range (RANGE below)
#   tool/test_range.sh <flutter> ...    the Flutters given, each an SDK root,
#                                       its bin/flutter, or a version
#
# A version is found as an fvm install (${FVM_CACHE_PATH:-~/fvm}/versions/<v>)
# or as the `flutter` on PATH when that is the version.
#
# Each Flutter, one after the other, in this package (and in example/):
#   flutter pub get
#   flutter analyze --fatal-infos     the package, its tests, tool/, benchmark/
#                                     and example/
#   flutter test                      every test in test/
#   flutter test (in example/)        the README's snippets, pumped, and the
#                                     check that each is the README's own
#   flutter test --platform chrome    the parity tests (test/*_parity_test.dart),
#                                     which assert the same pixels on the web
#                                     as on the VM
# Each `pub get` replaces the last one's resolution, so the Flutters run
# highest first and the lowest one's resolution is what is left.
#
# Logs go to $CSS_BOX_RANGE_OUT (default: a new temporary directory), one
# directory per Flutter version. CSS_BOX_TEST_JOBS sets `flutter test -j`
# (default 4). The web run needs Chrome (CHROME_EXECUTABLE, or Google Chrome
# where it installs); CSS_BOX_WEB=0 leaves it out, and says so.
#
# Exits 0 only when every Flutter analyzed clean and passed every test with
# none skipped.
set -u

# The tested range: the lowest Flutter css_box supports (pubspec.yaml's
# `environment: flutter:`) and the latest stable it was tested on.
RANGE=(3.47.6 3.38.5)

here="$(cd "$(dirname "$0")/.." && pwd)"
out="${CSS_BOX_RANGE_OUT:-$(mktemp -d -t css_box_range)}"
jobs="${CSS_BOX_TEST_JOBS:-4}"
mkdir -p "$out"

# The `flutter` binary for an argument: a root, a binary, or a version.
flutter_for() {
  local a="$1"
  if [[ -x "$a/bin/flutter" ]]; then echo "$a/bin/flutter"; return; fi
  if [[ -x "$a" && "$(basename "$a")" == flutter ]]; then echo "$a"; return; fi
  local fvm="${FVM_CACHE_PATH:-$HOME/fvm}/versions/$a/bin/flutter"
  if [[ -x "$fvm" ]]; then echo "$fvm"; return; fi
  local path_flutter
  path_flutter="$(command -v flutter || true)"
  if [[ -n "$path_flutter" && "$(version_of "$path_flutter")" == "$a" ]]; then echo "$path_flutter"; return; fi
  return 1
}

version_of() {
  local root
  root="$(cd "$(dirname "$1")/.." && pwd)"
  if [[ -f "$root/version" ]]; then cat "$root/version"; else "$1" --version --machine 2>/dev/null |
    sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p'; fi
}

# Chrome for the web run: CHROME_EXECUTABLE, or where it installs.
chrome() {
  local c
  for c in "${CHROME_EXECUTABLE:-}" "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "$(command -v google-chrome || true)" "$(command -v chromium || true)"; do
    if [[ -n "$c" && -x "$c" ]]; then echo "$c"; return; fi
  done
  return 1
}

# "<passed> passed, <skipped> skipped, <failed> failed" off a `flutter test`
# log's last progress line; skipped is empty where none was.
counts() {
  local last passed skipped failed
  last="$(tr '\r' '\n' <"$1" | grep -E '^[0-9]+:[0-9]+ \+[0-9]+' | tail -1)"
  passed="$(sed -nE 's/^[0-9]+:[0-9]+ \+([0-9]+).*/\1/p' <<<"$last")"
  skipped="$(sed -nE 's/^[0-9]+:[0-9]+ \+[0-9]+ ~([0-9]+).*/\1/p' <<<"$last")"
  failed="$(sed -nE 's/^[0-9]+:[0-9]+ \+[0-9]+( ~[0-9]+)? -([0-9]+).*/\2/p' <<<"$last")"
  echo "${passed:-0} passed, ${skipped:-0} skipped, ${failed:-0} failed"
  [[ -z "$skipped" ]]
}

parity=()
for f in "$here"/test/*_parity_test.dart; do [[ -f "$f" ]] && parity+=("test/$(basename "$f")"); done

args=("$@")
[[ ${#args[@]} -eq 0 ]] && args=("${RANGE[@]}")

status=0
summary=()
for a in "${args[@]}"; do
  if ! flutter="$(flutter_for "$a")"; then
    echo "test_range: no Flutter $a here (install it with fvm, or pass its root)" >&2
    summary+=("$a: NOT FOUND")
    status=1
    continue
  fi
  v="$(version_of "$flutter")"
  log="$out/$v"
  mkdir -p "$log"
  echo "== Flutter $v ($flutter)"

  (cd "$here" && "$flutter" pub get) >"$log/pub_get.txt" 2>&1
  pub=$?
  if [[ -f "$here/example/pubspec.yaml" ]]; then
    (cd "$here/example" && "$flutter" pub get) >>"$log/pub_get.txt" 2>&1 || pub=1
  fi

  (cd "$here" && "$flutter" analyze --fatal-infos) >"$log/analyze.txt" 2>&1
  analyze=$?
  issues="$(grep -Eo '[0-9]+ issues? found' "$log/analyze.txt" | tail -1)"
  [[ -z "$issues" ]] && grep -q 'No issues found' "$log/analyze.txt" && issues='no issues'

  (cd "$here" && "$flutter" test -j "$jobs" -r expanded) >"$log/test.txt" 2>&1
  tests=$?
  test_counts="$(counts "$log/test.txt")" || tests=1

  example="none"
  if [[ -d "$here/example/test" ]]; then
    (cd "$here/example" && "$flutter" test -r expanded) >"$log/example.txt" 2>&1
    ex=$?
    example_counts="$(counts "$log/example.txt")" || ex=1
    example="rc $ex ($example_counts)"
    [[ $ex -ne 0 ]] && status=1
  fi

  web="none"
  if [[ ${#parity[@]} -gt 0 ]]; then
    if [[ "${CSS_BOX_WEB:-1}" == 0 ]]; then
      web="LEFT OUT (CSS_BOX_WEB=0)"
    elif browser="$(chrome)"; then
      (cd "$here" && CHROME_EXECUTABLE="$browser" "$flutter" test --platform chrome -r expanded "${parity[@]}") \
        >"$log/web.txt" 2>&1
      w=$?
      web_counts="$(counts "$log/web.txt")" || w=1
      web="rc $w ($web_counts)"
      [[ $w -ne 0 ]] && status=1
    else
      web="NO CHROME (set CHROME_EXECUTABLE, or CSS_BOX_WEB=0)"
      status=1
    fi
  fi

  line="$v: pub get rc $pub; analyze rc $analyze (${issues:-?}); test rc $tests ($test_counts); example $example; web $web"
  echo "   $line"
  summary+=("$line")
  if [[ $pub -ne 0 || $analyze -ne 0 || $tests -ne 0 ]]; then status=1; fi
done

echo
echo "logs: $out"
printf '%s\n' "${summary[@]}"
exit $status
