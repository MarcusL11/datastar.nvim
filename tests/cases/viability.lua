local h = dofile(vim.env.DATASTAR_ROOT .. "/tests/helpers.lua")

local function measure(datastar, text)
  local buf = h.new_buffer(text, "html")
  local started = vim.loop.hrtime()
  local result = datastar.refresh(buf)
  local milliseconds = (vim.loop.hrtime() - started) / 1000000
  h.assert_equal(nil, result.error, "viability refresh")
  return result, milliseconds
end

return function()
  local file = assert(io.open(vim.env.DATASTAR_ROOT .. "/.deps/fixtures/viability.html", "rb"))
  local fixture = file:read("*a")
  file:close()
  local bytes = #fixture
  h.assert_true(bytes >= 100 * 1024 and bytes < 102 * 1024, "viability fixture must remain approximately 100 KiB")

  local lines = h.lines(fixture)
  h.assert_true(#lines % 2 == 0, "viability fixture line count must be even")
  local half = table.concat(vim.list_slice(lines, 1, #lines / 2), "\n") .. "\n"

  local datastar = require("datastar")
  datastar.setup()
  local half_result, half_ms = measure(datastar, half)
  local full_result, full_ms = measure(datastar, fixture)

  h.assert_equal(half_result.stats.recognized_attributes * 2, full_result.stats.recognized_attributes, "recognized work scales with input")
  h.assert_equal(half_result.stats.value_bytes_examined * 2, full_result.stats.value_bytes_examined, "tokenized bytes scale linearly")
  h.assert_equal(half_result.token_count * 2, full_result.token_count, "token count scales linearly")
  h.assert_equal(half_result.extmark_count * 2, full_result.extmark_count, "extmark count scales linearly")

  local disposition = full_ms > 20 and " INVESTIGATE(>20ms)" or ""
  io.stdout:write((
    "VIABILITY bytes=%d attributes=%d examined_value_bytes=%d tokens=%d extmarks=%d half_ms=%.3f full_ms=%.3f%s\n"
  ):format(
    bytes,
    full_result.stats.recognized_attributes,
    full_result.stats.value_bytes_examined,
    full_result.token_count,
    full_result.extmark_count,
    half_ms,
    full_ms,
    disposition
  ))
end
