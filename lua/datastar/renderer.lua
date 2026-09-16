local parser = require("datastar.parser")
local tokenizer = require("datastar.tokenizer")

local M = {}

M.priority = 110

local namespace = vim.api.nvim_create_namespace("datastar.nvim")
local warning_handler

local name_groups = {
  attribute_prefix = "DatastarAttributePrefix",
  plugin = "DatastarPlugin",
  key_separator = "DatastarKeySeparator",
  key = "DatastarKey",
  modifier_separator = "DatastarModifierSeparator",
  modifier = "DatastarModifier",
  modifier_argument_separator = "DatastarModifierArgumentSeparator",
  modifier_argument = "DatastarModifierArgument",
}

local expression_groups = {
  signal = "DatastarSignal",
  action = "DatastarAction",
  function_call = "DatastarFunctionCall",
  method = "DatastarMethodCall",
  string = "DatastarString",
  escape = "DatastarEscape",
  number = "DatastarNumber",
  boolean = "DatastarBoolean",
  null = "DatastarNull",
  operator = "DatastarOperator",
  punctuation = "DatastarPunctuation",
  object_key = "DatastarObjectKey",
  accessor = "DatastarAccessor",
  call_punctuation = "DatastarCallPunctuation",
}

local function valid_range(line_lengths, start_row, start_col, end_row, end_col)
  if start_row < 0 or end_row < start_row or end_row >= #line_lengths then
    return false
  end
  if start_col < 0 or end_col < 0 then
    return false
  end
  if start_col > line_lengths[start_row + 1] or end_col > line_lengths[end_row + 1] then
    return false
  end
  return start_row < end_row or start_col < end_col
end

local function set_mark(buf, line_lengths, group, start_row, start_col, end_row, end_col)
  if not group or not valid_range(line_lengths, start_row, start_col, end_row, end_col) then
    return false
  end

  vim.api.nvim_buf_set_extmark(buf, namespace, start_row, start_col, {
    end_row = end_row,
    end_col = end_col,
    hl_group = group,
    priority = M.priority,
  })
  return true
end

local function render_name(buf, line_lengths, candidate)
  local count = 0
  for _, part in ipairs(candidate.segmentation.parts) do
    if set_mark(
      buf,
      line_lengths,
      name_groups[part.role],
      candidate.name_start_row,
      candidate.name_start_col + part.start_offset,
      candidate.name_start_row,
      candidate.name_start_col + part.end_offset
    ) then
      count = count + 1
    end
  end
  return count
end

local function render_value(buf, line_lengths, value)
  if not value then
    return 0, 0
  end

  local count = 0
  local tokens = tokenizer.tokenize(value.source)
  for _, token in ipairs(tokens) do
    local start_row, start_col = value.position(token.start_offset)
    local end_row, end_col = value.position(token.end_offset)
    if set_mark(buf, line_lengths, expression_groups[token.role], start_row, start_col, end_row, end_col) then
      count = count + 1
    end
  end
  return count, #tokens
end

local function refresh_impl(buf)
  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)

  local candidates, parse_error, stats = parser.discover(buf)
  if not candidates then
    if warning_handler then
      warning_handler(parse_error)
    end
    return {
      error = parse_error,
      extmark_count = 0,
      token_count = 0,
      stats = stats,
    }
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
  local line_lengths = {}
  for index, line in ipairs(lines) do
    line_lengths[index] = #line
  end

  local extmark_count = 0
  local token_count = 0
  for _, candidate in ipairs(candidates) do
    extmark_count = extmark_count + render_name(buf, line_lengths, candidate)
    local rendered, tokens = render_value(buf, line_lengths, candidate.value)
    extmark_count = extmark_count + rendered
    token_count = token_count + tokens
  end

  return {
    error = nil,
    extmark_count = extmark_count,
    token_count = token_count,
    stats = stats,
  }
end

function M.refresh(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
    return { error = "invalid_buffer", extmark_count = 0, token_count = 0 }
  end

  local ok, result = xpcall(function()
    return refresh_impl(buf)
  end, debug.traceback)
  if ok then
    return result
  end

  pcall(vim.api.nvim_buf_clear_namespace, buf, namespace, 0, -1)
  return {
    error = result,
    extmark_count = 0,
    token_count = 0,
  }
end

function M.clear(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_clear_namespace, buf, namespace, 0, -1)
  end
end

function M.namespace()
  return namespace
end

function M.set_warning_handler(handler)
  warning_handler = handler
end

return M
