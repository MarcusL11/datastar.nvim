local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

return function()
  h.assert_equal({}, h.runtime_parser_paths(), "parser-absence case must not see a developer parser")

  local notices = {}
  local buf = h.new_buffer("{% load static %}\n<div data-show=\"$ready\"></div>", "htmldjango", { syntax = "htmldjango" })
  local first
  local second
  local recovered

  h.with_patch(vim, "notify", function(message, level)
    notices[#notices + 1] = { message = message, level = level }
  end, function()
    vim.cmd("runtime plugin/datastar.lua")
    local datastar = require("datastar")
    first = datastar.refresh(buf)
    second = datastar.refresh(buf)

    h.assert_true(datastar._state().attached[buf], "zero-config loader attaches an eligible pre-existing buffer")
    h.assert_equal("missing_parser", first.error, "missing parser result")
    h.assert_equal("missing_parser", second.error, "repeated missing parser result")
    h.assert_equal({}, h.extmarks(buf), "parser absence leaves Datastar namespace empty")

    vim.opt.runtimepath:prepend(vim.env.DATASTAR_ROOT .. "/.deps")
    h.assert_equal({ vim.env.DATASTAR_ROOT .. "/.deps/parser/html.so" }, h.runtime_parser_paths(), "the pinned parser becomes discoverable")
    recovered = datastar.refresh(buf)
    h.assert_equal(nil, recovered.error, "the same attached buffer recovers after the parser is installed")
    h.assert_true(datastar._state().attached[buf], "parser recovery does not replace the buffer attachment")
    h.assert_true(#h.extmarks(buf) > 0, "parser recovery renders Datastar marks")
  end)

  h.assert_equal(1, #notices, "parser installation recovery emits no duplicate warning")
  h.assert_match(notices[1].message, "HTML Tree%-sitter parser is required", "warning identifies the prerequisite")
  h.assert_match(notices[1].message, ":TSInstall html", "warning gives an actionable installation path")
  h.assert_match(notices[1].message, "host syntax was left unchanged", "warning explains safe degradation")
  h.assert_equal(vim.log.levels.WARN, notices[1].level, "warning level")

  vim.api.nvim_set_current_buf(buf)
  vim.cmd("syntax sync fromstart")
  h.assert_equal("djangoTagBlock", h.direct_syntax_group(0, 0), "host Django syntax survives parser absence and recovery")
end
