#!/usr/bin/env sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: $0 VERSION DESTINATION" >&2
  exit 2
fi

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$1
DESTINATION=$2

case $(uname -m) in
  x86_64|amd64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "unsupported Linux architecture: $(uname -m)" >&2; exit 1 ;;
esac
ASSET="nvim-linux-$ARCH.tar.gz"
KEY="linux-$ARCH"
CHECKSUM=$(python3 - "$ROOT/tests/neovim.lock" "$VERSION" "$KEY" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as lock:
    print(json.load(lock)[sys.argv[2]][sys.argv[3]])
PY
)

archive=$(mktemp "${TMPDIR:-/tmp}/nvim.XXXXXX.tar.gz")
trap 'rm -f "$archive"' EXIT
curl -fsSL "https://github.com/neovim/neovim/releases/download/$VERSION/$ASSET" -o "$archive"
printf '%s  %s\n' "$CHECKSUM" "$archive" | sha256sum -c -

rm -rf "$DESTINATION"
mkdir -p "$DESTINATION"
tar -xzf "$archive" -C "$DESTINATION" --strip-components=1
"$DESTINATION/bin/nvim" --version | head -n 1
