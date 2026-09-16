#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSIONS=${*:-"v0.10.4 v0.11.7 v0.12.5"}

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required for the local released-line matrix" >&2
  exit 1
fi

for version in $VERSIONS; do
  echo "=== datastar.nvim on Neovim $version ==="
  docker run --rm \
    -e "NVIM_VERSION=$version" \
    -v "$ROOT:/source:ro" \
    ubuntu:24.04 \
    sh -c '
      set -eu
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get install -y -qq ca-certificates curl git build-essential python3 >/dev/null
      cp -a /source /work
      rm -rf /work/.git /work/.pi /work/.deps
      cd /work
      ./tests/install_neovim.sh "$NVIM_VERSION" /opt/nvim
      ./tests/build_parsers.sh
      NVIM_BIN=/opt/nvim/bin/nvim ./tests/run.sh
    '
done
