local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

local function notices_matching(notices, pattern)
  local count = 0
  for _, notice in ipairs(notices) do
    if notice.message:match(pattern) then
      count = count + 1
    end
  end
  return count
end

local function seed_stale_mark(buf, namespace)
  vim.api.nvim_buf_set_extmark(buf, namespace, 0, 0, {
    end_row = 0,
    end_col = 1,
    hl_group = "Error",
  })
end

return function()
  local notices = {}
  local notify_must_fail = false
  local first_internal
  local second_internal
  local internal_ok
  local buf

  h.with_patch(vim, "notify", function(message, level)
    notices[#notices + 1] = { message = message, level = level }
    if notify_must_fail then
      error("simulated notification failure")
    end
  end, function()
    vim.cmd("runtime plugin/datastar.lua")
    local datastar = require("datastar")
    local namespace = datastar.namespace()

    local original_query_parse = vim.treesitter.query.parse
    h.with_patch(vim.treesitter.query, "parse", function()
      error("simulated query failure")
    end, function()
      buf = h.new_buffer("{% load static %}\n<div data-show=\"$ready\"></div>", "htmldjango", { syntax = "htmldjango" })
      seed_stale_mark(buf, namespace)
      local first_query = datastar.refresh(buf)
      h.assert_equal({}, h.extmarks(buf), "query failure clears a seeded stale Datastar mark")
      local second_query = datastar.refresh(buf)
      h.assert_equal("query_failed", first_query.error, "query failures have a stable public result")
      h.assert_equal("query_failed", second_query.error, "repeated query failures remain safe")
    end)
    h.assert_equal(original_query_parse, vim.treesitter.query.parse, "query parser patch is restored")
    h.assert_equal(1, notices_matching(notices, "query"), "query failure warning is emitted once")

    local recovered = datastar.refresh(buf)
    h.assert_equal(nil, recovered.error, "refresh recovers after a transient query failure")
    h.assert_true(#h.extmarks(buf) > 0, "query recovery restores Datastar marks")

    local original_get_parser = vim.treesitter.get_parser
    h.with_patch(vim.treesitter, "get_parser", function()
      return {
        parse = function()
          error("simulated parse failure")
        end,
      }
    end, function()
      local first_parse = datastar.refresh(buf)
      h.assert_equal({}, h.extmarks(buf), "parse failure clears stale Datastar marks")
      local second_parse = datastar.refresh(buf)
      h.assert_equal("parse_failed", first_parse.error, "parse failures have a stable public result")
      h.assert_equal("parse_failed", second_parse.error, "repeated parse failures remain safe")
    end)
    h.assert_equal(original_get_parser, vim.treesitter.get_parser, "Tree-sitter parser patch is restored")
    h.assert_equal(1, notices_matching(notices, "could not parse"), "parse failure warning is emitted once")

    local parse_recovered = datastar.refresh(buf)
    h.assert_equal(nil, parse_recovered.error, "refresh recovers after a transient parse failure")
    h.assert_true(#h.extmarks(buf) > 0, "parse recovery restores Datastar marks")

    local renderer = require("datastar.renderer")
    h.with_patch(renderer, "refresh", function()
      error("simulated internal refresh failure")
    end, function()
      notify_must_fail = true
      internal_ok, first_internal = pcall(datastar.refresh, buf)
      h.assert_equal({}, h.extmarks(buf), "unexpected refresh failure clears recovered stale marks")
      second_internal = datastar.refresh(buf)
    end)
  end)

  h.assert_true(internal_ok, "internal refresh failures do not escape through the public API")
  h.assert_match(first_internal.error, "simulated internal refresh failure", "internal failure remains inspectable")
  h.assert_match(second_internal.error, "simulated internal refresh failure", "repeated internal failure remains inspectable")
  h.assert_equal(1, notices_matching(notices, "unexpectedly"), "internal failure warning is emitted once")
  for _, notice in ipairs(notices) do
    h.assert_equal(vim.log.levels.WARN, notice.level, "failure notices use warning severity")
    h.assert_match(notice.message, "host syntax was left unchanged", "failure notices explain host-safe degradation")
  end

  vim.api.nvim_set_current_buf(buf)
  vim.cmd("syntax sync fromstart")
  h.assert_equal("djangoTagBlock", h.direct_syntax_group(0, 0), "failure paths preserve host Django syntax")
  h.assert_equal({}, h.extmarks(buf), "internal refresh failure leaves no Datastar marks")
end
