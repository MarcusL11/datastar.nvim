# datastar.nvim

Syntax highlighting for [Datastar](https://data-star.dev/) attributes in Neovim.

This first syntax MVP supports `html` and `htmldjango` only. It recognizes the pinned built-in Datastar attribute inventory, highlights attribute names and selected tokens in eligible quoted values, and leaves ordinary HTML and Django presentation to the host runtime.

## Requirements

- Neovim 0.10 or newer.
- An externally installed HTML Tree-sitter parser that Neovim can discover.

The parser is not bundled. If you use `nvim-treesitter`, install its `html` parser using that plugin's normal installation flow (for example, `:TSInstall html`). A `parser/html.*` file on Neovim's runtime path is the usual installation shape, but any HTML parser that Neovim can discover and use satisfies the requirement. The plugin does not fall back to a Vim syntax implementation.

## Installation

The plugin initializes itself when its `plugin/` file is loaded. For a normal, start-loaded plugin installation, no Lua configuration is needed.

### vim-plug

```vim
Plug 'MarcusL11/datastar.nvim'
```

### packer.nvim

```lua
use "MarcusL11/datastar.nvim"
```

### lazy.nvim

Load it for the two supported filetypes:

```lua
{
  "MarcusL11/datastar.nvim",
  ft = { "html", "htmldjango" },
}
```

Lazy managers may also call setup explicitly. This is safe: `setup()` is idempotent and replaces the plugin's autocmd group rather than accumulating handlers.

```lua
{
  "MarcusL11/datastar.nvim",
  ft = { "html", "htmldjango" },
  config = function()
    require("datastar").setup()
  end,
}
```

There is no configuration required or supported for extra filetypes or custom attributes in this MVP. See `:help datastar.nvim` after generating help tags if your plugin manager does not do so.

## Supported syntax

On `html` and `htmldjango` buffers, the highlighter recognizes these lowercase built-in Datastar attribute names:

```text
animate                 attr                  bind
class                   computed              custom-validity
effect                  ignore                ignore-morph
indicator               init                  json-signals
match-media             nonce                 on
on-intersect            on-interval           on-raf
on-resize               on-signal-patch       on-signal-patch-filter
persist                 preserve-attr         query-string
ref                     replace-url           scroll-into-view
show                    signals               style
text                    view-transition
```

A recognized name starts with `data-<name>` and may continue with `:<key>` segments (including well-formed dotted keys) and `__<modifier>` segments with an optional `.argument`. A complete recognized name can be highlighted even when the attribute has no value. While a name is being edited, completed name pieces may still be highlighted, but a malformed or incomplete suffix does not activate value tokenization.

Value tokenization is a separate step. It runs only for a complete recognized lowercase name whose value HTML parses as quoted. Unknown or ordinary `data-*`, ARIA attributes, comments, text, and unquoted values do not activate Datastar value highlighting.

Within an eligible quoted value, the supported highlighting contract is deliberately bounded:

- `$name` and `$$name` signals; called `@action` forms; function and method calls.
- Single- and double-quoted strings and backslash escapes.
- Decimal numbers and the literals `true`, `false`, and `null`.
- Operators: `=== !== && || ?? == != >= <= ++ -- += -= *= /= %= + - * / % > < ! = ? :`.
- Object/array punctuation `{ } [ ] , ;`, call parentheses, access dots, and object keys in `{ key: value }` positions.

These are highlighting boundaries, not JavaScript parsing or expression validation. Complete Django `{% ... %}` and `{{ ... }}` fragments inside a value are host-owned holes: no Datastar mark overlaps them, and surrounding string state resumes after the hole. An unclosed `{%` or `{{` stops Datastar tokenization through the end of that attribute value (fail closed).

## Highlight customization

The plugin defines default links only; it does not set colors. Override any group after your colorscheme, for example:

```lua
vim.api.nvim_set_hl(0, "DatastarSignal", { fg = "#7aa2f7", bold = true })
vim.api.nvim_set_hl(0, "DatastarAction", { link = "Special" })
```

Available groups are `DatastarAttributePrefix`, `DatastarPlugin`, `DatastarKeySeparator`, `DatastarKey`, `DatastarModifierSeparator`, `DatastarModifier`, `DatastarModifierArgumentSeparator`, `DatastarModifierArgument`, `DatastarSignal`, `DatastarAction`, `DatastarFunctionCall`, `DatastarMethodCall`, `DatastarString`, `DatastarEscape`, `DatastarNumber`, `DatastarBoolean`, `DatastarNull`, `DatastarOperator`, `DatastarPunctuation`, `DatastarObjectKey`, `DatastarAccessor`, and `DatastarCallPunctuation`. Defining the plugin's default links does not replace an override that still exists. Because a colorscheme may clear overrides, apply your overrides after the colorscheme.

## Troubleshooting

- **No Datastar highlighting:** confirm `:echo has('nvim-0.10')` is `1`, then install and make the HTML parser discoverable by Neovim. A missing parser emits this warning at most once per session: `datastar.nvim: the HTML Tree-sitter parser is required for Datastar highlighting; install it with :TSInstall html (or your parser manager) and reload the buffer; host syntax was left unchanged`. Query, parse, and unexpected refresh failures also warn at most once per failure category; check `:messages` and keep host syntax in place.
- **An attribute value is not highlighted:** check that the buffer filetype is exactly `html` or `htmldjango`, the full attribute name and suffixes are complete and lowercase, and the value is quoted. Other `data-*` values are intentionally ignored.
- **Django colors look different than HTML:** in an `htmldjango` buffer, built-in Vim Django/HTML syntax remains the visible host layer. The plugin registers HTML parsing for structure but does not start a visible HTML Tree-sitter highlighter there.
- **`:help datastar.nvim` is not found:** create help tags for the installed plugin's `doc` directory with `:helptags {path-to-datastar.nvim}/doc`.

## Compatibility and validation

Neovim 0.10+ is the public baseline. CI is configured to build the pinned external HTML parser and run the suite on Ubuntu with Neovim `v0.10.4`, `v0.11.7`, and `v0.12.5`; its nightly job is non-blocking. A separate macOS job only smoke-tests the Darwin parser-build path, not the plugin suite. No Windows compatibility claim is made.

Run the repository validation contract locally:

```sh
./tests/build_parsers.sh
./tests/run.sh --self-test-failure
./tests/run.sh
./tests/run.sh tests/cases/help.lua
./tests/run-version-matrix.sh
git diff --check
git status --short
```

The dedicated help case generates help tags in a temporary copy and checks that `:help datastar.nvim` resolves; it does not add `doc/tags` to the repository. The released-line matrix requires Docker. `tests/build_parsers.sh` builds a local parser into ignored `.deps/`; it does not add a parser binary to the repository. See [`docs/phase-2.md`](docs/phase-2.md) for the Phase 2 completion evidence and [`UPSTREAM.md`](UPSTREAM.md) for pinned source provenance and attribution.

## Limitations and non-goals

- Only `html` and `htmldjango` are supported.
- Only the listed pinned built-in attribute names and lowercase spelling are supported. Expression highlighting is limited to quoted HTML values. Custom attributes and other template filetypes are out of scope.
- Django handling is limited to complete `{% ... %}` and `{{ ... }}` holes inside a recognized value; Django comments and broader template lexical support are not provided.
- Arrow-function semantics, spread semantics, and template-literal interpolation are not highlighted.
- There is no JavaScript parser injection, Datastar Vim-syntax backend, incremental/decorative rendering backend, LSP, completion, diagnostics, hover, navigation, rename, or signature help.
- Parser binaries are not bundled, and upstream attribute synchronization is not automatic.

## Upstream references

- [Datastar](https://data-star.dev/)
- [Datastar VS Code extension](https://github.com/starfederation/datastar-vscode-extension)

## License

[MIT](LICENSE)
