# Phase 1 deterministic syntax architecture proof

Phase 1 proves this pipeline:

```text
HTML Tree-sitter boundaries
  → Lua attribute segmentation and bounded Datastar tokenizer
  → persistent highlight extmarks linked to standard groups
```

For `htmldjango`, HTML Tree-sitter is a structural service only. Built-in Vim Django/HTML syntax remains the visible host layer.

## Acceptance evidence

| Acceptance criterion | Evidence |
|---|---|
| Isolated real-Neovim harness | `tests/run.sh` creates fresh XDG directories and one clean headless process per case. `./tests/run.sh --self-test-failure` proves non-zero failure propagation. |
| Pinned parser input | `tests/parsers.lock` pins `tree-sitter-html` `5a5ca8551a179998360b4a4ca2c0f366a35acc03`, generated ABI 14. `tests/build_parsers.sh` builds `.deps/parser/html.so`; no binary is tracked. |
| HTML and registered Django structure | `tests/cases/architecture.lua` and `tests/cases/htmldjango.lua` explicitly parse both filetypes and assert a `document` root. Registration is repeated safely. |
| Recognized attribute boundaries | The architecture case compares all 78 representative-fixture extmarks by exact byte range/group/text and verifies all 32 pinned built-in attributes. Ordinary/unknown `data-*`, ARIA, comments, text and unrelated values are negative controls. |
| Attribute segmentation | Exact fixture and synthetic assertions cover `data-`, plugin names, `:`, dotted keys, `__`, modifier names, `.`, and modifier arguments. |
| Bounded expression roles | Exact fixture output plus synthetic controls cover `$`/`$$` signals, `@action`, function/method calls, strings/escapes, decimal numbers, booleans/null, operators, arrays/objects, separators and object keys. Arrow, spread and template interpolation semantics remain deferred. |
| Django ownership | Direct `synID()` assertions preserve `{% load static %}`, `{% url ... %}` and `{{ page }}` groups. No plugin mark overlaps those byte ranges, and the surrounding string resumes after each complete hole. |
| Highlighter ownership | The Django case proves an HTML parser is present while `get_captures_at_pos()` has no visible Tree-sitter captures. The plugin never calls `vim.treesitter.start()` or `stop()`. |
| Malformed/edit safety | `tests/cases/malformed.lua` table-tests incomplete names, keys, modifiers, expressions, strings/actions and Django delimiters; it checks bounds, empty-token prevention, fail-closed holes, stale-mark removal and edit convergence. |
| Portable highlights | `tests/cases/highlights.lua` verifies exact default links, absence of direct colors, ColorScheme restoration and preservation of a user override. Extmark priority is fixed at 110, immediately above normal Tree-sitter priority 100. |
| Parser absence | A process with no parser path receives one actionable warning, keeps an empty plugin namespace and retains direct Django syntax groups. |
| Bounded viability | The deterministic generator produces 102,564 bytes. Only recognized attribute values are tokenized. Half/full semantic work counts scale exactly 1:2; wall-clock time is reported but not asserted. |
| Released Neovim lines | `tests/run-version-matrix.sh` passed on pinned 0.10.4, 0.11.7 and 0.12.5 Linux artifacts. `.github/workflows/test.yml` makes these required lanes and nightly non-blocking. |

## Validation commands

```sh
./tests/build_parsers.sh
./tests/run.sh --self-test-failure
./tests/run.sh
./tests/run.sh tests/cases/architecture.lua
./tests/run.sh tests/cases/htmldjango.lua
./tests/run.sh tests/cases/malformed.lua
./tests/run.sh tests/cases/highlights.lua
./tests/run.sh tests/cases/lifecycle.lua
./tests/run.sh tests/cases/parser_absence.lua
./tests/run.sh tests/cases/viability.lua
./tests/run-version-matrix.sh
git diff --check
git status --short
```

## Local measurements

The approximately 100 KiB full-refresh probe reported:

| Neovim | Full refresh |
|---|---:|
| 0.10.4 | 16.946 ms |
| 0.11.7 | 13.976 ms |
| 0.12.5 | 16.561 ms |
| Local macOS 0.12.5 | 13.530 ms |

Measurements are development evidence, not CI timing assertions. All were below the approximately 20 ms investigation threshold.

## Explicitly deferred to Phase 2 or later

- Production configuration and broader attachment hardening.
- Template filetypes beyond `html` and `htmldjango`.
- Custom Datastar attributes.
- Incremental refresh machinery or an alternate decoration provider.
- Automated upstream language-data synchronization.
- Arrow-function, spread and template-literal interpolation semantics.
- LSP packaging, completion, diagnostics, hover, navigation, rename and signature help.
