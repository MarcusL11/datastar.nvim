local M = {}

local root = assert(vim.env.DATASTAR_ROOT)

local function format(value)
  return vim.inspect(value)
end

function M.fail(message)
  error(message, 2)
end

function M.assert_equal(expected, actual, context)
  if not vim.deep_equal(expected, actual) then
    error(("%s\nexpected: %s\nactual:   %s"):format(context or "values differ", format(expected), format(actual)), 2)
  end
end

function M.assert_true(value, context)
  if not value then
    error(context or "expected truthy value", 2)
  end
end

function M.assert_match(value, pattern, context)
  if not tostring(value):match(pattern) then
    error(("%s\nvalue: %s\npattern: %s"):format(context or "pattern did not match", value, pattern), 2)
  end
end

function M.read_fixture(name)
  local file = assert(io.open(root .. "/tests/fixtures/" .. name, "rb"))
  local contents = file:read("*a")
  file:close()
  return contents
end

function M.lines(text)
  text = text:gsub("\n$", "")
  return vim.split(text, "\n", { plain = true })
end

function M.new_buffer(text, filetype, options)
  options = options or {}
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, M.lines(text))
  vim.api.nvim_set_current_buf(buf)
  if options.syntax then
    vim.bo[buf].syntax = options.syntax
  end
  vim.bo[buf].filetype = filetype
  return buf
end

function M.extmarks(buf)
  local namespace = require("datastar").namespace()
  local raw = vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, {
    details = true,
    type = "highlight",
  })
  local normalized = {}
  for _, mark in ipairs(raw) do
    local details = mark[4]
    normalized[#normalized + 1] = {
      row = mark[2],
      col = mark[3],
      end_row = details.end_row,
      end_col = details.end_col,
      group = details.hl_group,
      priority = details.priority,
    }
  end
  table.sort(normalized, function(left, right)
    if left.row ~= right.row then
      return left.row < right.row
    end
    if left.col ~= right.col then
      return left.col < right.col
    end
    if left.end_row ~= right.end_row then
      return left.end_row < right.end_row
    end
    if left.end_col ~= right.end_col then
      return left.end_col < right.end_col
    end
    return left.group < right.group
  end)
  return normalized
end

function M.mark_text(buf, mark)
  return table.concat(vim.api.nvim_buf_get_text(buf, mark.row, mark.col, mark.end_row, mark.end_col, {}), "\n")
end

function M.marks_with_text(buf)
  local results = {}
  for _, mark in ipairs(M.extmarks(buf)) do
    results[#results + 1] = {
      text = M.mark_text(buf, mark),
      row = mark.row,
      col = mark.col,
      end_row = mark.end_row,
      end_col = mark.end_col,
      group = mark.group,
      priority = mark.priority,
    }
  end
  return results
end

function M.find_all(text, needle)
  local ranges = {}
  local position = 1
  while true do
    local start_at, end_at = text:find(needle, position, true)
    if not start_at then
      return ranges
    end
    ranges[#ranges + 1] = { start_at - 1, end_at }
    position = end_at + 1
  end
end

function M.direct_syntax_group(row, column)
  local id = vim.fn.synID(row + 1, column + 1, true)
  return vim.fn.synIDattr(id, "name")
end

function M.runtime_parser_paths()
  local paths = vim.api.nvim_get_runtime_file("parser/html.*", true)
  table.sort(paths)
  return paths
end

function M.with_patch(target, key, replacement, callback)
  local original = target[key]
  target[key] = replacement
  local ok, result = xpcall(callback, debug.traceback)
  target[key] = original
  if not ok then
    error(result, 0)
  end
  return result
end

function M.autocmd_topology(group)
  local topology = {}
  for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ group = group })) do
    local key = autocmd.event .. ":" .. autocmd.pattern
    topology[key] = (topology[key] or 0) + 1
  end
  return topology
end

return M
