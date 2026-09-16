# Phase 2 production syntax MVP — completion evidence

> **Status:** implementation, automated validation and user visual review completed on 2026-09-16. Phase 2 was committed and pushed; tag and publication remain unauthorized.

Phase 2 turns the Phase 1 architecture proof into a bounded user-facing syntax MVP without expanding its language or filetype scope. The public boundary remains Neovim 0.10+, an externally installed HTML Tree-sitter parser, and the `html`/`htmldjango` filetypes.

The Phase 2 implementation is commit `430676cd32a2005fe88fa39221976b7290066dc6`.

## Acceptance evidence

| Criterion | Evidence | Result |
|---|---|---|
| Public activation | `zero_config.lua` proves loader-first activation for pre-existing HTML and Django buffers. `public_entry.lua` proves explicit-setup-first loading and later loader idempotence. | PASS locally and on Neovim 0.10.4, 0.11.7 and 0.12.5. |
| Manual visual check | Open the representative fixture with the local plugin/parser runtime paths and inspect Datastar highlighting in Neovim. | PASS — user confirmed the fixture worked locally. |
| Lifecycle boundary | `lifecycle.lua` covers exact autocmd topology, repeated setup, parser-before-plugin callback ordering, edits, reload, filetype transitions, repeated detach/reattach, unload, wipeout, buffer `0`, invalid arguments and foreign namespace preservation. | PASS on every required lane. |
| Failure UX | `parser_absence.lua` proves one actionable warning, host preservation and same-buffer recovery after parser discovery. `failure_ux.lua` proves stale-mark cleanup, one-time query/parse/internal warnings and recoverable query/parse paths. | PASS on every required lane. |
| Attribute contract | `architecture.lua` covers all 32 pinned built-ins and negative controls. `malformed.lua` proves completed name pieces may render while an incomplete suffix cannot activate value tokenization. | PASS on every required lane. |
| Expression contract | `architecture.lua` covers representative roles. `syntax_contract.lua` covers the complete documented operator set, punctuation and identifier boundaries. | PASS on every required lane. |
| Django ownership | `htmldjango.lua` proves structural HTML parsing without a visible HTML Tree-sitter highlighter, direct Django syntax preservation, HTML/Django semantic equivalence and no plugin mark over a complete Django hole. | PASS on every required lane. |
| Malformed behavior | `malformed.lua` covers bounded incomplete input, fail-closed unclosed holes, no empty tokens, stale-mark removal and edit convergence. | PASS on every required lane. |
| Highlight links | `highlights.lua` proves default standard-group links, no direct colors, preservation of an existing override and restoration of cleared defaults on `ColorScheme`. | PASS on every required lane. |
| Help delivery | `help.lua` copies `doc/datastar.txt`, generates tags in an isolated temporary directory and resolves `:help datastar.nvim` without creating repository `doc/tags`. | PASS locally and on every required lane. |
| Harness integrity | `./tests/run.sh --self-test-failure` must observe the intentional failure and return success only because the harness rejected it. | PASS. |
| Bounded viability | The 102,564-byte deterministic fixture examined 814 recognized attributes, 26,048 value bytes, 5,698 tokens and 8,954 extmarks. Half/full semantic counts remained exactly proportional. | PASS; timings recorded below, not asserted. |
| Released lines | `./tests/run-version-matrix.sh` builds the pinned ABI-14 HTML parser and runs the complete suite in isolated Docker copies. | PASS on 0.10.4, 0.11.7 and 0.12.5. |
| Darwin parser build | `./tests/build_parsers.sh` exercised the Darwin arm64 compile/link path locally. CI runs the same build-only path on `macos-14`. | PASS locally and in GitHub Actions; this is not a macOS plugin-suite claim. |
| Provenance and tree hygiene | `UPSTREAM.md` retains exact attribution and pins. No parser binary or generated `doc/tags` is tracked. | PASS. |

## Commands and recorded results

Local environment: Darwin 25.6.0 arm64, Neovim 0.12.5.

```text
./tests/build_parsers.sh
  PASS — built .deps/parser/html.so from
  5a5ca8551a179998360b4a4ca2c0f366a35acc03 (ABI 14)

./tests/run.sh --self-test-failure
  PASS — harness rejected tests/cases/self_failure.lua

./tests/run.sh
  PASS — 12/12 cases
  VIABILITY bytes=102564 attributes=814 examined_value_bytes=26048
            tokens=5698 extmarks=8954 half_ms=5.971 full_ms=12.486

./tests/run-version-matrix.sh
  PASS — Neovim 0.10.4, full_ms=14.256
  PASS — Neovim 0.11.7, full_ms=12.996
  PASS — Neovim 0.12.5, full_ms=13.000

git diff --check
  PASS

candidate changed/new-file whitespace scan
  PASS — 20 paths checked

parser binaries tracked
  PASS — 0

repository doc/tags tracked or present
  PASS — 0
```

The released-line matrix used the checksum-pinned Neovim artifacts in `tests/neovim.lock`. Wall-clock viability measurements are evidence only; the semantic scaling assertions are the deterministic gate.

## Release-facing decisions

- Automatic loading through `plugin/datastar.lua` is the normal path.
- Explicit `require("datastar").setup()` remains safe for lazy plugin managers and accepts no configuration in this MVP.
- Setup attaches all already-loaded eligible buffers.
- Public `attach`, `detach` and `refresh` normalize buffer `0`, reject invalid handles safely and remain bounded to `html`/`htmldjango`.
- Buffer callbacks use plugin-owned attachment identities. Filetype detach does not use the RPC-only channel detach API and stale callbacks remove themselves without affecting newer attachments.
- Complete recognized attribute names may be valueless. Value tokenization requires a complete lowercase recognized name and a quoted HTML value.
- Parser, query, parse and unexpected refresh failures clear plugin marks, preserve host syntax and warn at most once per category.
- A conventional help file is shipped without generated tags; plugin managers or `:helptags` generate them.
- CI retains required pinned Linux released-line jobs and non-blocking nightly, and adds a build-only macOS parser smoke. Windows is not claimed.

## GitHub Actions evidence

The pushed Phase 2 implementation passed the complete workflow:

- Run: <https://github.com/MarcusL11/datastar.nvim/actions/runs/35076418560>
- Required Neovim 0.10.4, 0.11.7 and 0.12.5 jobs: PASS.
- Build-only `macos-14` parser smoke: PASS.
- Non-blocking Neovim nightly job: PASS.

The macOS result remains parser-build evidence only; it does not claim a macOS plugin-suite lane.

## Explicitly deferred to Phase 3+

- Additional filetypes or template frameworks.
- User-defined/custom Datastar attributes.
- JavaScript parser injection or a Datastar Vim-syntax backend.
- Incremental refresh or a decoration-provider rendering backend.
- Arrow-function semantics, spread semantics or template-literal interpolation.
- Django comments or broader template lexical parity.
- LSP packaging, completion, diagnostics, hover, navigation, rename or signature help.
- Automated upstream attribute synchronization.
- Release tagging or publication.

Those items require a separately approved phase and fresh handoff.
