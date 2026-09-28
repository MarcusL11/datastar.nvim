local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

local function only_parser(language)
  local runtime = vim.fn.tempname()
  vim.fn.mkdir(runtime .. "/parser", "p")
  local file = "/parser/" .. language .. ".so"
  vim.fn.writefile(vim.fn.readfile(vim.env.DATASTAR_ROOT .. "/.deps" .. file, "b"), runtime .. file, "b")
  vim.opt.runtimepath:prepend(runtime)
  return runtime
end

return function()
  h.assert_equal({}, h.runtime_parser_paths("javascript"), "JavaScript parser is not device-local")
  h.assert_equal({}, h.runtime_parser_paths("html"), "HTML parser is not device-local")
  local notices = {}
  h.with_patch(vim, "notify", function(message, level)
    notices[#notices + 1] = { message = message, level = level }
  end, function()
    local datastar = require("datastar")
    datastar.setup()
    local buf = h.new_buffer('const view = html`<p data-show="$ready"></p>`;', "javascript")
    for _ = 1, 2 do
      h.assert_equal("missing_javascript_parser", datastar.refresh(buf).error, "missing JavaScript parser degrades safely")
      h.assert_equal({}, h.extmarks(buf), "no marks without JavaScript parser")
    end
    h.assert_true(datastar._state().attached[buf], "failed refresh keeps the buffer attached")
    h.assert_equal(1, #notices, "JavaScript parser warning is deduplicated")
    h.assert_match(notices[1].message, ":TSInstall javascript", "JavaScript warning is actionable")

    local runtime = only_parser("javascript")
    h.assert_equal("javascript", vim.treesitter.get_parser(buf, "javascript"):lang(), "host JavaScript parser is available")
    local started, start_error = pcall(vim.treesitter.start, buf, "javascript")
    h.assert_true(started, "visible JavaScript highlighter can start: " .. tostring(start_error))
    for _ = 1, 2 do
      h.assert_equal("missing_parser", datastar.refresh(buf).error, "missing HTML parser degrades safely")
      h.assert_equal({}, h.extmarks(buf), "no marks without HTML parser")
    end
    h.assert_equal(2, #notices, "HTML warning is deduplicated")
    h.assert_match(notices[2].message, ":TSInstall html", "HTML warning is actionable")
    h.assert_equal("javascript", vim.treesitter.get_parser(buf):lang(), "host highlighter remains JavaScript")
    h.assert_equal("javascript", vim.bo[buf].filetype, "host filetype survives parser failures")

    vim.opt.runtimepath:prepend(vim.env.DATASTAR_ROOT .. "/.deps")
    h.assert_equal(nil, datastar.refresh(buf).error, "both parser dependencies recover in the same buffer")
    h.assert_true(#h.extmarks(buf) > 0, "recovery paints Datastar marks")
    h.assert_equal("javascript", vim.treesitter.get_parser(buf):lang(), "recovery does not replace host parser")
    h.with_patch(vim.treesitter, "get_string_parser", function() error("HTML parser unavailable") end, function()
      h.assert_equal("missing_parser", datastar.refresh(buf).error, "late parser failure clears stale marks")
      h.assert_equal({}, h.extmarks(buf), "late parser failure clears only Datastar marks")
      h.assert_equal("javascript", vim.treesitter.get_parser(buf):lang(), "late parser failure preserves host parser")
    end)
    h.assert_equal(2, #notices, "repeat HTML failure does not repeat warning")
    h.assert_equal(nil, datastar.refresh(buf).error, "late HTML parser failure recovers")
    vim.opt.runtimepath:remove(runtime)
    vim.fn.delete(runtime, "rf")
  end)
  for _, notice in ipairs(notices) do
    h.assert_equal(vim.log.levels.WARN, notice.level, "missing-parser warning level")
    h.assert_match(notice.message, "host syntax was left unchanged", "warning states safe degradation")
  end
end
