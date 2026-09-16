local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

local function semantic_text(buf)
  return vim.tbl_map(function(mark)
    return mark.group .. "|" .. h.mark_text(buf, mark)
  end, h.extmarks(buf))
end

local function assert_contains(items, item, context)
  h.assert_true(vim.tbl_contains(items, item), context .. ": " .. item)
end

return function()
  vim.cmd("runtime plugin/datastar.lua")
  local datastar = require("datastar")

  local source = [[<div data-my-plugin:item__debounce.500="$signal && @get('/x')" data-custom-action="$other" data-unknown="$ignored" data-show="$built_in"></div>]]
  local buf = h.new_buffer(source, "html")
  h.assert_true(not vim.tbl_contains(semantic_text(buf), "DatastarPlugin|my-plugin"), "unknown custom names are negative controls")
  h.assert_true(not vim.tbl_contains(semantic_text(buf), "DatastarSignal|$ignored"), "unknown data-* values never activate tokenization")

  local caller_options = {
    custom_attributes = { "my-plugin", "custom-action", "my-plugin", "show" },
  }
  local topology = h.autocmd_topology("datastar.nvim")
  datastar.setup(caller_options)
  h.assert_equal({ "custom-action", "my-plugin" }, datastar._state().config.custom_attributes, "duplicates and built-in collisions are normalized")
  h.assert_equal(topology, h.autocmd_topology("datastar.nvim"), "configuration changes do not duplicate autocmds")

  local rendered = semantic_text(buf)
  for _, expected in ipairs({
    "DatastarPlugin|my-plugin",
    "DatastarKeySeparator|:",
    "DatastarKey|item",
    "DatastarModifierSeparator|__",
    "DatastarModifier|debounce",
    "DatastarModifierArgumentSeparator|.",
    "DatastarModifierArgument|500",
    "DatastarSignal|$signal",
    "DatastarAction|@get",
    "DatastarPlugin|custom-action",
    "DatastarSignal|$other",
    "DatastarPlugin|show",
    "DatastarSignal|$built_in",
  }) do
    assert_contains(rendered, expected, "custom attributes receive built-in-equivalent segmentation and tokenization")
  end
  h.assert_true(not vim.tbl_contains(rendered, "DatastarSignal|$ignored"), "configured custom names do not broaden unknown data-* matching")

  caller_options.custom_attributes[1] = "mutated-later"
  caller_options.custom_attributes[5] = "also-later"
  datastar.setup()
  h.assert_equal({ "custom-action", "my-plugin" }, datastar._state().config.custom_attributes, "setup() preserves a defensive copy of current configuration")
  h.assert_true(vim.tbl_contains(semantic_text(buf), "DatastarPlugin|my-plugin"), "caller mutation has no effect")

  local effective = require("datastar.attributes").effective_names()
  local counts = {}
  for _, name in ipairs(effective) do
    counts[name] = (counts[name] or 0) + 1
  end
  h.assert_equal(1, counts.show, "built-in collision appears once in the effective inventory")
  h.assert_equal(1, counts["my-plugin"], "duplicate custom name appears once in the effective inventory")
  local my_position
  local my_plugin_position
  for index, name in ipairs(effective) do
    if name == "my" then
      my_position = index
    elseif name == "my-plugin" then
      my_plugin_position = index
    end
  end

  datastar.setup({ custom_attributes = { "my", "my-plugin" } })
  effective = require("datastar.attributes").effective_names()
  for index, name in ipairs(effective) do
    if name == "my" then
      my_position = index
    elseif name == "my-plugin" then
      my_plugin_position = index
    end
  end
  h.assert_true(my_plugin_position < my_position, "effective matching order is longest-name-safe")
  h.assert_true(vim.tbl_contains(semantic_text(buf), "DatastarPlugin|my-plugin"), "longest custom plugin is selected")

  local stable_config = datastar._state().config
  local stable_marks = h.extmarks(buf)
  local stable_topology = h.autocmd_topology("datastar.nvim")
  local invalid_options = {
    { value = false, message = "options must be a table" },
    { value = { filetypes = { "html" } }, message = "unknown option" },
    { value = { custom_attributes = "my-plugin" }, message = "dense array" },
    { value = { custom_attributes = { [1] = "my-plugin", [3] = "gap" } }, message = "without holes" },
    { value = { custom_attributes = { named = "my-plugin" } }, message = "integer keys" },
    { value = { custom_attributes = { "my-plugin", 7 } }, message = "must be a string" },
    { value = { custom_attributes = { "" } }, message = "must match" },
    { value = { custom_attributes = { "data-my-plugin" } }, message = "must match" },
    { value = { custom_attributes = { "MyPlugin" } }, message = "must match" },
    { value = { custom_attributes = { "-leading" } }, message = "must match" },
    { value = { custom_attributes = { "trailing-" } }, message = "must match" },
    { value = { custom_attributes = { "double--hyphen" } }, message = "must match" },
    { value = { custom_attributes = { "under_score" } }, message = "must match" },
  }
  for _, case in ipairs(invalid_options) do
    local ok, error_message = pcall(datastar.setup, case.value)
    h.assert_equal(false, ok, "malformed setup must raise")
    h.assert_match(error_message, "datastar%.nvim setup:", "configuration errors are actionable")
    h.assert_match(error_message, case.message, "configuration error identifies the malformed input")
    h.assert_equal(stable_config, datastar._state().config, "invalid setup leaves the active configuration unchanged")
    h.assert_equal(stable_marks, h.extmarks(buf), "invalid setup leaves existing marks unchanged")
    h.assert_equal(stable_topology, h.autocmd_topology("datastar.nvim"), "invalid setup leaves autocmd topology unchanged")
    h.assert_equal(true, datastar._state().attached[buf], "invalid setup leaves attachments unchanged")
  end

  local replacement_source = [[<div data-my="$old" data-replacement="$new" data-unknown="$ignored"></div>]]
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, { replacement_source })
  h.assert_true(vim.tbl_contains(semantic_text(buf), "DatastarPlugin|my"), "old configuration is active before replacement")
  datastar.setup({ custom_attributes = { "replacement" } })
  rendered = semantic_text(buf)
  h.assert_true(not vim.tbl_contains(rendered, "DatastarPlugin|my"), "replacement removes old custom-name marks")
  assert_contains(rendered, "DatastarPlugin|replacement", "replacement recognizes only the new custom name")
  assert_contains(rendered, "DatastarSignal|$new", "replacement custom value is tokenized")
  h.assert_true(not vim.tbl_contains(rendered, "DatastarSignal|$old"), "removed custom values are no longer tokenized")
  h.assert_true(not vim.tbl_contains(rendered, "DatastarSignal|$ignored"), "unknown controls remain negative after replacement")

  datastar.setup(nil)
  h.assert_equal({ "replacement" }, datastar._state().config.custom_attributes, "setup(nil) preserves current configuration")
  assert_contains(semantic_text(buf), "DatastarPlugin|replacement", "setup(nil) reapplies current configuration")

  local before_second_loader = h.autocmd_topology("datastar.nvim")
  vim.g.loaded_datastar_nvim = nil
  vim.cmd("runtime plugin/datastar.lua")
  h.assert_equal({ "replacement" }, datastar._state().config.custom_attributes, "a later no-argument loader preserves explicit configuration")
  h.assert_equal(before_second_loader, h.autocmd_topology("datastar.nvim"), "a later loader keeps one autocmd topology")
  local renderer = require("datastar.renderer")
  local original_refresh = renderer.refresh
  local refresh_count = 0
  h.with_patch(renderer, "refresh", function(target)
    refresh_count = refresh_count + 1
    return original_refresh(target)
  end, function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, { [[<div data-replacement="!$new"></div>]] })
  end)
  h.assert_equal(1, refresh_count, "loader/setup ordering leaves one current buffer callback")

  datastar.setup({})
  h.assert_equal({}, datastar._state().config.custom_attributes, "setup({}) replaces configuration from defaults")
  h.assert_equal({}, h.extmarks(buf), "setup({}) clears custom names and their value marks")
end
