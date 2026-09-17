local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

local function overlaps(mark, row, start_col, end_col)
  if mark.row ~= row or mark.end_row ~= row then
    return false
  end
  return mark.col < end_col and mark.end_col > start_col
end

return function()
  local datastar = require("datastar")
  datastar.setup()
  local fixture = h.read_fixture("representative.html")

  local django = h.new_buffer(fixture, "htmldjango", { syntax = "htmldjango" })
  vim.cmd("syntax sync fromstart")

  local parser = vim.treesitter.get_parser(django, "html")
  h.assert_equal("html", parser:lang(), "explicit Django structural parser language")
  h.assert_equal("document", parser:parse(true)[1]:root():type(), "Django buffer explicit HTML parse")

  local captures_ok, captures = pcall(vim.treesitter.get_captures_at_pos, django, 11, 23)
  h.assert_true(captures_ok, "capture inspection must be available")
  h.assert_equal({}, captures, "plugin must not start a visible HTML Tree-sitter highlighter for htmldjango")

  local result = datastar.refresh(django)
  h.assert_equal(nil, result.error, "Django refresh")

  vim.api.nvim_set_current_buf(django)
  vim.cmd("syntax sync fromstart")
  h.assert_equal("djangoTagBlock", h.direct_syntax_group(0, 0), "load tag delimiter remains Django-owned")
  h.assert_equal("djangoStatement", h.direct_syntax_group(0, 3), "load statement remains Django-owned")
  h.assert_equal("djangoTagBlock", h.direct_syntax_group(11, 61), "url tag delimiter remains Django-owned")
  h.assert_equal("djangoStatement", h.direct_syntax_group(11, 64), "url statement remains Django-owned")
  h.assert_equal("djangoVarBlock", h.direct_syntax_group(11, 84), "Django output delimiter remains Django-owned")
  h.assert_equal("djangoVarBlock", h.direct_syntax_group(11, 87), "Django output identifier remains Django-owned")

  for _, mark in ipairs(h.extmarks(django)) do
    h.assert_true(not overlaps(mark, 0, 0, 17), "Datastar mark overlaps load tag")
    h.assert_true(not overlaps(mark, 11, 61, 78), "Datastar mark overlaps url tag")
    h.assert_true(not overlaps(mark, 11, 84, 94), "Datastar mark overlaps Django output")
  end

  local html = h.new_buffer(fixture, "html")
  datastar.refresh(html)
  h.assert_equal(h.extmarks(html), h.extmarks(django), "HTML and htmldjango semantic output must be exact equivalents")
end
