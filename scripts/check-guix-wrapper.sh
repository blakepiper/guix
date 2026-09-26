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
    printf 'refresh\n' >> "$TEST_GUIX_LOG"
    printf '%s\n' "$GUIX_CODEX_RELEASE_FILE" > "$TEST_GUIX_SNAPSHOT"
    test "${TEST_GUIX_REFRESH_STATUS:-0}" = 0 || exit "$TEST_GUIX_REFRESH_STATUS"
    printf 'snapshot\n' > "$GUIX_CODEX_RELEASE_FILE"
    ;;
  home:build|home:reconfigure)
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
unset GUIX_CODEX_RELEASE_FILE TEST_GUIX_REFRESH_STATUS TEST_GUIX_COMMAND_STATUS

for action in build reconfigure; do
  : > "$TEST_GUIX_LOG"
  "$work/repo with spaces/scripts/guix" home "$action" -L modules 'host with spaces.scm'
  printf '%s\n' refresh home "$action" -L modules 'host with spaces.scm' > "$work/expected"
  cmp "$work/expected" "$TEST_GUIX_LOG"
  test ! -e "$(dirname "$(cat "$TEST_GUIX_SNAPSHOT")")"
done

# A failed refresh must never continue with the reference/previous version.
: > "$TEST_GUIX_LOG"
status=0
TEST_GUIX_REFRESH_STATUS=42 "$work/repo with spaces/scripts/guix" home build || status=$?
test "$status" = 42
test "$(cat "$TEST_GUIX_LOG")" = refresh
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
printf 'Guix wrapper refresh, arguments, failures and cleanup passed.\n'
