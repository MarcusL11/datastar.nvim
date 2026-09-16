# Phase 3 filetypes and custom attributes — completion evidence

> **Status:** implementation, local automated validation, manual user verification, and GitHub Actions validation completed on 2026-09-16. Phase 3 is committed and pushed; tagging and publication remain unauthorized.

The Phase 3 implementation is commit `9bd1e37c47e68b0533507bddcf7d8bd6a4c0b4d2`.

Phase 3 extends the syntax MVP to the evidence-backed `html`, `htmldjango`, `jinja`, `twig`, and `liquid` matrix and adds atomic configuration for custom Datastar plugin names. It does not broaden the parser/tokenizer architecture or start LSP and release work.

## Acceptance evidence

| Criterion | Evidence | Result |
|---|---|---|
| Fixed filetype matrix | `filetypes.lua` proves exact built-in name/value output for all five filetypes. | PASS locally and on Neovim 0.10.4, 0.11.7, and 0.12.5. |
| Parser ownership | `filetypes.lua` proves only `htmldjango` is globally registered to HTML, Jinja/Twig/Liquid identities remain unchanged, and setup starts/stops no host highlighter. | PASS on every required lane. |
| Template holes | `filetypes.lua` covers complete output/block holes, whitespace control, string-state resumption, no overlap, and fail-closed unclosed openers in every supported filetype. | PASS on every required lane. |
| Filetype lifecycle | `filetypes.lua` proves supported-to-supported refreshes retain one callback; `lifecycle.lua` preserves unsupported detach and foreign-namespace behavior. | PASS on every required lane. |
| Parser absence and recovery | `parser_absence.lua` proves safe degradation, one warning, and same-buffer recovery in all five filetypes. | PASS on every required lane. |
| Custom attribute semantics | `custom_attributes.lua` proves built-in-equivalent segmentation and bounded quoted-value tokenization while unknown `data-*` remains negative. | PASS on every required lane. |
| Configuration validation | `custom_attributes.lua` covers the grammar, dense arrays, string values, unknown options, duplicate/collision normalization, deterministic longest matching, defensive copies, and atomic invalid failures. | PASS on every required lane. |
| Setup replacement and loading | `custom_attributes.lua` and `public_entry.lua` prove loader-first/options-later and options-first/loader-later ordering, preserving configuration and one callback. They also prove replacement cleanup, `setup(nil)` preservation, and `setup({})` reset. | PASS on every required lane. |
| Phase 2 regression contract | The complete 14-case suite retains architecture, malformed input, syntax roles, lifecycle, failure UX, highlights, help, and viability coverage. | PASS locally and on every required lane. |
| Help delivery | `help.lua` generates tags in an isolated copy and resolves `:help datastar.nvim` without creating repository `doc/tags`. | PASS locally and on every required lane. |
| Provenance and tree hygiene | The built-in inventory and HTML parser pins remain unchanged; no parser binary or help tags are tracked. | PASS locally. |

## Commands and recorded results

Local environment: Darwin 25.6.0 arm64, Neovim 0.12.5.

```text
./tests/build_parsers.sh
  PASS — built .deps/parser/html.so from
  5a5ca8551a179998360b4a4ca2c0f366a35acc03 (ABI 14)

./tests/run.sh tests/cases/filetypes.lua tests/cases/custom_attributes.lua
  PASS — 2/2 focused Phase 3 cases

./tests/run.sh \
  tests/cases/public_entry.lua \
  tests/cases/zero_config.lua \
  tests/cases/lifecycle.lua \
  tests/cases/parser_absence.lua
  PASS — 4/4 public lifecycle and failure cases

./tests/run.sh --self-test-failure
  PASS — harness rejected tests/cases/self_failure.lua

./tests/run.sh
  PASS — 14/14 cases
  VIABILITY bytes=102564 attributes=814 examined_value_bytes=26048
            tokens=5698 extmarks=8954 half_ms=6.654 full_ms=13.854

./tests/run.sh tests/cases/help.lua
  PASS

./tests/run-version-matrix.sh
  PASS — Neovim 0.10.4, full_ms=15.597
  PASS — Neovim 0.11.7, full_ms=14.776
  PASS — Neovim 0.12.5, full_ms=13.647
```

Wall-clock viability values are evidence only; deterministic semantic scaling remains the gate. The matrix builds the pinned parser inside isolated Linux repository copies, so no Linux binary enters the host `.deps/`.

## GitHub Actions evidence

The pushed Phase 3 implementation passed the complete workflow:

- Run: <https://github.com/MarcusL11/datastar.nvim/actions/runs/35087160907>
- Required Neovim 0.10.4, 0.11.7, and 0.12.5 jobs: PASS.
- Build-only `macos-14` parser smoke: PASS.
- Non-blocking Neovim nightly job: PASS.

The `actions/checkout@v4` Node.js 20 deprecation warning remains unrelated release-engineering work and did not affect any required result.

## Manual verification

From this repository (`/Users/mal/Documents/dev/datastar.nvim`), first build the local parser and then open the tracked Phase 3 fixture:

```sh
cd /Users/mal/Documents/dev/datastar.nvim
./tests/build_parsers.sh
nvim --clean \
  --cmd "set runtimepath^=$PWD/.deps" \
  --cmd "set runtimepath^=$PWD" \
  tests/fixtures/phase3.jinja \
  -c "set filetype=jinja" \
  -c "lua require('datastar').setup({ custom_attributes = { 'my-plugin' } })"
```

The file that opens is `tests/fixtures/phase3.jinja`. Inspect these concrete results:

1. `data-on:click` has distinct Datastar name pieces, and `@get` plus `$ready` are highlighted inside its quoted value.
2. `data-my-plugin:status__debounce.500` is recognized after the command configures `my-plugin`; its prefix, plugin, key, modifier, argument, object key, and `$ready` are highlighted.
3. The complete `{{- product.title -}}`, `{% if product %}`, `{{ product.title }}`, and `{% endif %}` spans remain host-owned with no Datastar mark painted across them.

Exit with `:qa!`. This command uses the parser built in this repository and the plugin code in this same checkout; it does not depend on another installed copy of datastar.nvim.

## Public contract decisions

- Supported filetypes are fixed to `html`, `htmldjango`, `jinja`, `twig`, and `liquid`.
- Only `htmldjango -> html` is globally registered. The other template filetypes use an explicit secondary HTML parser without changing language identity.
- The only setup option is `custom_attributes`, containing plugin names without `data-`.
- Names use lowercase kebab-case, duplicates and built-in collisions are deduplicated, matching is deterministic and longest-name-safe, and caller input is copied.
- `setup()` and `setup(nil)` preserve/reapply current configuration. `setup(opts)` replaces the explicit configuration from defaults, so `setup({})` clears custom names.
- Invalid configuration raises before changing active configuration, autocmds, attachments, or marks.
- Configuration updates refresh already-loaded supported buffers and retain one current callback.

## Explicitly deferred to Phase 4+

- Vue, Svelte, Astro, and Templ native component/parser boundaries.
- ERB, JSP, PHP, Razor, Blade, Handlebars, Mustache, Go templates, and other alternate hole/filetype contracts.
- Generic configurable filetypes and plugin-owned filename detection.
- Custom metadata, completion, modifier validation, and diagnostics.
- JavaScript injection, a Datastar Vim grammar, incremental parsing, or a decoration provider.
- Arrow semantics, spread semantics, and template interpolation.
- LSP transport, packaging, completion, diagnostics, hover, navigation, rename, and signature help.
- Automated upstream synchronization, checkout-action maintenance, tagging, publication, and broader platform claims.

Those items require separate approval and a fresh handoff. Commit, push, tagging, and publication authorization remain external to this evidence document.
