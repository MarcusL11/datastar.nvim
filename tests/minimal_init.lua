local root = assert(vim.env.DATASTAR_ROOT, "DATASTAR_ROOT is required")
vim.opt.runtimepath:prepend(root)

if vim.env.DATASTAR_TEST_NO_PARSER ~= "1" then
  vim.opt.runtimepath:prepend(root .. "/.deps")
end

vim.cmd("filetype on")
vim.cmd("syntax enable")
