#!/usr/bin/env python3
"""Generate the pinned built-in Datastar attribute inventory."""

import argparse
import json
from pathlib import Path

UPSTREAM_COMMIT = "38b266ae5af74d04fa3c80887fee165670cbd35e"
DEFAULT_OUTPUT = Path("lua/datastar/generated/attributes.lua")


def render(names: list[str]) -> str:
    lines = [
        "-- Generated from starfederation/datastar-vscode-extension language-data.json.",
        f"-- Upstream commit: {UPSTREAM_COMMIT}",
        "-- Regenerate with: python3 scripts/generate_attributes.py PATH/TO/language-data.json",
        "return {",
    ]
    lines.extend(f'  "{name}",' for name in names)
    lines.extend(["}", ""])
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    data = json.loads(args.source.read_text(encoding="utf-8"))
    names = [attribute["name"] for attribute in data["attributes"]]
    output = render(names)

    if args.check:
        if args.output.read_text(encoding="utf-8") != output:
            raise SystemExit(f"generated inventory is stale: {args.output}")
        return

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(output, encoding="utf-8")


if __name__ == "__main__":
    main()
