local M = {}

local operators = {
  "===",
  "!==",
  "&&",
  "||",
  "??",
  "==",
  "!=",
  ">=",
  "<=",
  "++",
  "--",
  "+=",
  "-=",
  "*=",
  "/=",
  "%=",
  "+",
  "-",
  "*",
  "/",
  "%",
  ">",
  "<",
  "!",
  "=",
  "?",
  ":",
}

local literal_roles = {
  ["true"] = "boolean",
  ["false"] = "boolean",
  ["null"] = "null",
}

local function add(tokens, role, start_index, end_index)
  if end_index > start_index then
    tokens[#tokens + 1] = {
      role = role,
      start_offset = start_index,
      end_offset = end_index,
    }
  end
end

local function hole_end(source, position)
  local opener = source:sub(position, position + 1)
  local closer = opener == "{%" and "%}" or opener == "{{" and "}}" or nil
  if not closer then
    return nil, false
  end

  local close_start = source:find(closer, position + 2, true)
  return close_start and close_start + 2 or nil, true
end

local function parse_string(source, position)
  local quote = source:sub(position, position)
  local segments = {}
  local escapes = {}
  local segment_start = position
  local cursor = position + 1

  while cursor <= #source do
    local after_hole, is_hole = hole_end(source, cursor)
    if is_hole then
      add(segments, "string", segment_start - 1, cursor - 1)
      if not after_hole then
        return segments, escapes, #source + 1, false
      end
      cursor = after_hole
      segment_start = cursor
    elseif source:sub(cursor, cursor) == "\\" then
      if cursor == #source then
        return {}, {}, #source + 1, false
      end
      add(escapes, "escape", cursor - 1, cursor + 1)
      cursor = cursor + 2
    elseif source:sub(cursor, cursor) == quote then
      add(segments, "string", segment_start - 1, cursor)
      return segments, escapes, cursor + 1, true
    else
      cursor = cursor + 1
    end
  end

  return {}, {}, #source + 1, false
end

local function opaque_template_end(source, position)
  local cursor = position + 1
  while cursor <= #source do
    local after_hole, is_hole = hole_end(source, cursor)
    if is_hole then
      if not after_hole then
        return #source + 1, false
      end
      cursor = after_hole
    elseif source:sub(cursor, cursor) == "\\" then
      cursor = cursor + 2
    elseif source:sub(cursor, cursor) == "`" then
      return cursor + 1, true
    else
      cursor = cursor + 1
    end
  end
  return #source + 1, false
end

local function append_all(target, source)
  for _, item in ipairs(source) do
    target[#target + 1] = item
  end
end

local function identifier_end(source, position)
  local identifier = source:sub(position):match("^([A-Za-z_][A-Za-z0-9_]*)")
  return identifier and position + #identifier - 1 or nil
end

local function next_non_space(source, position)
  local cursor = position
  while source:sub(cursor, cursor):match("%s") do
    cursor = cursor + 1
  end
  return source:sub(cursor, cursor), cursor
end

local function previous_non_space(source, position)
  local cursor = position
  while cursor >= 1 and source:sub(cursor, cursor):match("%s") do
    cursor = cursor - 1
  end
  return source:sub(cursor, cursor), cursor
end

local function signal_end(source, position)
  local cursor = position
  if source:sub(cursor, cursor) ~= "$" then
    return nil
  end
  cursor = cursor + 1
  if source:sub(cursor, cursor) == "$" then
    cursor = cursor + 1
  end
  if not source:sub(cursor, cursor):match("[A-Za-z_]") then
    return nil
  end
  cursor = cursor + 1
  while source:sub(cursor, cursor):match("[A-Za-z0-9_]") do
    cursor = cursor + 1
  end
  return cursor - 1
end

local function invalid_signal_end(source, position)
  if source:sub(position, position) ~= "$" then
    return nil
  end
  local cursor = position + 1
  if source:sub(cursor, cursor) == "$" then
    cursor = cursor + 1
  end
  while source:sub(cursor, cursor):match("[A-Za-z0-9_]") do
    cursor = cursor + 1
  end
  return cursor - 1
end

local function action_end(source, position)
  if source:sub(position, position) ~= "@" then
    return nil
  end
  local name = source:sub(position + 1):match("^([A-Za-z][A-Za-z0-9_]*)")
  return name and position + #name or nil
end

local function number_end(source, position)
  local integer = source:sub(position):match("^(%d+)")
  if not integer then
    return nil
  end
  local finish = position + #integer - 1
  if source:sub(finish + 1, finish + 1) == "." and source:sub(finish + 2, finish + 2):match("%d") then
    local fraction = source:sub(finish + 2):match("^(%d+)")
    finish = finish + 1 + #fraction
  end
  return finish
end

local function matching_operator(source, position)
  for _, operator in ipairs(operators) do
    if source:sub(position, position + #operator - 1) == operator then
      return operator
    end
  end
end

function M.tokenize(source)
  local tokens = {}
  local position = 1

  while position <= #source do
    local character = source:sub(position, position)
    local after_hole, is_hole = hole_end(source, position)
    if is_hole then
      if not after_hole then
        break
      end
      position = after_hole
    elseif character:match("%s") then
      position = position + 1
    elseif character == "'" or character == '"' then
      local segments, escapes, next_position, complete = parse_string(source, position)
      append_all(tokens, segments)
      append_all(tokens, escapes)
      position = next_position
      if not complete then
        break
      end
    elseif character == "`" then
      local next_position, complete = opaque_template_end(source, position)
      position = next_position
      if not complete then
        break
      end
    elseif source:sub(position, position + 1) == "=>" then
      position = position + 2
    elseif source:sub(position, position + 2) == "..." then
      position = position + 3
    else
      local finish = signal_end(source, position)
      if finish then
        add(tokens, "signal", position - 1, finish)
        position = finish + 1
      elseif character == "$" then
        position = invalid_signal_end(source, position) + 1
      else
        finish = action_end(source, position)
        if finish then
          local next_character = next_non_space(source, finish + 1)
          if next_character == "(" then
            add(tokens, "action", position - 1, finish)
          end
          position = finish + 1
        else
          finish = identifier_end(source, position)
          if finish then
            local text = source:sub(position, finish)
            local next_character = next_non_space(source, finish + 1)
            local previous_character = previous_non_space(source, position - 1)
            local role = literal_roles[text]
            if role then
              add(tokens, role, position - 1, finish)
            elseif next_character == ":" and (previous_character == "{" or previous_character == ",") then
              add(tokens, "object_key", position - 1, finish)
            elseif next_character == "(" and previous_character == "." then
              add(tokens, "method", position - 1, finish)
            elseif next_character == "(" then
              add(tokens, "function_call", position - 1, finish)
            end
            position = finish + 1
          else
            finish = number_end(source, position)
            if finish then
              add(tokens, "number", position - 1, finish)
              position = finish + 1
            elseif character == "." and source:sub(position + 1, position + 1):match("[A-Za-z_]") then
              add(tokens, "accessor", position - 1, position)
              position = position + 1
            elseif character:match("[{}%[%],;]") then
              add(tokens, "punctuation", position - 1, position)
              position = position + 1
            elseif character == "(" or character == ")" then
              add(tokens, "call_punctuation", position - 1, position)
              position = position + 1
            else
              local operator = matching_operator(source, position)
              if operator then
                add(tokens, "operator", position - 1, position + #operator - 1)
                position = position + #operator
              else
                position = position + 1
              end
            end
          end
        end
      end
    end
  end

  return tokens
end

return M
