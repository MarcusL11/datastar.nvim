# datastar.nvim

Datastar syntax support for Neovim.

The current Phase 1 implementation is a deterministic architecture proof for `html` and `htmldjango`. It uses the HTML Tree-sitter parser for attribute boundaries, a bounded Lua tokenizer for Datastar expressions, and persistent semantic highlight extmarks.

## Requirements

- Neovim 0.10 or newer
- An externally installed HTML Tree-sitter parser

The plugin does not bundle parser binaries. With `nvim-treesitter`, install the `html` parser through the normal parser installation mechanism for your setup.

## Behavior

- Recognizes the built-in Datastar attributes pinned from the official VS Code extension.
- Highlights attribute prefixes, plugin names, dotted keys, modifiers and modifier arguments.
- Highlights bounded expression roles including signals, actions, calls, strings, decimal numbers, literals, operators, object/array punctuation and object keys.
- Preserves complete `{% ... %}` and `{{ ... }}` Django fragments as host-owned regions.
- Registers `htmldjango` to use the HTML parser for structure without starting a visible HTML Tree-sitter highlighter. Built-in Vim `htmldjango` syntax remains the host presentation layer.
- Uses default links to standard highlight groups and does not define colors.
- Leaves host syntax unchanged and warns once if the HTML parser is unavailable.

The plugin loads automatically when installed on Neovim's runtime path. Phase 1 intentionally has no broad configuration API.

## Deterministic tests

The test parser is built from an exact upstream source commit into the ignored `.deps/` directory:

```sh
./tests/build_parsers.sh
./tests/run.sh --self-test-failure
./tests/run.sh
```

Run the released-line matrix in isolated Docker containers:

```sh
./tests/run-version-matrix.sh
```

The required matrix pins Neovim 0.10.4, 0.11.7 and 0.12.5 artifacts and verifies their SHA-256 checksums. CI also runs a non-blocking nightly lane. See [`docs/phase-1.md`](docs/phase-1.md) for the acceptance evidence and [`UPSTREAM.md`](UPSTREAM.md) for pinned sources and attribution.

## Deferred work

Phase 2 will address production hardening and release-facing lifecycle/configuration. Additional template filetypes, custom attributes, incremental performance machinery, upstream synchronization automation and all LSP features remain deferred.

## Upstream references

- [Datastar](https://data-star.dev/)
- [Datastar VS Code extension](https://github.com/starfederation/datastar-vscode-extension)

## License

[MIT](LICENSE)
