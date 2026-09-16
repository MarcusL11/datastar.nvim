local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

return function()
  local root = vim.env.DATASTAR_ROOT
  local repository_tags = root .. "/doc/tags"
  h.assert_equal(0, vim.fn.filereadable(repository_tags), "the repository must not contain generated help tags")

  local temporary_root = vim.fn.tempname()
  local temporary_doc = temporary_root .. "/doc"
  local copied_help = temporary_doc .. "/datastar.txt"
  vim.fn.mkdir(temporary_doc, "p")
  vim.fn.writefile(vim.fn.readfile(root .. "/doc/datastar.txt", "b"), copied_help, "b")

  local ok, error_message = xpcall(function()
    vim.cmd("helptags " .. vim.fn.fnameescape(temporary_doc))
    h.assert_equal(1, vim.fn.filereadable(temporary_doc .. "/tags"), "helptags generates tags only in the temporary doc directory")

    vim.opt.runtimepath:prepend(temporary_root)
    vim.cmd("silent help datastar.nvim")
    h.assert_equal("help", vim.bo.buftype, ":help opens a help buffer")
    h.assert_equal(vim.fn.resolve(copied_help), vim.fn.resolve(vim.api.nvim_buf_get_name(0)), ":help datastar.nvim resolves to the copied plugin help")
  end, debug.traceback)

  vim.fn.delete(temporary_root, "rf")
  if not ok then
    error(error_message, 0)
  end
  h.assert_equal(0, vim.fn.filereadable(repository_tags), "help validation never writes doc/tags in the repository")
end
