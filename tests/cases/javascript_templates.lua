local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

local function texts(buf)
  return vim.tbl_map(function(mark) return mark.group .. "|" .. mark.text end, h.marks_with_text(buf))
end

local function assert_no_overlap(buf, row, first, last)
  for _, mark in ipairs(h.extmarks(buf)) do
    if mark.row == row and mark.end_row == row then
      h.assert_true(mark.end_col <= first or mark.col >= last, "Datastar mark overlaps JavaScript substitution")
    end
  end
end

return function()
  local root = vim.env.DATASTAR_ROOT .. "/.deps/parser/"
  h.assert_equal({ root .. "javascript.so" }, h.runtime_parser_paths("javascript"), "only pinned JavaScript parser is visible")
  h.assert_equal({ root .. "html.so" }, h.runtime_parser_paths("html"), "only pinned HTML parser is visible")

  local datastar = require("datastar")
  local starts, stops = 0, 0
  h.with_patch(vim.treesitter, "start", function()
    starts = starts + 1
  end, function()
    h.with_patch(vim.treesitter, "stop", function()
      stops = stops + 1
    end, function()
      datastar.setup()
    end)
  end)
  local source = h.read_fixture("site-theme-switcher.js")
  local buf = h.new_buffer(source, "javascript")
  local host_parser = vim.treesitter.get_parser(buf, "javascript")
  local started, start_error = pcall(vim.treesitter.start, buf, "javascript")
  h.assert_true(started, "visible JavaScript highlighter starts: " .. tostring(start_error))
  local host_highlighter = vim.treesitter.highlighter.active[buf]
  h.assert_true(host_highlighter ~= nil, "visible JavaScript highlighter is active")
  local result = datastar.refresh(buf)
  h.assert_equal(nil, result.error, "real tagged-template reproducer parses")
  h.assert_equal(host_highlighter, vim.treesitter.highlighter.active[buf], "plugin preserves the visible host highlighter")
  h.assert_equal(host_parser, vim.treesitter.get_parser(buf), "plugin reuses the host parser without replacing it")
  h.assert_equal(0, starts, "plugin never starts the host highlighter")
  h.assert_equal(0, stops, "plugin never stops the host highlighter")
  h.assert_equal(3, result.stats.recognized_attributes, "only the three Datastar attributes are recognized")
  local rendered = texts(buf)
  for _, wanted in ipairs({ "DatastarPlugin|ref", "DatastarPlugin|attr", "DatastarKey|aria-label", "DatastarPlugin|on", "DatastarKey|click", "DatastarSignal|$$actionLabel", "DatastarSignal|$_theme" }) do
    h.assert_true(vim.tbl_contains(rendered, wanted), "missing reproducer mark " .. wanted)
  end
  h.assert_equal("javascript", vim.bo[buf].filetype, "JavaScript identity is preserved")
  h.assert_equal("javascript", vim.treesitter.get_parser(buf):lang(), "host parser remains JavaScript")

  local negative = [[const quoted = '<div data-show="$wrong">';
const untagged = `<div data-show="$untagged">`;
const other = css`<div data-show="$other">`;
const member = tools.html`<div data-show="$member">`;
const alias = htmlAlias`<div data-show="$alias">`;
// <div data-show="$comment">
/* <div data-show="$block"> */
const compare = x < div > data - show;
const actual = html`<div data-show="$right"></div>`;]]
  local negative_buf = h.new_buffer(negative, "javascript")
  local negative_result = datastar.refresh(negative_buf)
  h.assert_equal(nil, negative_result.error, "negative controls parse")
  h.assert_equal(1, negative_result.stats.recognized_attributes, "only the exact html tag is recognized")
  h.assert_true(vim.tbl_contains(texts(negative_buf), "DatastarSignal|$right"), "exact html tag is highlighted")
  for _, wrong in ipairs({ "$wrong", "$untagged", "$other", "$member", "$alias", "$comment", "$block" }) do
    h.assert_true(not vim.tbl_contains(texts(negative_buf), "DatastarSignal|" .. wrong), "non-html source is untouched: " .. wrong)
  end

  local with_holes = [[const view = html`<div data-show="$before && ${getThing({ foo: "$owned" })} && $after"
  aria-label="${title}"
  data-on:click="$later"
></div>`;]]
  local holes_buf = h.new_buffer(with_holes, "javascript")
  local holes_result = datastar.refresh(holes_buf)
  h.assert_equal(nil, holes_result.error, "substitutions parse")
  h.assert_true(vim.tbl_contains(texts(holes_buf), "DatastarPlugin|show"), "literal name survives a value hole")
  h.assert_true(not vim.tbl_contains(texts(holes_buf), "DatastarSignal|$before"), "entire intersecting value fails closed before hole")
  h.assert_true(not vim.tbl_contains(texts(holes_buf), "DatastarSignal|$after"), "entire intersecting value fails closed after hole")
  h.assert_true(not vim.tbl_contains(texts(holes_buf), "DatastarSignal|$owned"), "JavaScript substitution is never tokenized")
  h.assert_true(vim.tbl_contains(texts(holes_buf), "DatastarSignal|$later"), "later independent value resumes")
  local row = 0
  for line in with_holes:gmatch("([^\n]+)") do
    local first, last = line:find("${getThing", 1, true)
    if first then assert_no_overlap(holes_buf, row, first - 1, last) end
    row = row + 1
  end

  local inline = h.new_buffer('const view = html`<div aria-label="${title}" data-show="$inline"></div>`;', "javascript")
  h.assert_equal(nil, datastar.refresh(inline).error, "inline template after substitution parses")
  h.assert_true(vim.tbl_contains(texts(inline), "DatastarSignal|$inline"), "same-line position after substitution is mapped correctly")

  local multiline = h.new_buffer([[const view = html`<div data-show="$before ${
  compute({ value: '$inside' })
} $after" data-text="$resumed"></div>`;]], "javascript")
  local multi_result = datastar.refresh(multiline)
  h.assert_equal(nil, multi_result.error, "multiline JavaScript substitution parses")
  h.assert_true(not vim.tbl_contains(texts(multiline), "DatastarSignal|$before"), "multiline hole fails closed before")
  h.assert_true(not vim.tbl_contains(texts(multiline), "DatastarSignal|$after"), "multiline hole fails closed after")
  h.assert_true(vim.tbl_contains(texts(multiline), "DatastarSignal|$resumed"), "same-tag independent attribute resumes after multiline hole")

  local edit_buf = h.new_buffer('const first = html`<p data-show="$one"></p>`;\nconst second = html`<p data-on:click="$two"></p>`;', "javascript")
  for _, replacement in ipairs({
    'const first = html`<p data-show="$changed"></p>`;\nconst second = html`<p data-on:click="$two"></p>`;',
    'const first = css`<p data-show="$one"></p>`;\nconst second = html`<p data-on:click="$two"></p>`;',
    'const first = html`<p data-show="$changed"></p>`;\nconst second = html`<p data-on:click="$two"></p>`;',
  }) do
    vim.api.nvim_buf_set_lines(edit_buf, 0, -1, true, h.lines(replacement))
    local after = datastar.refresh(edit_buf)
    h.assert_equal(nil, after.error, "edit refresh succeeds")
    h.assert_equal(after.extmark_count, #h.extmarks(edit_buf), "one extmark per rendered part after edit")
    h.assert_equal(after.stats.recognized_attributes, 2 - (replacement:find("css`", 1, true) and 1 or 0), "only current html templates are counted")
  end
  h.assert_true(not vim.tbl_contains(texts(edit_buf), "DatastarSignal|$one"), "old mark does not survive edits")
  vim.bo[edit_buf].filetype = "lua"
  h.assert_equal({}, h.extmarks(edit_buf), "filetype change clears only plugin marks")
end
