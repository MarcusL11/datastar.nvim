local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

return function()
  local html = h.new_buffer('<div data-show="$html"></div>', "html")
  local django = h.new_buffer('<div data-on:click="@get(\'/ready\')"></div>', "htmldjango")
  local unsupported = h.new_buffer('<div data-show="$lua"></div>', "lua")
  local notices = {}

  h.with_patch(vim, "notify", function(message, level)
    notices[#notices + 1] = { message = message, level = level }
  end, function()
    vim.cmd("runtime plugin/datastar.lua")
    h.assert_equal(true, vim.g.loaded_datastar_nvim, "the public loader records zero-config activation")

    local datastar = require("datastar")
    h.assert_true(#h.extmarks(html) > 0, "zero-config loading attaches pre-existing HTML buffers")
    h.assert_true(#h.extmarks(django) > 0, "zero-config loading attaches pre-existing Django buffers")
    h.assert_equal({}, h.extmarks(unsupported), "zero-config loading ignores unsupported buffers")

    local topology = h.autocmd_topology("datastar.nvim")
    local renderer = require("datastar.renderer")
    local original_refresh = renderer.refresh
    local refresh_count = 0
    h.with_patch(renderer, "refresh", function(buf)
      refresh_count = refresh_count + 1
      return original_refresh(buf)
    end, function()
      vim.api.nvim_buf_set_lines(html, 0, -1, true, { '<div data-show="!$html"></div>' })
    end)
    h.assert_equal(1, refresh_count, "one edit triggers exactly one zero-config refresh")

    datastar.setup()
    h.assert_equal(topology, h.autocmd_topology("datastar.nvim"), "explicit setup after zero-config loading is idempotent")
    h.assert_true(#h.extmarks(html) > 0 and #h.extmarks(django) > 0, "explicit setup preserves eligible marks")
    h.assert_equal({}, h.extmarks(unsupported), "explicit setup preserves the filetype boundary")
  end)

  h.assert_equal({}, notices, "the valid zero-config path emits no warnings")
end
