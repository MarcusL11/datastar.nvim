local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

local malformed = {
  "<div data-",
  "<div data-on:",
  "<div data-on:click__",
  "<div data-on:click__debounce.",
  '<div data-on:click="$_ready && @get(">',
  '<div data-signals="{foo: {">',
  '<div data-on:click="{% url \'items\' %>">',
  '<div data-on:click="{{ page }">',
  '<div data-ordinary="$_not_datastar">',
}

local function assert_in_bounds(buf, marks)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
  for _, mark in ipairs(marks) do
    h.assert_true(mark.row >= 0 and mark.end_row < #lines, "mark row out of bounds")
    h.assert_true(mark.col >= 0 and mark.col <= #lines[mark.row + 1], "mark start out of bounds")
    h.assert_true(mark.end_col >= 0 and mark.end_col <= #lines[mark.end_row + 1], "mark end out of bounds")
    h.assert_true(mark.row < mark.end_row or mark.col < mark.end_col, "empty semantic token was invented")
    h.assert_true(h.mark_text(buf, mark) ~= "", "empty semantic text was invented")
  end
end

local function fresh_marks(datastar, text)
  local buf = h.new_buffer(text, "html")
  local result = datastar.refresh(buf)
  h.assert_equal(nil, result.error, "fresh malformed refresh should not throw")
  assert_in_bounds(buf, h.extmarks(buf))
  return h.extmarks(buf), buf
end

return function()
  local datastar = require("datastar")
  datastar.setup()

  for _, text in ipairs(malformed) do
    fresh_marks(datastar, text)
  end

  local partial_key = fresh_marks(datastar, "<div data-on:")
  for _, mark in ipairs(partial_key) do
    h.assert_true(mark.group ~= "DatastarKey" and mark.group ~= "DatastarKeySeparator", "incomplete key invented a token")
  end

  local partial_modifier = fresh_marks(datastar, "<div data-on:click__")
  for _, mark in ipairs(partial_modifier) do
    h.assert_true(mark.group ~= "DatastarModifier" and mark.group ~= "DatastarModifierSeparator", "incomplete modifier invented a token")
  end

  local unclosed = [[<div data-on:click="'before {% url 'items' after $signal">]]
  local marks, unclosed_buf = fresh_marks(datastar, unclosed)
  local opener = assert(unclosed:find("{%", 1, true)) - 1
  for _, mark in ipairs(marks) do
    h.assert_true(mark.end_row < 0 or mark.row > 0 or mark.end_col <= opener, "unclosed Django hole did not fail closed")
  end
  h.assert_true(vim.tbl_contains(vim.tbl_map(function(mark)
    return h.mark_text(unclosed_buf, mark)
  end, marks), "'before "), "completed string portion before an unclosed hole should remain highlighted")

  local incomplete = '<div data-on:click="$_ready && @get(">'
  local complete = '<div data-on:click="$_ready && @get(\'/items\')">'
  local editing = h.new_buffer(incomplete, "html")
  datastar.refresh(editing)
  vim.api.nvim_buf_set_lines(editing, 0, -1, true, { complete })
  datastar.refresh(editing)
  local edited_valid = h.extmarks(editing)
  local fresh_valid = fresh_marks(datastar, complete)
  h.assert_equal(fresh_valid, edited_valid, "edit-to-valid output must converge")

  vim.api.nvim_buf_set_lines(editing, 0, -1, true, { incomplete })
  datastar.refresh(editing)
  local edited_incomplete = h.extmarks(editing)
  local fresh_incomplete = fresh_marks(datastar, incomplete)
  h.assert_equal(fresh_incomplete, edited_incomplete, "delete-back output must converge")

  vim.api.nvim_buf_set_lines(editing, 0, -1, true, { '<div data-ordinary="$_ready">' })
  datastar.refresh(editing)
  h.assert_equal({}, h.extmarks(editing), "refresh must remove stale Datastar marks")
end
