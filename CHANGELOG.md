# Changelog

Notable user-facing changes to `datastar.nvim` are recorded here.

## Unreleased

- Add original light/dark wordmarks and social-preview artwork.
- Remove phase completion notes from the shipped documentation.

## v0.2.0

### Added

- Highlight Datastar attributes inside direct `html` tagged templates in `javascript` buffers without replacing the visible JavaScript highlighter.
- Treat JavaScript `${...}` substitutions as host-owned holes: values intersecting a substitution receive no Datastar value marks; independent attributes after the hole still work.
- Require a discoverable JavaScript Tree-sitter parser in addition to HTML for JavaScript buffers, with safe missing-parser warnings and recovery.
- Pin the JavaScript parser for the isolated test harness; cover the real Rocket example, negative controls, edits, parser absence, and Neovim 0.10.4/0.11.7/0.12.5.

This does not add TypeScript/JSX, other template tags, or Datastar LSP features.

## v0.1.1

- Preserve Django template highlighting and language identity while using HTML parsing for Datastar attribute boundaries.

## v0.1.0

- Introduce Datastar syntax highlighting for `html`, `htmldjango`, `jinja`, `twig`, and `liquid` with bounded expression tokens and configurable custom attribute names.
- Add safe automatic activation, help documentation, pinned parser provenance, and tests across Neovim 0.10.4, 0.11.7, and 0.12.5.
