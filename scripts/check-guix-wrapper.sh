#!/bin/sh
# Exercise routing, failure handling and cleanup without a daemon or activation.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/repo with spaces/scripts" "$work/bin"
cp "$root/scripts/guix" "$work/repo with spaces/scripts/guix"
cat > "$work/bin/guix" <<'MOCK'
#!/bin/sh
set -eu
test "$1" = time-machine
test "$2" = -C
test "$4" = --
shift 4
case "$1:$2" in
  repl:-L)
    case "$4" in
      */update-firefox.scm)
        printf 'firefox-refresh\n' >> "$TEST_GUIX_LOG"
        test "${TEST_FIREFOX_REFRESH_STATUS:-0}" = 0 || exit "$TEST_FIREFOX_REFRESH_STATUS"
        printf 'firefox-snapshot\n' > "$GUIX_FIREFOX_RELEASE_FILE"
        printf '/gnu/store/ybk9mpvi5aw47hr1bwpf1bqnqjv2x3ml-firefox-156.0\n' > "$GUIX_FIREFOX_RELEASE_FILE.path"
        exit 0
        ;;
    esac
    printf 'refresh\n' >> "$TEST_GUIX_LOG"
    printf '%s\n' "$GUIX_CODEX_RELEASE_FILE" > "$TEST_GUIX_SNAPSHOT"
    test "${TEST_GUIX_REFRESH_STATUS:-0}" = 0 || exit "$TEST_GUIX_REFRESH_STATUS"
    printf 'snapshot\n' > "$GUIX_CODEX_RELEASE_FILE"
    ;;
  build:--max-jobs=0)
    test "$3" = --no-offload
    test "$4" = '--substitute-urls=https://substitutes.nonguix.org https://ci.guix.gnu.org https://bordeaux.guix.gnu.org'
    test "$6" = /gnu/store/ybk9mpvi5aw47hr1bwpf1bqnqjv2x3ml-firefox-156.0
    printf 'firefox-fetch\n' >> "$TEST_GUIX_LOG"
    exit "${TEST_FIREFOX_FETCH_STATUS:-0}"
    ;;
  home:build|home:reconfigure)
    test "$(cat "$GUIX_FIREFOX_RELEASE_FILE")" = firefox-snapshot
    test "$(cat "$GUIX_CODEX_RELEASE_FILE")" = snapshot
    printf '%s\n' "$@" >> "$TEST_GUIX_LOG"
    exit "${TEST_GUIX_COMMAND_STATUS:-0}"
    ;;
  *)
    test -z "${GUIX_CODEX_RELEASE_FILE:-}"
    printf '%s\n' "$@" >> "$TEST_GUIX_LOG"
    ;;
esac
MOCK
chmod +x "$work/bin/guix"
PATH="$work/bin:$PATH"
TEST_GUIX_LOG="$work/log"
TEST_GUIX_SNAPSHOT="$work/snapshot-path"
export PATH TEST_GUIX_LOG TEST_GUIX_SNAPSHOT
unset GUIX_CODEX_RELEASE_FILE GUIX_FIREFOX_RELEASE_FILE TEST_GUIX_REFRESH_STATUS TEST_GUIX_COMMAND_STATUS
unset TEST_FIREFOX_REFRESH_STATUS TEST_FIREFOX_FETCH_STATUS

for action in build reconfigure; do
  : > "$TEST_GUIX_LOG"
  "$work/repo with spaces/scripts/guix" home "$action" -L modules 'host with spaces.scm'
  printf '%s\n' firefox-refresh firefox-fetch refresh home "$action" -L modules 'host with spaces.scm' > "$work/expected"
  cmp "$work/expected" "$TEST_GUIX_LOG"
  test ! -e "$(dirname "$(cat "$TEST_GUIX_SNAPSHOT")")"
done

# A failed refresh must never continue with the reference/previous version.
: > "$TEST_GUIX_LOG"
status=0
TEST_GUIX_REFRESH_STATUS=42 "$work/repo with spaces/scripts/guix" home build || status=$?
test "$status" = 42
printf '%s\n' firefox-refresh firefox-fetch refresh > "$work/expected"
cmp "$work/expected" "$TEST_GUIX_LOG"
test ! -e "$(dirname "$(cat "$TEST_GUIX_SNAPSHOT")")"

# Home failures propagate and remove the per-invocation snapshot too.
status=0
TEST_GUIX_COMMAND_STATUS=17 "$work/repo with spaces/scripts/guix" home build || status=$?
test "$status" = 17
test ! -e "$(dirname "$(cat "$TEST_GUIX_SNAPSHOT")")"

: > "$TEST_GUIX_LOG"
"$work/repo with spaces/scripts/guix" system build -L modules hosts/t490/system.scm
printf '%s\n' system build -L modules hosts/t490/system.scm > "$work/expected"
cmp "$work/expected" "$TEST_GUIX_LOG"

# Missing metadata or a failed signed download must stop before Home or Codex.
for stage in refresh fetch; do
  : > "$TEST_GUIX_LOG"
  status=0
  if test "$stage" = refresh; then
    TEST_FIREFOX_REFRESH_STATUS=23 "$work/repo with spaces/scripts/guix" home build || status=$?
    test "$status" = 23
    printf '%s\n' firefox-refresh > "$work/expected"
  else
    TEST_FIREFOX_FETCH_STATUS=24 "$work/repo with spaces/scripts/guix" home build || status=$?
    test "$status" = 1
    printf '%s\n' firefox-refresh firefox-fetch > "$work/expected"
  fi
  cmp "$work/expected" "$TEST_GUIX_LOG"
done
printf 'Guix wrapper refresh, arguments, failures and cleanup passed.\n'
