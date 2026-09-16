local builtin_names = require("datastar.generated.attributes")

local M = {}

local active = {
  custom_attributes = {},
}

local builtin = {}
for _, name in ipairs(builtin_names) do
  builtin[name] = true
end

local function invalid(message)
  error("datastar.nvim setup: " .. message, 3)
end

local function valid_attribute_name(name)
  if name:sub(1, 5) == "data-" or not name:match("^[a-z][a-z0-9-]*$") then
    return false
  end
  if name:sub(-1) == "-" or name:find("--", 1, true) then
    return false
  end
  return true
end

local function validate_options(opts)
  if type(opts) ~= "table" then
    invalid("options must be a table or nil")
  end
  for key in pairs(opts) do
    if key ~= "custom_attributes" then
      invalid(("unknown option %q; only custom_attributes is supported"):format(tostring(key)))
    end
  end
end

local function validate_dense_array(values)
  if values == nil then
    return {}
  end
  if type(values) ~= "table" then
    invalid("custom_attributes must be a dense array of strings")
  end

  local count = 0
  local maximum = 0
  for key in pairs(values) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      invalid("custom_attributes must be a dense array of strings with integer keys starting at 1")
    end
    count = count + 1
    maximum = math.max(maximum, key)
  end
  if maximum ~= count then
    invalid("custom_attributes must be a dense array without holes")
  end

  local normalized = {}
  local seen = {}
  for index = 1, count do
    local name = values[index]
    if type(name) ~= "string" then
      invalid(("custom_attributes[%d] must be a string"):format(index))
    end
    if not valid_attribute_name(name) then
      invalid((
        "custom_attributes[%d] must match ^[a-z][a-z0-9]*(%%-[a-z0-9]+)*$ and omit the data- prefix"
      ):format(index))
    end
    if not builtin[name] and not seen[name] then
      seen[name] = true
      normalized[#normalized + 1] = name
    end
  end
  table.sort(normalized)
  return normalized
end

function M.normalize(opts)
  validate_options(opts)
  return {
    custom_attributes = validate_dense_array(opts.custom_attributes),
  }
end

function M.current()
  return vim.deepcopy(active)
end

function M.apply(configuration)
  active = vim.deepcopy(configuration)
end

return M
