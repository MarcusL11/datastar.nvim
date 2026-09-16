local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

local function mark_ids(buf, namespace)
  local ids = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, {})) do
    ids[#ids + 1] = mark[1]
  end
  return ids
end

return function()
  vim.cmd("runtime plugin/datastar.lua")
  local datastar = require("datastar")
  local expected_topology = {
    ["BufUnload:*"] = 1,
    ["BufWipeout:*"] = 1,
    ["ColorScheme:*"] = 1,
    ["FileType:*"] = 1,
  }
  h.assert_equal(expected_topology, h.autocmd_topology("datastar.nvim"), "the loader installs the exact lifecycle topology")

  datastar.setup()
  h.assert_equal(expected_topology, h.autocmd_topology("datastar.nvim"), "repeated setup preserves the exact lifecycle topology")

  local renderer = require("datastar.renderer")
  local ordered = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(ordered, 0, -1, true, { '<div data-show="$ordered"></div>' })
  local call_order = {}
  local original_refresh_for_order = renderer.refresh
  local original_buf_attach = vim.api.nvim_buf_attach
  h.with_patch(renderer, "refresh", function(target)
    call_order[#call_order + 1] = "refresh"
    return original_refresh_for_order(target)
  end, function()
    h.with_patch(vim.api, "nvim_buf_attach", function(...)
      call_order[#call_order + 1] = "attach"
      return original_buf_attach(...)
    end, function()
      vim.bo[ordered].filetype = "html"
    end)
  end)
  h.assert_equal("refresh", call_order[1], "Tree-sitter refresh begins before any buffer attachment")
  h.assert_equal("attach", call_order[#call_order], "the plugin buffer callback attaches after the initial refresh")

  local buf = h.new_buffer('<div data-show="$ready"></div>', "html")
  h.assert_true(datastar.attach(buf), "first attachment")
  local namespace = datastar.namespace()
  local before_ids = mark_ids(buf, namespace)
  h.assert_true(datastar.attach(buf), "repeat attachment is a no-op success")
  h.assert_equal(before_ids, mark_ids(buf, namespace), "no-op reattach must preserve extmark IDs")

  local original_refresh = renderer.refresh
  local refresh_count = 0
  h.with_patch(renderer, "refresh", function(target)
    refresh_count = refresh_count + 1
    return original_refresh(target)
  end, function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, { '<div data-show="!$ready"></div>' })
  end)
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

  local cycled = h.new_buffer('<div data-show="$cycled"></div>', "html")
  for _ = 1, 3 do
    vim.bo[cycled].filetype = "lua"
    h.assert_equal(nil, datastar._state().attached[cycled], "each unsupported filetype transition detaches")
    vim.bo[cycled].filetype = "html"
    h.assert_equal(true, datastar._state().attached[cycled], "each HTML transition reattaches")
  end
  refresh_count = 0
  h.with_patch(renderer, "refresh", function(target)
    refresh_count = refresh_count + 1
    return original_refresh(target)
  end, function()
    vim.api.nvim_buf_set_lines(cycled, 0, -1, true, { '<div data-show="!$cycled"></div>' })
  end)
  h.assert_equal(1, refresh_count, "repeated filetype detach and reattach leaves exactly one refresh callback")
  h.assert_equal(true, datastar._state().attached[cycled], "stale callback cleanup does not clear the current attachment")

  local normalized = h.new_buffer('<div data-show="$normalized"></div>', "html")
  h.assert_true(datastar.attach(0), "buffer zero resolves to the current attached buffer")
  h.assert_equal(nil, datastar._state().attached[0], "buffer zero is never retained as an attachment key")
  h.assert_equal(nil, datastar.refresh(0).error, "refresh resolves buffer zero immediately")
  h.assert_true(datastar.detach(0), "detach resolves buffer zero immediately")
  h.assert_equal(false, datastar.detach(0), "repeated detach through buffer zero is idempotent")
  h.assert_true(datastar.attach(0), "buffer zero can reattach the concrete current buffer")
  h.assert_equal(true, datastar._state().attached[normalized], "zero-based reattach records the concrete buffer id")
  h.assert_equal(nil, datastar._state().attached[0], "zero-based reattach does not create alias state")

  local invalid_buffers = { false, "1", 0 / 0, math.huge, -math.huge, 1.5, -1 }
  local marks_before_invalid_calls = h.extmarks(normalized)
  for _, invalid in ipairs(invalid_buffers) do
    h.assert_equal(false, datastar.attach(invalid), "invalid attach arguments are rejected")
    h.assert_equal("invalid_buffer", datastar.refresh(invalid).error, "invalid refresh arguments are rejected")
    h.assert_equal(false, datastar.detach(invalid), "invalid detach arguments are rejected")
    h.assert_equal(true, datastar._state().attached[normalized], "invalid arguments do not detach the current buffer")
    h.assert_equal(marks_before_invalid_calls, h.extmarks(normalized), "invalid arguments do not alter current buffer marks")
  end

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

  local unsupported = h.new_buffer('<div data-show="$unsupported"></div>', "lua")
  h.assert_equal(false, datastar.attach(unsupported), "public attach rejects unsupported filetypes")
  h.assert_equal("unsupported_filetype", datastar.refresh(unsupported).error, "public refresh rejects unsupported filetypes")
  h.assert_equal(false, datastar.detach(unsupported), "public detach is safe for an unsupported unattached buffer")
  h.assert_equal({}, h.extmarks(unsupported), "unsupported public calls never create Datastar marks")

  local unloaded = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(unloaded, 0, -1, true, { '<div data-show="$unloaded"></div>' })
  vim.bo[unloaded].filetype = "html"
  h.assert_true(datastar._state().attached[unloaded], "loaded eligible control attaches")
  vim.api.nvim_buf_delete(unloaded, { force = true, unload = true })
  h.assert_equal(nil, datastar._state().attached[unloaded], "BufUnload immediately removes buffer-local attachment state")
  h.assert_true(vim.api.nvim_buf_is_valid(unloaded), "unloaded lifecycle control remains valid")
  h.assert_equal(false, vim.api.nvim_buf_is_loaded(unloaded), "lifecycle control is unloaded")
  h.assert_equal(false, datastar.attach(unloaded), "public attach is safe for unloaded buffers")
  h.assert_equal("invalid_buffer", datastar.refresh(unloaded).error, "public refresh is safe for unloaded buffers")
  h.assert_equal(false, datastar.detach(unloaded), "public detach is safe for unloaded buffers")

  local third = h.new_buffer('<div data-show="$three"></div>', "html")
  datastar.attach(third)
  vim.api.nvim_buf_delete(third, { force = true })
  h.assert_equal(nil, datastar._state().attached[third], "wipeout removes buffer-local attachment state")
  h.assert_equal(false, datastar.attach(third), "public attach is safe for invalid buffers")
  h.assert_equal("invalid_buffer", datastar.refresh(third).error, "public refresh is safe for invalid buffers")
  h.assert_equal(false, datastar.detach(third), "public detach is safe for invalid buffers")
end
