local attributes = require("datastar.attributes")

local M = {}

local attribute_query

local function get_attribute_query()
  if attribute_query then
    return attribute_query
  end
  local ok, query = pcall(vim.treesitter.query.parse, "html", "(attribute) @attribute")
  if not ok then
    return nil
  end
  attribute_query = query
  return query
end

local function node_text(buf, node)
  local start_row, start_col, end_row, end_col = node:range()
  return table.concat(vim.api.nvim_buf_get_text(buf, start_row, start_col, end_row, end_col, {}), "\n")
end

local function direct_named_child(node, wanted_type)
  for index = 0, node:named_child_count() - 1 do
    local child = node:named_child(index)
    if child:type() == wanted_type then
      return child
    end
  end
end

local function build_position_mapper(source, start_row, start_col)
  local line_starts = { 0 }
  for index = 1, #source do
    if source:byte(index) == 10 then
      line_starts[#line_starts + 1] = index
    end
  end

  return function(offset)
    local low = 1
    local high = #line_starts
    while low <= high do
      local middle = math.floor((low + high) / 2)
      if line_starts[middle] <= offset then
        low = middle + 1
      else
        high = middle - 1
      end
    end

    local line_index = high
    local row = start_row + line_index - 1
    local column = offset - line_starts[line_index]
    if line_index == 1 then
      column = column + start_col
    end
    return row, column
  end
end

local function value_from_attribute(buf, attribute_node)
  local quoted = direct_named_child(attribute_node, "quoted_attribute_value")
  if not quoted then
    return nil
  end

  local value = direct_named_child(quoted, "attribute_value")
  if not value then
    return nil
  end

  local start_row, start_col, end_row, end_col = value:range()
  local source = node_text(buf, value)
  return {
    source = source,
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
    position = build_position_mapper(source, start_row, start_col),
  }
end

function M.discover(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "html")
  if not ok or not parser then
    return nil, "missing_parser"
  end

  local query = get_attribute_query()
  if not query then
    return nil, "query_failed"
  end

  local parsed, trees = pcall(function()
    return parser:parse(true)
  end)
  if not parsed or not trees or not trees[1] then
    return nil, "parse_failed"
  end

  local root = trees[1]:root()
  local candidates = {}
  local stats = {
    attributes_examined = 0,
    recognized_attributes = 0,
    value_bytes_examined = 0,
  }

  for capture_id, node in query:iter_captures(root, buf, 0, -1) do
    if query.captures[capture_id] == "attribute" then
      stats.attributes_examined = stats.attributes_examined + 1
      local name_node = direct_named_child(node, "attribute_name")
      if name_node then
        local name = node_text(buf, name_node)
        local segmentation = attributes.segment(name)
        if segmentation then
          local start_row, start_col, end_row, end_col = name_node:range()
          local value = segmentation.complete and value_from_attribute(buf, node) or nil
          candidates[#candidates + 1] = {
            name = name,
            name_start_row = start_row,
            name_start_col = start_col,
            name_end_row = end_row,
            name_end_col = end_col,
            segmentation = segmentation,
            value = value,
          }
          stats.recognized_attributes = stats.recognized_attributes + 1
          stats.value_bytes_examined = stats.value_bytes_examined + (value and #value.source or 0)
        end
      end
    end
  end

  return candidates, nil, stats
end

return M
