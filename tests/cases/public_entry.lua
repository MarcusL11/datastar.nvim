local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

return function()
  local html = h.new_buffer('<div data-show="$html"></div>', "html")
  local django = h.new_buffer('<div data-on:click="@get(\'/ready\')"></div>', "htmldjango")
  local unsupported = h.new_buffer('<div data-show="$lua"></div>', "lua")

  local datastar = require("datastar")
  datastar.setup()
  local before_loader = h.autocmd_topology("datastar.nvim")
  h.assert_true(#h.extmarks(html) > 0, "explicit setup before the loader attaches pre-existing HTML buffers")
  h.assert_true(#h.extmarks(django) > 0, "explicit setup attaches every pre-existing eligible buffer")
  h.assert_equal({}, h.extmarks(unsupported), "setup leaves unsupported pre-existing buffers alone")

  vim.cmd("runtime plugin/datastar.lua")
  h.assert_equal(true, vim.g.loaded_datastar_nvim, "the public loader records activation")
  h.assert_equal(before_loader, h.autocmd_topology("datastar.nvim"), "loading after explicit setup does not duplicate autocmds")

  datastar.setup()
  h.assert_equal(before_loader, h.autocmd_topology("datastar.nvim"), "explicit setup after the loader remains idempotent")

  local renderer = require("datastar.renderer")
  local original_refresh = renderer.refresh
  local refresh_count = 0
  h.with_patch(renderer, "refresh", function(buf)
    refresh_count = refresh_count + 1
    return original_refresh(buf)
  end, function()
    vim.api.nvim_buf_set_lines(html, 0, -1, true, { '<div data-show="!$html"></div>' })
  end)
  h.assert_equal(1, refresh_count, "mixed loader and explicit setup paths install one buffer callback")

  vim.cmd("runtime plugin/datastar.lua")
  h.assert_equal(before_loader, h.autocmd_topology("datastar.nvim"), "re-sourcing the public loader is a no-op")
  h.assert_equal({}, h.extmarks(unsupported), "public activation does not broaden the filetype boundary")
end
