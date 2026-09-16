local M = {}

M.groups = {
  DatastarAttributePrefix = "Operator",
  DatastarPlugin = "Function",
  DatastarKeySeparator = "Delimiter",
  DatastarKey = "Identifier",
  DatastarModifierSeparator = "Delimiter",
  DatastarModifier = "Keyword",
  DatastarModifierArgumentSeparator = "Delimiter",
  DatastarModifierArgument = "Number",
  DatastarSignal = "Identifier",
  DatastarAction = "Function",
  DatastarFunctionCall = "Function",
  DatastarMethodCall = "Function",
  DatastarString = "String",
  DatastarEscape = "SpecialChar",
  DatastarNumber = "Number",
  DatastarBoolean = "Boolean",
  DatastarNull = "Constant",
  DatastarOperator = "Operator",
  DatastarPunctuation = "Delimiter",
  DatastarObjectKey = "Identifier",
  DatastarAccessor = "Delimiter",
  DatastarCallPunctuation = "Delimiter",
}

function M.define()
  for group, target in pairs(M.groups) do
    vim.api.nvim_set_hl(0, group, { default = true, link = target })
  end
end

return M
