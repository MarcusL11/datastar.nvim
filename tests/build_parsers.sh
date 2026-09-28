#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DEPS="$ROOT/.deps"
SOURCE="$DEPS/tree-sitter-html"
PARSER_DIR="$DEPS/parser"
COMMIT=5a5ca8551a179998360b4a4ca2c0f366a35acc03
REPOSITORY=https://github.com/tree-sitter/tree-sitter-html.git

mkdir -p "$DEPS" "$PARSER_DIR"
if [ ! -d "$SOURCE/.git" ]; then
  git clone --quiet --filter=blob:none "$REPOSITORY" "$SOURCE"
fi

git -C "$SOURCE" fetch --quiet origin "$COMMIT"
git -C "$SOURCE" checkout --quiet --detach "$COMMIT"
ACTUAL=$(git -C "$SOURCE" rev-parse HEAD)
if [ "$ACTUAL" != "$COMMIT" ]; then
  echo "unexpected HTML parser source commit: $ACTUAL" >&2
  exit 1
fi

CC=${CC:-cc}
CFLAGS=${CFLAGS:--O2 -fPIC}
"$CC" $CFLAGS -I"$SOURCE/src" -c "$SOURCE/src/parser.c" -o "$DEPS/html-parser.o"
"$CC" $CFLAGS -I"$SOURCE/src" -c "$SOURCE/src/scanner.c" -o "$DEPS/html-scanner.o"

case $(uname -s) in
  Darwin)
    "$CC" -dynamiclib "$DEPS/html-parser.o" "$DEPS/html-scanner.o" -o "$PARSER_DIR/html.so"
    ;;
  *)
    "$CC" -shared "$DEPS/html-parser.o" "$DEPS/html-scanner.o" -o "$PARSER_DIR/html.so"
    ;;
esac

printf 'built %s from %s (ABI 14)\n' "$PARSER_DIR/html.so" "$COMMIT"

JS_SOURCE="$DEPS/tree-sitter-javascript"
JS_COMMIT=3a837b6f3658ca3618f2022f8707e29739c91364
JS_REPOSITORY=https://github.com/tree-sitter/tree-sitter-javascript.git
if [ ! -d "$JS_SOURCE/.git" ]; then
  git clone --quiet --filter=blob:none "$JS_REPOSITORY" "$JS_SOURCE"
fi

git -C "$JS_SOURCE" fetch --quiet origin "$JS_COMMIT"
git -C "$JS_SOURCE" checkout --quiet --detach "$JS_COMMIT"
JS_ACTUAL=$(git -C "$JS_SOURCE" rev-parse HEAD)
if [ "$JS_ACTUAL" != "$JS_COMMIT" ]; then
  echo "unexpected JavaScript parser source commit: $JS_ACTUAL" >&2
  exit 1
fi

"$CC" $CFLAGS -I"$JS_SOURCE/src" -c "$JS_SOURCE/src/parser.c" -o "$DEPS/javascript-parser.o"
"$CC" $CFLAGS -I"$JS_SOURCE/src" -c "$JS_SOURCE/src/scanner.c" -o "$DEPS/javascript-scanner.o"
case $(uname -s) in
  Darwin)
    "$CC" -dynamiclib "$DEPS/javascript-parser.o" "$DEPS/javascript-scanner.o" -o "$PARSER_DIR/javascript.so"
    ;;
  *)
    "$CC" -shared "$DEPS/javascript-parser.o" "$DEPS/javascript-scanner.o" -o "$PARSER_DIR/javascript.so"
    ;;
esac
printf 'built %s from %s (ABI 14)\n' "$PARSER_DIR/javascript.so" "$JS_COMMIT"
