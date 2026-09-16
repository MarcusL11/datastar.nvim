local highlights = require("datastar.highlights")
local renderer = require("datastar.renderer")

local M = {}

local attached = {}
local warned_for_parser = false
local setup_complete = false
local augroup_name = "datastar.nvim"

local function eligible(buf)
  local filetype = vim.bo[buf].filetype
  return filetype == "html" or filetype == "htmldjango"
end

local function warn_once(reason)
  if warned_for_parser or (reason ~= "missing_parser" and reason ~= "query_failed") then
    return
  end
  warned_for_parser = true
  vim.notify(
    "datastar.nvim: the HTML Tree-sitter parser is required for Datastar highlighting; host syntax was left unchanged",
    vim.log.levels.WARN
  )
end

function M.refresh(buf)
  return renderer.refresh(buf)
end

function M.attach(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) or not eligible(buf) then
    return false
  end
  if attached[buf] then
    return true
  end

  -- Initialize the Tree-sitter parser before our buffer callback so its edit and
  -- reload callbacks invalidate the tree before our synchronous refresh runs.
  renderer.refresh(buf)

  local did_attach = vim.api.nvim_buf_attach(buf, false, {
    on_lines = function()
      if attached[buf] then
        renderer.refresh(buf)
      end
      return false
    end,
    on_reload = function()
      if attached[buf] then
        renderer.refresh(buf)
      end
    end,
    on_detach = function()
      attached[buf] = nil
    end,
  })

  if not did_attach then
    renderer.clear(buf)
    return false
  end

  attached[buf] = true
  return true
end

function M.detach(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not attached[buf] then
    renderer.clear(buf)
    return false
  end

  renderer.clear(buf)
  attached[buf] = nil
  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_detach, buf)
  end
  return true
end

function M.setup()
  vim.treesitter.language.register("html", "htmldjango")
  renderer.set_warning_handler(warn_once)
  highlights.define()

  local group = vim.api.nvim_create_augroup(augroup_name, { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "*",
    callback = function(args)
      if eligible(args.buf) then
        M.attach(args.buf)
      else
        M.detach(args.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = highlights.define,
  })
  vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
    group = group,
    callback = function(args)
      attached[args.buf] = nil
    end,
  })

  setup_complete = true
  local current = vim.api.nvim_get_current_buf()
  if eligible(current) then
    M.attach(current)
  end
end

function M.namespace()
  return renderer.namespace()
end

function M._state()
  return {
    attached = vim.deepcopy(attached),
    setup_complete = setup_complete,
    warned_for_parser = warned_for_parser,
  }
end

return M
