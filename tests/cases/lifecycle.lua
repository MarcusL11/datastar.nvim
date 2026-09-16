local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

local function mark_ids(buf, namespace)
  local ids = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, {})) do
    ids[#ids + 1] = mark[1]
  end
  return ids
end

return function()
  local datastar = require("datastar")
  datastar.setup()
  local first_autocmds = vim.api.nvim_get_autocmds({ group = "datastar.nvim" })
  datastar.setup()
  local second_autocmds = vim.api.nvim_get_autocmds({ group = "datastar.nvim" })
  h.assert_equal(#first_autocmds, #second_autocmds, "repeated setup must not accumulate autocmds")

  local filetype_patterns = {}
  for _, autocmd in ipairs(second_autocmds) do
    if autocmd.event == "FileType" then
      filetype_patterns[autocmd.pattern] = true
    end
  end
  h.assert_equal({ ["*"] = true }, filetype_patterns, "one FileType autocmd handles attachment and detachment")

  local buf = h.new_buffer('<div data-show="$ready"></div>', "html")
  h.assert_true(datastar.attach(buf), "first attachment")
  local namespace = datastar.namespace()
  local before_ids = mark_ids(buf, namespace)
  h.assert_true(datastar.attach(buf), "repeat attachment is a no-op success")
  h.assert_equal(before_ids, mark_ids(buf, namespace), "no-op reattach must preserve extmark IDs")

  local renderer = require("datastar.renderer")
  local original_refresh = renderer.refresh
  local refresh_count = 0
  renderer.refresh = function(target)
    refresh_count = refresh_count + 1
    return original_refresh(target)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, { '<div data-show="!$ready"></div>' })
  renderer.refresh = original_refresh
  h.assert_equal(1, refresh_count, "one edit must cause one semantic refresh")
  local automatic_text = vim.tbl_map(function(mark)
    return h.mark_text(buf, mark)
  end, h.extmarks(buf))
  h.assert_true(vim.tbl_contains(automatic_text, "!"), "automatic refresh must parse the edited tree, not stale structure")

  local external_namespace = vim.api.nvim_create_namespace("datastar.nvim.lifecycle.external")
  vim.api.nvim_buf_set_extmark(buf, external_namespace, 0, 0, {
    end_row = 0,
    end_col = 1,
    hl_group = "Error",
  })
  h.assert_true(datastar.detach(buf), "explicit detach")
  h.assert_equal({}, h.extmarks(buf), "detach clears plugin marks")
  h.assert_equal(1, #vim.api.nvim_buf_get_extmarks(buf, external_namespace, 0, -1, {}), "detach preserves foreign namespace")

  local first = h.new_buffer('<div data-show="$one"></div>', "html")
  local second = h.new_buffer('<div data-show="$two"></div>', "html")
  datastar.attach(first)
  datastar.attach(second)
  h.assert_true(#h.extmarks(first) > 0 and #h.extmarks(second) > 0, "state is buffer-local")
  datastar.detach(first)
  h.assert_equal({}, h.extmarks(first), "detaching one buffer clears only that buffer")
  h.assert_true(#h.extmarks(second) > 0, "second buffer remains attached")

  vim.bo[second].filetype = "lua"
  h.assert_equal({}, h.extmarks(second), "changing to an unsupported filetype clears plugin marks")
  h.assert_equal(nil, datastar._state().attached[second], "changing filetype detaches plugin callbacks")

  local filename = vim.fn.tempname() .. ".html"
  vim.fn.writefile({ '<div data-show="$before"></div>' }, filename)
  vim.cmd("edit " .. vim.fn.fnameescape(filename))
  local reloaded = vim.api.nvim_get_current_buf()
  vim.bo[reloaded].filetype = "html"
  datastar.attach(reloaded)
  vim.fn.writefile({ '<div data-on:click="@get(\'/after\')"></div>' }, filename)
  vim.cmd("edit!")
  local reload_text = vim.tbl_map(function(mark)
    return h.mark_text(reloaded, mark)
  end, h.extmarks(reloaded))
  h.assert_true(vim.tbl_contains(reload_text, "@get"), "reload must refresh from the invalidated parser tree")
  h.assert_true(not vim.tbl_contains(reload_text, "$before"), "reload must not retain stale semantic marks")
  vim.api.nvim_buf_delete(reloaded, { force = true })
  vim.fn.delete(filename)

  local third = h.new_buffer('<div data-show="$three"></div>', "html")
  datastar.attach(third)
  vim.api.nvim_buf_delete(third, { force = true })
  h.assert_equal(nil, datastar._state().attached[third], "wipeout removes buffer-local attachment state")
end
