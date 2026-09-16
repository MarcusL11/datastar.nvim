#!/usr/bin/env python3
"""Generate a deterministic approximately 100 KiB Phase 1 viability fixture."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / ".deps" / "fixtures" / "viability.html"
TARGET = 100 * 1024
LINE = (
    '<div class="host" data-on:click="!$busy && @get(\'/items?page=12\')" '
    'aria-label="$ignored" data-ordinary="@get(\'x\')">Text</div>\n'
)


def main() -> None:
    count = 2
    while len(LINE.encode("utf-8")) * count < TARGET:
        count += 2
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(LINE * count, encoding="utf-8")
    print(f"generated {OUTPUT} ({OUTPUT.stat().st_size} bytes, {count} lines)")


if __name__ == "__main__":
    main()
