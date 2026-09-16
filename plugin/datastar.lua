if vim.g.loaded_datastar_nvim then
  return
end
vim.g.loaded_datastar_nvim = true

require("datastar").setup()
