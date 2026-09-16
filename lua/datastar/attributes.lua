local builtin_names = require("datastar.generated.attributes")

local M = {}

local names = vim.deepcopy(builtin_names)
table.sort(names, function(left, right)
  return #left > #right
end)

local function add(parts, role, start_col, end_col)
  parts[#parts + 1] = {
    role = role,
    start_offset = start_col,
    end_offset = end_col,
  }
end

local function match_plugin(attribute_name)
  if attribute_name:sub(1, 5) ~= "data-" then
    return nil
  end

  for _, name in ipairs(names) do
    local finish = 5 + #name
    if attribute_name:sub(6, finish) == name then
      local following = attribute_name:sub(finish + 1, finish + 2)
      if following == "" or following:sub(1, 1) == ":" or following == "__" then
        return name, finish
      end
    end
  end
end

local function key_end(attribute_name, start_at)
  local suffix = attribute_name:sub(start_at)
  local delimiter = suffix:find("__", 1, true) or suffix:find(":", 1, true)
  local key = delimiter and suffix:sub(1, delimiter - 1) or suffix
  if not key:match("^[a-z_][a-z0-9_.-]*$") or key:sub(-1) == "." or key:find("..", 1, true) then
    return nil
  end
  for segment in key:gmatch("[^.]+") do
    if not segment:match("^[a-z_][a-z0-9_-]*$") then
      return nil
    end
  end
  return start_at + #key - 1
end

local function modifier_end(attribute_name, start_at)
  local modifier = attribute_name:sub(start_at):match("^([a-z][a-z0-9-]*)")
  return modifier and start_at + #modifier - 1 or nil
end

local function argument_end(attribute_name, start_at)
  local argument = attribute_name:sub(start_at):match("^([a-z0-9]+)")
  return argument and start_at + #argument - 1 or nil
end

function M.segment(attribute_name)
  local plugin, plugin_end = match_plugin(attribute_name)
  if not plugin then
    return nil
  end

  local parts = {}
  add(parts, "attribute_prefix", 0, 5)
  add(parts, "plugin", 5, plugin_end)

  local position = plugin_end + 1
  while position <= #attribute_name do
    if attribute_name:sub(position, position) == ":" then
      local finish = key_end(attribute_name, position + 1)
      if not finish then
        break
      end
      add(parts, "key_separator", position - 1, position)
      add(parts, "key", position, finish)
      position = finish + 1
    elseif attribute_name:sub(position, position + 1) == "__" then
      local finish = modifier_end(attribute_name, position + 2)
      if not finish then
        break
      end
      add(parts, "modifier_separator", position - 1, position + 1)
      add(parts, "modifier", position + 1, finish)
      position = finish + 1
      if attribute_name:sub(position, position) == "." then
        local argument_finish = argument_end(attribute_name, position + 1)
        if not argument_finish then
          break
        end
        add(parts, "modifier_argument_separator", position - 1, position)
        add(parts, "modifier_argument", position, argument_finish)
        position = argument_finish + 1
      end
    else
      break
    end
  end

  return {
    plugin = plugin,
    parts = parts,
    complete = position > #attribute_name,
  }
end

function M.names()
  return vim.deepcopy(builtin_names)
end

return M
