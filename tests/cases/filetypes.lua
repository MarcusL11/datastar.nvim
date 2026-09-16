local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

local supported = { "html", "htmldjango", "jinja", "twig", "liquid" }
local secondary = { "jinja", "twig", "liquid" }

local function overlaps(mark, row, start_col, end_col)
  if mark.row ~= row or mark.end_row ~= row then
    return false
  end
  return mark.col < end_col and mark.end_col > start_col
end

local function semantic_text(buf)
  return vim.tbl_map(function(mark)
    return mark.group .. "|" .. h.mark_text(buf, mark)
  end, h.extmarks(buf))
end

return function()
  local identities = {}
  for _, filetype in ipairs(secondary) do
    identities[filetype] = vim.treesitter.language.get_lang(filetype)
  end

  local starts = 0
  local stops = 0
  local datastar
  h.with_patch(vim.treesitter, "start", function(...)
    starts = starts + 1
    return nil
  end, function()
    h.with_patch(vim.treesitter, "stop", function(...)
      stops = stops + 1
      return nil
    end, function()
      datastar = require("datastar")
      datastar.setup()
    end)
  end)
  h.assert_equal(0, starts, "setup never starts a host Tree-sitter highlighter")
  h.assert_equal(0, stops, "setup never stops a host Tree-sitter highlighter")
  h.assert_equal("html", vim.treesitter.language.get_lang("htmldjango"), "only Django is globally registered to HTML")
  for _, filetype in ipairs(secondary) do
    h.assert_equal(identities[filetype], vim.treesitter.language.get_lang(filetype), filetype .. " language identity is unchanged")
  end

  local source = [[<div data-on:click="@get('/x?name={{- product.title -}}') && $ready"></div>]]
  local expected = {
    "DatastarAttributePrefix|data-",
    "DatastarPlugin|on",
    "DatastarKeySeparator|:",
    "DatastarKey|click",
    "DatastarAction|@get",
    "DatastarCallPunctuation|(",
    "DatastarString|'/x?name=",
    "DatastarString|'",
    "DatastarCallPunctuation|)",
    "DatastarOperator|&&",
    "DatastarSignal|$ready",
  }

  local original_start = vim.treesitter.start
  local original_stop = vim.treesitter.stop
  h.with_patch(vim.treesitter, "start", function(...)
    starts = starts + 1
    return original_start(...)
  end, function()
    h.with_patch(vim.treesitter, "stop", function(...)
      stops = stops + 1
      return original_stop(...)
    end, function()
      for _, filetype in ipairs(supported) do
        local buf = h.new_buffer(source, filetype, filetype == "htmldjango" and { syntax = "htmldjango" } or nil)
        local result = datastar.refresh(buf)
        h.assert_equal(nil, result.error, filetype .. " uses the structural HTML parser")
        h.assert_equal(1, result.stats.recognized_attributes, filetype .. " recognizes the exact Datastar attribute")
        h.assert_equal(expected, semantic_text(buf), filetype .. " has exact built-in name and value semantics")

        local hole_start, hole_end = assert(source:find("{{- product.title -}}", 1, true))
        for _, mark in ipairs(h.extmarks(buf)) do
          h.assert_true(not overlaps(mark, 0, hole_start - 1, hole_end), filetype .. " mark overlaps an output hole")
        end

        if filetype ~= "html" then
          local ok, captures = pcall(vim.treesitter.get_captures_at_pos, buf, 0, 6)
          h.assert_true(ok, filetype .. " supports host highlighter inspection")
          h.assert_equal({}, captures, filetype .. " structural parsing does not start a visible HTML highlighter")
        end
        if identities[filetype] then
          h.assert_equal(identities[filetype], vim.treesitter.language.get_lang(filetype), filetype .. " identity survives explicit HTML parsing")
        end
      end
    end)
  end)
  h.assert_equal(0, starts, "setup and attachment never start a host Tree-sitter highlighter")
  h.assert_equal(0, stops, "setup and attachment never stop a host Tree-sitter highlighter")

  local block_source = [[<div data-show="$ready && {%- if enabled -%} true {%- endif -%} && {{ value }}"></div>]]
  for _, filetype in ipairs(supported) do
    local buf = h.new_buffer(block_source, filetype)
    datastar.refresh(buf)
    for _, hole in ipairs({ "{%- if enabled -%}", "{%- endif -%}", "{{ value }}" }) do
      local start_at, end_at = assert(block_source:find(hole, 1, true))
      for _, mark in ipairs(h.extmarks(buf)) do
        h.assert_true(not overlaps(mark, 0, start_at - 1, end_at), filetype .. " mark overlaps " .. hole)
      end
    end
  end

  local unclosed_cases = {
    { source = [[<div data-show="$before && {{ unfinished $after"></div>]], opener = "{{" },
    { source = [[<div data-show="$before && {% unfinished $after"></div>]], opener = "{%" },
  }
  for _, case in ipairs(unclosed_cases) do
    for _, filetype in ipairs(supported) do
      local buf = h.new_buffer(case.source, filetype)
      datastar.refresh(buf)
      local opener = assert(case.source:find(case.opener, 1, true)) - 1
      local texts = semantic_text(buf)
      h.assert_true(vim.tbl_contains(texts, "DatastarSignal|$before"), filetype .. " renders safe tokens before an unclosed " .. case.opener)
      h.assert_true(not vim.tbl_contains(texts, "DatastarSignal|$after"), filetype .. " fails closed after an unclosed " .. case.opener)
      for _, mark in ipairs(h.extmarks(buf)) do
        h.assert_true(mark.end_col <= opener, filetype .. " emits no mark after an unclosed " .. case.opener)
      end
    end
  end

  local cycled = h.new_buffer('<div data-show="$cycled"></div>', "html")
  local renderer = require("datastar.renderer")
  local original_refresh = renderer.refresh
  for _, filetype in ipairs({ "jinja", "twig", "liquid", "htmldjango", "html" }) do
    local refreshes = 0
    h.with_patch(renderer, "refresh", function(buf)
      refreshes = refreshes + 1
      return original_refresh(buf)
    end, function()
      vim.bo[cycled].filetype = filetype
    end)
    h.assert_equal(1, refreshes, "supported transition to " .. filetype .. " refreshes once")
    h.assert_equal(true, datastar._state().attached[cycled], "supported transition remains attached")
  end

  local edit_refreshes = 0
  h.with_patch(renderer, "refresh", function(buf)
    edit_refreshes = edit_refreshes + 1
    return original_refresh(buf)
  end, function()
    vim.api.nvim_buf_set_lines(cycled, 0, -1, true, { '<div data-show="!$cycled"></div>' })
  end)
  h.assert_equal(1, edit_refreshes, "supported transitions preserve exactly one current buffer callback")

  vim.bo[cycled].filetype = "lua"
  h.assert_equal(nil, datastar._state().attached[cycled], "unsupported transition detaches")
  h.assert_equal({}, h.extmarks(cycled), "unsupported transition clears only plugin marks")
end
