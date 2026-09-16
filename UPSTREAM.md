# Upstream inputs

Phase 1 uses these pinned upstream inputs:

- Datastar attribute metadata: [`starfederation/datastar-vscode-extension`](https://github.com/starfederation/datastar-vscode-extension), commit `38b266ae5af74d04fa3c80887fee165670cbd35e`, `src/language-data.json`.
- Syntax-role reference: the same repository and commit, `src/datastar.injection.tmLanguage.json`.
- HTML parser source: [`tree-sitter/tree-sitter-html`](https://github.com/tree-sitter/tree-sitter-html), commit `5a5ca8551a179998360b4a4ca2c0f366a35acc03` (`v0.23.2`). The generated parser uses Tree-sitter ABI 14.

The generated built-in attribute inventory is committed at `lua/datastar/generated/attributes.lua`. Regenerate it from a checked-out copy of the pinned `language-data.json` with:

```sh
python3 scripts/generate_attributes.py path/to/language-data.json
```

The Datastar VS Code extension is MIT licensed, copyright Star Federation. The HTML grammar is MIT licensed, copyright Max Brunsfeld and contributors. Their license notices are retained in the parser source checkouts created under `.deps/`; generated platform parser binaries are not committed.
