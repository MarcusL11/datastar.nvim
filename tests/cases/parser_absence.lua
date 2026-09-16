local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

return function()
  h.assert_equal({}, h.runtime_parser_paths(), "parser-absence case must not see a developer parser")

  local notices = {}
  local original_notify = vim.notify
  vim.notify = function(message, level)
    notices[#notices + 1] = { message = message, level = level }
  end

  local datastar = require("datastar")
  datastar.setup()
  datastar.setup()
  local buf = h.new_buffer("{% load static %}\n<div data-show=\"$ready\"></div>", "htmldjango", { syntax = "htmldjango" })
  local first = datastar.refresh(buf)
  local second = datastar.refresh(buf)
  vim.notify = original_notify

  h.assert_equal("missing_parser", first.error, "missing parser result")
  h.assert_equal("missing_parser", second.error, "repeated missing parser result")
  h.assert_equal(1, #notices, "parser absence emits at most one warning")
  h.assert_match(notices[1].message, "HTML Tree%-sitter parser is required", "warning is actionable")
  h.assert_equal(vim.log.levels.WARN, notices[1].level, "warning level")
  h.assert_equal({}, h.extmarks(buf), "parser absence leaves Datastar namespace empty")

  vim.api.nvim_set_current_buf(buf)
  vim.cmd("syntax sync fromstart")
  h.assert_equal("djangoTagBlock", h.direct_syntax_group(0, 0), "host Django syntax survives parser absence")
end
