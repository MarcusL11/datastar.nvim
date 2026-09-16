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
