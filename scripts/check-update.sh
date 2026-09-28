#!/bin/sh
# Check publication/failure behavior without fetching channels or activating.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
repo="$work/repo with spaces"
mkdir -p "$repo/scripts" "$work/bin"
cp "$root/scripts/update" "$repo/scripts/update"
printf 'original pins\n' > "$work/original"
cp "$work/original" "$repo/channels.scm"
cat > "$work/bin/guix" <<'MOCK'
#!/bin/sh
set -eu
test "$1" = time-machine
test "$2" = -C
test "$4" = --
test "$5" = repl
test "$6" = -q
test -z "${GUIX_CODEX_RELEASE_FILE:-}"
test -z "${GUIX_FIREFOX_RELEASE_FILE:-}"
candidate_dir=$(dirname "$3")
printf '%s\n' "$candidate_dir" > "$TEST_UPDATE_TEMP"
# Neither stage may temporarily expose unvalidated pins to other commands.
cmp "$TEST_UPDATE_ORIGINAL" channels.scm
case "$7" in
  --)
    test "$8" = "$PWD/scripts/update-channels.scm"
    test "$9" = "$candidate_dir/previous.scm"
    test "${10}" = "$candidate_dir/candidate.scm"
    printf 'resolve\n' >> "$TEST_UPDATE_LOG"
    if [ "${TEST_UPDATE_MODE:-}" = resolve-failure ]; then
      printf 'partial candidate\n' > "${10}"
      exit 23
    fi
    if [ "${TEST_UPDATE_MODE:-}" != unchanged ]; then
      printf 'new pins\n' > "${10}"
    fi
    ;;
  -L)
    test "$8" = "$PWD/modules"
    test "$9" = "$PWD/scripts/check.scm"
    printf 'check\n' >> "$TEST_UPDATE_LOG"
    case "${TEST_UPDATE_MODE:-}" in
      check-failure) exit 24 ;;
      concurrent-edit) printf 'user edit\n' > channels.scm ;;
      interrupt) kill -TERM "$PPID" ;;
    esac
    ;;
  *) exit 99 ;;
esac
MOCK
chmod +x "$work/bin/guix"
PATH="$work/bin:$PATH"
TEST_UPDATE_ORIGINAL="$work/original"
TEST_UPDATE_LOG="$work/log"
TEST_UPDATE_TEMP="$work/temp-path"
export PATH TEST_UPDATE_ORIGINAL TEST_UPDATE_LOG TEST_UPDATE_TEMP
# Inherited per-command release records must not affect offline host checks.
GUIX_CODEX_RELEASE_FILE=/does/not/exist
GUIX_FIREFOX_RELEASE_FILE=/does/not/exist
export GUIX_CODEX_RELEASE_FILE GUIX_FIREFOX_RELEASE_FILE

for mode in success unchanged resolve-failure check-failure concurrent-edit interrupt; do
  cp "$work/original" "$repo/channels.scm"
  : > "$TEST_UPDATE_LOG"
  status=0
  TEST_UPDATE_MODE=$mode "$repo/scripts/update" > "$work/output" 2>&1 || status=$?
  case "$mode" in
    success)
      test "$status" = 0
      printf 'new pins\n' > "$work/expected"
      ;;
    concurrent-edit)
      test "$status" = 1
      printf 'user edit\n' > "$work/expected"
      ;;
    *)
      case "$mode" in
        unchanged) test "$status" = 0 ;;
        resolve-failure) test "$status" = 23 ;;
        check-failure) test "$status" = 24 ;;
        interrupt) test "$status" = 143 ;;
      esac
      cp "$work/original" "$work/expected"
      ;;
  esac
  cmp "$work/expected" "$repo/channels.scm"
  printf 'resolve\n' > "$work/expected-log"
  if [ "$mode" != resolve-failure ]; then
    printf 'check\n' >> "$work/expected-log"
  fi
  cmp "$work/expected-log" "$TEST_UPDATE_LOG"
  test ! -e "$(cat "$TEST_UPDATE_TEMP")"
done

: > "$TEST_UPDATE_LOG"
"$repo/scripts/update" --help > /dev/null
status=0
"$repo/scripts/update" unexpected > /dev/null 2>&1 || status=$?
test "$status" = 2
test ! -s "$TEST_UPDATE_LOG"
printf 'Channel update publication, failures, interruption and concurrent edits passed.\n'
