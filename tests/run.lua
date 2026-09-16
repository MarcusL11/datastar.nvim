local root = assert(vim.env.DATASTAR_ROOT, "DATASTAR_ROOT is required")
local case_path = assert(vim.env.DATASTAR_TEST_CASE, "DATASTAR_TEST_CASE is required")

local function fail(message)
  io.stderr:write(message .. "\n")
  vim.cmd("cquit 1")
end

local ok, error_message = xpcall(function()
  local case = dofile(root .. "/" .. case_path)
  assert(type(case) == "function", case_path .. " must return a function")
  case()
end, debug.traceback)

if not ok then
  fail(("FAIL %s\n%s"):format(case_path, error_message))
else
  io.stdout:write(("PASS %s\n"):format(case_path))
  vim.cmd("qa!")
end
