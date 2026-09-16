local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

local operators = {
  "===", "!==", "&&", "||", "??", "==", "!=", ">=", "<=", "++", "--",
  "+=", "-=", "*=", "/=", "%=", "+", "-", "*", "/", "%", ">", "<", "!", "=", "?", ":",
}

local name_groups = {
  DatastarAttributePrefix = true,
  DatastarPlugin = true,
  DatastarKeySeparator = true,
  DatastarKey = true,
  DatastarModifierSeparator = true,
  DatastarModifier = true,
  DatastarModifierArgumentSeparator = true,
  DatastarModifierArgument = true,
}

local function expression_marks(buf)
  local marks = {}
  for _, mark in ipairs(h.marks_with_text(buf)) do
    if not name_groups[mark.group] then
      marks[#marks + 1] = mark.group .. "|" .. mark.text
    end
  end
  return marks
end

return function()
  local datastar = require("datastar")
  datastar.setup()

  local operator_lines = {}
  for _, operator in ipairs(operators) do
    operator_lines[#operator_lines + 1] = ('<div data-show="$left %s $right"></div>'):format(operator)
  end
  local operator_buf = h.new_buffer(table.concat(operator_lines, "\n"), "html")
  local operator_result = datastar.refresh(operator_buf)
  h.assert_equal(nil, operator_result.error, "operator contract refresh")

  local rendered_operators = {}
  for _, mark in ipairs(h.marks_with_text(operator_buf)) do
    if mark.group == "DatastarOperator" then
      rendered_operators[#rendered_operators + 1] = mark.text
    end
  end
  h.assert_equal(operators, rendered_operators, "the public renderer supports the complete published operator set with maximal boundaries")

  local boundary_expression = "{key: [call_name(1), object_name.run_method($signal), trueValue, false, nullValue, null]}; @get(); @idle; $$store; $9"
  local boundary_buf = h.new_buffer('<div data-show="' .. boundary_expression .. '"></div>', "html")
  local boundary_result = datastar.refresh(boundary_buf)
  h.assert_equal(nil, boundary_result.error, "punctuation and identifier boundary refresh")
  h.assert_equal({
    "DatastarPunctuation|{",
    "DatastarObjectKey|key",
    "DatastarOperator|:",
    "DatastarPunctuation|[",
    "DatastarFunctionCall|call_name",
    "DatastarCallPunctuation|(",
    "DatastarNumber|1",
    "DatastarCallPunctuation|)",
    "DatastarPunctuation|,",
    "DatastarAccessor|.",
    "DatastarMethodCall|run_method",
    "DatastarCallPunctuation|(",
    "DatastarSignal|$signal",
    "DatastarCallPunctuation|)",
    "DatastarPunctuation|,",
    "DatastarPunctuation|,",
    "DatastarBoolean|false",
    "DatastarPunctuation|,",
    "DatastarPunctuation|,",
    "DatastarNull|null",
    "DatastarPunctuation|]",
    "DatastarPunctuation|}",
    "DatastarPunctuation|;",
    "DatastarAction|@get",
    "DatastarCallPunctuation|(",
    "DatastarCallPunctuation|)",
    "DatastarPunctuation|;",
    "DatastarPunctuation|;",
    "DatastarSignal|$$store",
    "DatastarPunctuation|;",
  }, expression_marks(boundary_buf), "punctuation and identifier-like tokens stop at the published lexical boundaries")
end
