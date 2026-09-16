local highlights = require("datastar.highlights")
local renderer = require("datastar.renderer")

local M = {}

local attached = {}
local attachment_tokens = {}
local notices = {}
local setup_complete = false
local augroup_name = "datastar.nvim"

local notice_messages = {
  missing_parser = "datastar.nvim: the HTML Tree-sitter parser is required for Datastar highlighting; install it with :TSInstall html (or your parser manager) and reload the buffer; host syntax was left unchanged",
  query_failed = "datastar.nvim: the HTML Tree-sitter query could not be created; update the HTML parser and datastar.nvim, then reload the buffer; host syntax was left unchanged",
  parse_failed = "datastar.nvim: the HTML Tree-sitter parser could not parse this buffer; reload the buffer after checking the parser installation; host syntax was left unchanged",
  refresh_failed = "datastar.nvim: Datastar highlighting failed unexpectedly; reload the buffer, update datastar.nvim, and report the failure if it persists; host syntax was left unchanged",
}

local function normalize_buffer(buf)
  if buf == nil or buf == 0 then
    buf = vim.api.nvim_get_current_buf()
  end
  if type(buf) ~= "number" or buf ~= buf or buf <= 0 or buf == math.huge or buf == -math.huge or buf % 1 ~= 0 then
    return nil
  end
  return buf
end

local function valid_loaded_buffer(buf)
  local valid_ok, valid = pcall(vim.api.nvim_buf_is_valid, buf)
  if not valid_ok or not valid then
    return false
  end
  local loaded_ok, loaded = pcall(vim.api.nvim_buf_is_loaded, buf)
  return loaded_ok and loaded
end

local function eligible(buf)
  if not valid_loaded_buffer(buf) then
    return false
  end
  local filetype = vim.bo[buf].filetype
  return filetype == "html" or filetype == "htmldjango"
end

local function warn_once(reason)
  local category = notice_messages[reason] and reason or "refresh_failed"
  if notices[category] then
    return
  end
  notices[category] = true
  pcall(vim.notify, notice_messages[category], vim.log.levels.WARN)
end

local function failed_refresh(error_message)
  pcall(renderer.clear, error_message.buf)
  warn_once("refresh_failed")
  return {
    error = error_message.message,
    extmark_count = 0,
    token_count = 0,
  }
end

function M.refresh(buf)
  buf = normalize_buffer(buf)
  if not buf or not valid_loaded_buffer(buf) then
    return { error = "invalid_buffer", extmark_count = 0, token_count = 0 }
  end
  if not eligible(buf) then
    renderer.clear(buf)
    return { error = "unsupported_filetype", extmark_count = 0, token_count = 0 }
  end

  local ok, result = xpcall(function()
    return renderer.refresh(buf)
  end, debug.traceback)
  if not ok then
    return failed_refresh({ buf = buf, message = result })
  end
  if type(result) ~= "table" then
    return failed_refresh({ buf = buf, message = "invalid_refresh_result" })
  end
  if result.error then
    warn_once(result.error)
  end
  return result
end

function M.attach(buf)
  buf = normalize_buffer(buf)
  if not buf or not eligible(buf) then
    return false
  end
  if attached[buf] then
    return true
  end

  -- Initialize the Tree-sitter parser before our buffer callback so its edit and
  -- reload callbacks invalidate the tree before our synchronous refresh runs.
  M.refresh(buf)

  local token = {}
  attachment_tokens[buf] = token
  local did_attach = vim.api.nvim_buf_attach(buf, false, {
    on_lines = function()
      if attachment_tokens[buf] ~= token then
        return true
      end
      M.refresh(buf)
      return false
    end,
    on_reload = function()
      if attachment_tokens[buf] ~= token then
        return true
      end
      M.refresh(buf)
      return false
    end,
    on_detach = function()
      if attachment_tokens[buf] == token then
        attachment_tokens[buf] = nil
        attached[buf] = nil
      end
      return true
    end,
  })

  if not did_attach then
    if attachment_tokens[buf] == token then
      attachment_tokens[buf] = nil
    end
    renderer.clear(buf)
    return false
  end

  attached[buf] = true
  return true
end

function M.detach(buf)
  buf = normalize_buffer(buf)
  if not buf or not valid_loaded_buffer(buf) then
    return false
  end

  local was_attached = attached[buf] == true
  attachment_tokens[buf] = nil
  attached[buf] = nil
  renderer.clear(buf)
  return was_attached
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
      attachment_tokens[args.buf] = nil
      attached[args.buf] = nil
    end,
  })

  setup_complete = true
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if eligible(buf) then
      M.attach(buf)
    elseif attached[buf] then
      M.detach(buf)
    end
  end
end

function M.namespace()
  return renderer.namespace()
end

function M._state()
  return {
    attached = vim.deepcopy(attached),
    setup_complete = setup_complete,
    warned_for_parser = notices.missing_parser == true or notices.query_failed == true,
    notices = vim.deepcopy(notices),
  }
end

return M
