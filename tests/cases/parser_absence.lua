local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

return function()
  h.assert_equal({}, h.runtime_parser_paths(), "parser-absence case must not see a developer parser")

  local notices = {}
  local buffers = {}
  for _, filetype in ipairs({ "html", "htmldjango", "jinja", "twig", "liquid" }) do
    buffers[filetype] = h.new_buffer(
      "{% load static %}\n<div data-show=\"$ready\"></div>",
      filetype,
      filetype == "htmldjango" and { syntax = "htmldjango" } or nil
    )
  end

  h.with_patch(vim, "notify", function(message, level)
    notices[#notices + 1] = { message = message, level = level }
  end, function()
    vim.cmd("runtime plugin/datastar.lua")
    local datastar = require("datastar")

    for filetype, buf in pairs(buffers) do
      local first = datastar.refresh(buf)
      local second = datastar.refresh(buf)
      h.assert_equal("missing_parser", first.error, filetype .. " has a stable missing-parser result")
      h.assert_equal("missing_parser", second.error, filetype .. " remains safe on repeated failure")
      h.assert_true(datastar._state().attached[buf], filetype .. " remains attached while the parser is absent")
      h.assert_equal({}, h.extmarks(buf), filetype .. " parser absence leaves the namespace empty")
    end

    vim.opt.runtimepath:prepend(vim.env.DATASTAR_ROOT .. "/.deps")
    h.assert_equal({ vim.env.DATASTAR_ROOT .. "/.deps/parser/html.so" }, h.runtime_parser_paths(), "the pinned parser becomes discoverable")

    for filetype, buf in pairs(buffers) do
      local recovered = datastar.refresh(buf)
      h.assert_equal(nil, recovered.error, filetype .. " recovers in the same buffer after parser discovery")
      h.assert_true(datastar._state().attached[buf], filetype .. " recovery does not replace its attachment")
      h.assert_true(#h.extmarks(buf) > 0, filetype .. " recovery renders Datastar marks")
    end
  end)

  h.assert_equal(1, #notices, "all filetypes share one actionable parser warning")
  h.assert_match(notices[1].message, "HTML Tree%-sitter parser is required", "warning identifies the prerequisite")
  h.assert_match(notices[1].message, ":TSInstall html", "warning gives an actionable installation path")
  h.assert_match(notices[1].message, "host syntax was left unchanged", "warning explains safe degradation")
  h.assert_equal(vim.log.levels.WARN, notices[1].level, "warning level")

  local django = buffers.htmldjango
  vim.api.nvim_set_current_buf(django)
  vim.cmd("syntax sync fromstart")
  h.assert_equal("djangoTagBlock", h.direct_syntax_group(0, 0), "host Django syntax survives parser absence and recovery")
end
