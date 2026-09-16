local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

local color_keys = { "fg", "bg", "sp", "ctermfg", "ctermbg" }

local function assert_links(groups)
  for group, target in pairs(groups) do
    local definition = vim.api.nvim_get_hl(0, { name = group, link = true, create = false })
    h.assert_equal(target, definition.link, group .. " default link")
    for _, key in ipairs(color_keys) do
      h.assert_equal(nil, definition[key], group .. " must not define " .. key)
    end
  end
end

return function()
  vim.cmd("runtime plugin/datastar.lua")
  local highlights = require("datastar.highlights")
  vim.api.nvim_set_hl(0, "DatastarPlugin", { fg = 0x123456 })
  highlights.define()
  local override = vim.api.nvim_get_hl(0, { name = "DatastarPlugin", link = true, create = false })
  h.assert_equal(0x123456, override.fg, "default linking must preserve a user override")
  h.assert_equal(nil, override.link, "user override must not be replaced with a link")

  vim.api.nvim_set_hl(0, "DatastarPlugin", { link = highlights.groups.DatastarPlugin })
  assert_links(highlights.groups)

  vim.cmd("highlight clear")
  vim.api.nvim_exec_autocmds("ColorScheme", {})
  assert_links(highlights.groups)
end
