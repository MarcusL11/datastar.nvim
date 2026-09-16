#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NVIM_BIN=${NVIM_BIN:-nvim}

if [ ! -f "$ROOT/.deps/parser/html.so" ]; then
  echo "missing test parser; run ./tests/build_parsers.sh first" >&2
  exit 1
fi
python3 "$ROOT/tests/generate_viability.py" >/dev/null

DEFAULT_CASES='tests/cases/architecture.lua tests/cases/htmldjango.lua tests/cases/filetypes.lua tests/cases/custom_attributes.lua tests/cases/malformed.lua tests/cases/syntax_contract.lua tests/cases/highlights.lua tests/cases/public_entry.lua tests/cases/zero_config.lua tests/cases/lifecycle.lua tests/cases/parser_absence.lua tests/cases/failure_ux.lua tests/cases/help.lua tests/cases/viability.lua'

if [ "${1:-}" = "--self-test-failure" ]; then
  CASES='tests/cases/self_failure.lua'
  EXPECT_FAILURE=1
  shift
elif [ "$#" -gt 0 ]; then
  CASES="$*"
  EXPECT_FAILURE=0
else
  CASES=$DEFAULT_CASES
  EXPECT_FAILURE=0
fi

run_case() {
  case_path=$1
  xdg=$(mktemp -d "${TMPDIR:-/tmp}/datastar-nvim-test.XXXXXX")
  no_parser=0
  if [ "$case_path" = "tests/cases/parser_absence.lua" ]; then
    no_parser=1
  fi

  set +e
  XDG_CONFIG_HOME="$xdg/config" \
  XDG_DATA_HOME="$xdg/data" \
  XDG_STATE_HOME="$xdg/state" \
  XDG_CACHE_HOME="$xdg/cache" \
  DATASTAR_ROOT="$ROOT" \
  DATASTAR_TEST_CASE="$case_path" \
  DATASTAR_TEST_NO_PARSER="$no_parser" \
    "$NVIM_BIN" --clean --headless --cmd "set noloadplugins" -u "$ROOT/tests/minimal_init.lua" -i NONE \
      -c "lua dofile([[$ROOT/tests/run.lua]])"
  status=$?
  set -e
  rm -rf "$xdg"
  return "$status"
}

if [ "$EXPECT_FAILURE" -eq 1 ]; then
  if run_case "$CASES"; then
    echo "self-test unexpectedly succeeded" >&2
    exit 1
  fi
  echo "PASS harness rejected intentional failure"
  exit 0
fi

for case_path in $CASES; do
  run_case "$case_path"
done
