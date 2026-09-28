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

local function node_text(source, node)
  if type(source) == "string" then
    return vim.treesitter.get_node_text(node, source)
  end
  local start_row, start_col, end_row, end_col = node:range()
  return table.concat(vim.api.nvim_buf_get_text(source, start_row, start_col, end_row, end_col, {}), "\n")
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

local function before(row, col, other_row, other_col)
  return row < other_row or (row == other_row and col < other_col)
end

local function holes_overlap(holes, sr, sc, er, ec)
  for _, hole in ipairs(holes) do
    if before(sr, sc, hole.end_row, hole.end_col) and before(hole.start_row, hole.start_col, er, ec) then
      return true
    end
  end
  return false
end

local function value_from_attribute(source, attribute_node, map_position, holes)
  local quoted = direct_named_child(attribute_node, "quoted_attribute_value")
  if not quoted then
    return nil
  end

  local value = direct_named_child(quoted, "attribute_value")
  if not value then
    return nil
  end

  local start_row, start_col, end_row, end_col = value:range()
  if holes and holes_overlap(holes, start_row, start_col, end_row, end_col) then
    return nil
  end
  local text = node_text(source, value)
  local local_position = build_position_mapper(text, start_row, start_col)
  return {
    source = text,
    position = map_position and function(offset)
      return map_position(local_position(offset))
    end or local_position,
  }
end

local function new_stats()
  return { attributes_examined = 0, recognized_attributes = 0, value_bytes_examined = 0 }
end

local function collect_attributes(root, source, query, candidates, stats, map_position, holes)
  for capture_id, node in query:iter_captures(root, source, 0, -1) do
    if query.captures[capture_id] == "attribute" then
      stats.attributes_examined = stats.attributes_examined + 1
      local name_node = direct_named_child(node, "attribute_name")
      if name_node then
        local name = node_text(source, name_node)
        local segmentation = attributes.segment(name)
        local sr, sc, er, ec = name_node:range()
        if segmentation and (not holes or not holes_overlap(holes, sr, sc, er, ec)) then
          local value = segmentation.complete and value_from_attribute(source, node, map_position, holes) or nil
          if map_position then
            sr, sc = map_position(sr, sc)
            er, ec = map_position(er, ec)
          end
          candidates[#candidates + 1] = {
            name = name,
            name_start_row = sr,
            name_start_col = sc,
            name_end_row = er,
            name_end_col = ec,
            segmentation = segmentation,
            value = value,
          }
          stats.recognized_attributes = stats.recognized_attributes + 1
          stats.value_bytes_examined = stats.value_bytes_examined + (value and #value.source or 0)
        end
      end
    end
  end
end

local function parse_html(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "html")
  if not ok or not parser then
    return nil, "missing_parser"
  end
  local query = get_attribute_query()
  if not query then
    return nil, "query_failed"
  end
  local parsed, trees = pcall(function() return parser:parse(true) end)
  if not parsed or not trees or not trees[1] then
    return nil, "parse_failed"
  end
  local candidates, stats = {}, new_stats()
  collect_attributes(trees[1]:root(), buf, query, candidates, stats)
  return candidates, nil, stats
end

local function visit_tagged_templates(node, buf, visit)
  if node:type() == "call_expression" then
    local tag = node:field("function")[1]
    local template = node:field("arguments")[1]
    if tag and tag:type() == "identifier" and node_text(buf, tag) == "html"
        and template and template:type() == "template_string" then
      visit(template)
    end
  end
  for index = 0, node:named_child_count() - 1 do
    visit_tagged_templates(node:named_child(index), buf, visit)
  end
end

local function template_source(buf, template)
  local sr, sc = template:range()
  local raw = node_text(buf, template)
  if template:has_error() or raw:sub(1, 1) ~= "`" or raw:sub(-1) ~= "`" then
    return nil
  end
  local source = raw:sub(2, -2)
  local absolute_start = vim.api.nvim_buf_get_offset(buf, sr) + sc + 1
  local holes = {}
  for index = 0, template:named_child_count() - 1 do
    local child = template:named_child(index)
    if child:type() == "template_substitution" then
      local hr, hc, fr, fc = child:range()
      local first = vim.api.nvim_buf_get_offset(buf, hr) + hc - absolute_start
      local last = vim.api.nvim_buf_get_offset(buf, fr) + fc - absolute_start
      holes[#holes + 1] = { first, last }
    end
  end
  local masked = source
  local local_position = build_position_mapper(source, 0, 0)
  local ranges = {}
  for _, hole in ipairs(holes) do
    local segment = source:sub(hole[1] + 1, hole[2])
    masked = masked:sub(1, hole[1]) .. segment:gsub("[^\n]", " ") .. masked:sub(hole[2] + 1)
    local start_row, start_col = local_position(hole[1])
    local end_row, end_col = local_position(hole[2])
    ranges[#ranges + 1] = { start_row = start_row, start_col = start_col, end_row = end_row, end_col = end_col }
  end
  local function buffer_position(row, col)
    return sr + row, row == 0 and sc + 1 + col or col
  end
  return masked, ranges, buffer_position
end

local function parse_javascript(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "javascript")
  if not ok or not parser then
    return nil, "missing_javascript_parser"
  end
  local parsed, trees = pcall(function() return parser:parse(true) end)
  if not parsed or not trees or not trees[1] then
    return nil, "javascript_parse_failed"
  end
  local candidates, stats = {}, new_stats()
  local failure
  visit_tagged_templates(trees[1]:root(), buf, function(template)
    if failure then return end
    local source, holes, map_position = template_source(buf, template)
    if not source then return end
    local html_ok, html_parser = pcall(vim.treesitter.get_string_parser, source, "html")
    if not html_ok or not html_parser then
      failure = "missing_parser"
      return
    end
    local query = get_attribute_query()
    if not query then
      failure = "query_failed"
      return
    end
    local html_parsed, html_trees = pcall(function() return html_parser:parse() end)
    if not html_parsed or not html_trees or not html_trees[1] then
      failure = "parse_failed"
      return
    end
    collect_attributes(html_trees[1]:root(), source, query, candidates, stats, map_position, holes)
  end)
  if failure then return nil, failure end
  return candidates, nil, stats
end

function M.discover(buf)
  if vim.bo[buf].filetype == "javascript" then
    return parse_javascript(buf)
  end
  return parse_html(buf)
end

return M
