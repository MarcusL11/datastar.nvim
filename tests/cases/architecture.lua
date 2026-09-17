local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

local expected_fixture = [[2:2-2:7|DatastarAttributePrefix|data-
2:7-2:14|DatastarPlugin|signals
2:16-2:17|DatastarPunctuation|{
2:17-2:23|DatastarObjectKey|_ready
2:23-2:24|DatastarOperator|:
2:25-2:30|DatastarBoolean|false
2:30-2:31|DatastarPunctuation|,
2:32-2:36|DatastarObjectKey|form
2:36-2:37|DatastarOperator|:
2:38-2:39|DatastarPunctuation|{
2:39-2:44|DatastarObjectKey|query
2:44-2:45|DatastarOperator|:
2:46-2:48|DatastarString|''
2:48-2:49|DatastarPunctuation|}
2:49-2:50|DatastarPunctuation|}
3:2-3:7|DatastarAttributePrefix|data-
3:7-3:11|DatastarPlugin|init
3:13-3:20|DatastarSignal|$_ready
3:21-3:22|DatastarOperator|=
3:23-3:27|DatastarBoolean|true
4:2-4:7|DatastarAttributePrefix|data-
4:7-4:12|DatastarPlugin|class
4:14-4:15|DatastarPunctuation|{
4:15-4:29|DatastarString|'panel--ready'
4:29-4:30|DatastarOperator|:
4:31-4:38|DatastarSignal|$_ready
4:38-4:39|DatastarPunctuation|}
5:2-5:7|DatastarAttributePrefix|data-
5:7-5:19|DatastarPlugin|on-intersect
5:19-5:21|DatastarModifierSeparator|__
5:21-5:25|DatastarModifier|once
5:25-5:27|DatastarModifierSeparator|__
5:27-5:31|DatastarModifier|half
5:33-5:40|DatastarSignal|$_ready
5:41-5:42|DatastarOperator|=
5:43-5:47|DatastarBoolean|true
7:9-7:14|DatastarAttributePrefix|data-
7:14-7:18|DatastarPlugin|bind
7:18-7:19|DatastarKeySeparator|:
7:19-7:29|DatastarKey|form.query
9:4-9:9|DatastarAttributePrefix|data-
9:9-9:18|DatastarPlugin|indicator
9:18-9:19|DatastarKeySeparator|:
9:19-9:27|DatastarKey|_loading
10:4-10:9|DatastarAttributePrefix|data-
10:9-10:13|DatastarPlugin|attr
10:13-10:14|DatastarKeySeparator|:
10:14-10:23|DatastarKey|aria-busy
10:25-10:34|DatastarSignal|$_loading
10:35-10:36|DatastarOperator|?
10:37-10:43|DatastarString|'true'
10:44-10:45|DatastarOperator|:
10:46-10:50|DatastarNull|null
11:4-11:9|DatastarAttributePrefix|data-
11:9-11:11|DatastarPlugin|on
11:11-11:12|DatastarKeySeparator|:
11:12-11:17|DatastarKey|click
11:22-11:23|DatastarAccessor|.
11:23-11:37|DatastarMethodCall|preventDefault
11:37-11:38|DatastarCallPunctuation|(
11:38-11:39|DatastarCallPunctuation|)
11:39-11:40|DatastarPunctuation|;
11:41-11:42|DatastarOperator|!
11:42-11:51|DatastarSignal|$_loading
11:52-11:54|DatastarOperator|&&
11:55-11:59|DatastarAction|@get
11:59-11:60|DatastarCallPunctuation|(
11:60-11:61|DatastarString|'
11:78-11:84|DatastarString|?page=
11:94-11:95|DatastarString|'
11:95-11:96|DatastarCallPunctuation|)
13:10-13:15|DatastarAttributePrefix|data-
13:15-13:19|DatastarPlugin|show
13:21-13:22|DatastarOperator|!
13:22-13:31|DatastarSignal|$_loading
14:10-14:15|DatastarAttributePrefix|data-
14:15-14:19|DatastarPlugin|show
14:21-14:30|DatastarSignal|$_loading]]

local function compact_marks(buf)
  local lines = {}
  for _, mark in ipairs(h.marks_with_text(buf)) do
    lines[#lines + 1] = ("%d:%d-%d:%d|%s|%s"):format(
      mark.row,
      mark.col,
      mark.end_row,
      mark.end_col,
      mark.group,
      mark.text
    )
    h.assert_equal(110, mark.priority, "every semantic mark uses the documented priority")
  end
  return table.concat(lines, "\n")
end

local function assert_synthetic_roles(datastar)
  local text = [[<div data-on:click__debounce.500ms="$foo + $$bar; format([12, true, null]); thing.run('x\\n')"></div>]]
  local buf = h.new_buffer(text, "html")
  local result = datastar.refresh(buf)
  h.assert_equal(nil, result.error, "synthetic role refresh")

  local roles = {}
  for _, mark in ipairs(h.marks_with_text(buf)) do
    roles[mark.group .. "|" .. mark.text] = true
  end
  local expected = {
    "DatastarKey|click",
    "DatastarModifier|debounce",
    "DatastarModifierArgument|500ms",
    "DatastarSignal|$foo",
    "DatastarSignal|$$bar",
    "DatastarFunctionCall|format",
    "DatastarNumber|12",
    "DatastarBoolean|true",
    "DatastarNull|null",
    "DatastarMethodCall|run",
    "DatastarString|'x\\\\n'",
    "DatastarEscape|\\\\",
  }
  for _, role in ipairs(expected) do
    h.assert_true(roles[role], "missing synthetic semantic role " .. role)
  end
end

local function assert_negative_controls(datastar)
  local text = [[<div data-ordinary="$_not_datastar" aria-label="@get('x')" title="data-show" data-unknown="$foo"></div>
<!-- data-on:click="$foo" -->
text data-show="$foo"]]
  local buf = h.new_buffer(text, "html")
  datastar.refresh(buf)
  h.assert_equal({}, h.extmarks(buf), "negative controls must not produce Datastar marks")
end

local function assert_deferred_constructs(datastar)
  local text = [[<div data-show="condition ? value : other; x => x; [...items]; `hello ${$foo}`"></div>]]
  local buf = h.new_buffer(text, "html")
  datastar.refresh(buf)
  for _, mark in ipairs(h.marks_with_text(buf)) do
    h.assert_true(not (mark.group == "DatastarObjectKey" and mark.text == "value"), "ternary operand must not become an object key")
    h.assert_true(not (mark.group == "DatastarSignal" and mark.text == "$foo"), "template interpolation is deferred")
    h.assert_true(not (mark.group == "DatastarAccessor" and mark.text == "."), "spread semantics are deferred")
  end
end

local function assert_inventory(datastar)
  local names = require("datastar.attributes").names()
  local expected_names = {
    "animate", "attr", "bind", "class", "computed", "custom-validity", "effect", "ignore",
    "ignore-morph", "indicator", "init", "json-signals", "match-media", "nonce", "on",
    "on-intersect", "on-interval", "on-raf", "on-resize", "on-signal-patch",
    "on-signal-patch-filter", "persist", "preserve-attr", "query-string", "ref", "replace-url",
    "scroll-into-view", "show", "signals", "style", "text", "view-transition",
  }
  h.assert_equal(expected_names, names, "generated inventory must match the pinned upstream 32-attribute list")
  local lines = {}
  for _, name in ipairs(names) do
    lines[#lines + 1] = ('<div data-%s="$signal"></div>'):format(name)
  end
  local buf = h.new_buffer(table.concat(lines, "\n"), "html")
  datastar.refresh(buf)
  local seen = {}
  for _, mark in ipairs(h.marks_with_text(buf)) do
    if mark.group == "DatastarPlugin" then
      seen[mark.text] = true
    end
  end
  for _, name in ipairs(names) do
    h.assert_true(seen[name], "pinned built-in attribute was not recognized: " .. name)
  end
  h.assert_equal(#names, vim.tbl_count(seen), "recognized inventory count")
end

return function()
  local expected_parser = vim.env.DATASTAR_ROOT .. "/.deps/parser/html.so"
  h.assert_equal({ expected_parser }, h.runtime_parser_paths(), "test must use only its pinned HTML parser")

  local django_language = vim.treesitter.language.get_lang("htmldjango")
  local datastar = require("datastar")
  datastar.setup()
  datastar.setup()
  h.assert_equal(django_language, vim.treesitter.language.get_lang("htmldjango"), "htmldjango language identity")

  local buf = h.new_buffer(h.read_fixture("representative.html"), "html")
  local started, start_error = pcall(vim.treesitter.start, buf, "html")
  h.assert_true(started, "visible HTML Tree-sitter highlighter failed: " .. tostring(start_error))

  local parser = vim.treesitter.get_parser(buf, "html")
  local trees = parser:parse(true)
  h.assert_equal("document", trees[1]:root():type(), "explicit HTML parse root")

  local result = datastar.refresh(buf)
  h.assert_equal(nil, result.error, "representative HTML refresh")
  h.assert_equal(10, result.stats.attributes_examined, "fixture attribute count")
  h.assert_equal(10, result.stats.recognized_attributes, "fixture Datastar attribute count")
  h.assert_equal(expected_fixture, compact_marks(buf), "exact representative fixture semantics")

  assert_synthetic_roles(datastar)
  assert_negative_controls(datastar)
  assert_deferred_constructs(datastar)
  assert_inventory(datastar)
end
