-- Minimal test runner. Usage: nvim --headless -u NONE -l tests/run.lua
-- Discovers tests/*_test.lua; each file returns function(t) registering tests.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(root)
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local tests = {}
local t = {}
function t.test(name, fn) table.insert(tests, { name = name, fn = fn }) end
function t.eq(expected, actual, msg)
  if not vim.deep_equal(expected, actual) then
    error(string.format('%sexpected %s, got %s', msg and (msg .. ': ') or '',
      vim.inspect(expected), vim.inspect(actual)), 2)
  end
end
function t.truthy(v, msg) if not v then error(msg or 'expected truthy value', 2) end end

-- Create a temp tree: files = { ['a/b.txt'] = 'content' }; returns base dir.
function t.tree(files)
  local base = vim.fn.resolve(vim.fn.tempname())
  for rel, content in pairs(files) do
    local path = base .. '/' .. rel
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    vim.fn.writefile(vim.split(content, '\n'), path)
  end
  return base
end

local files = vim.fn.glob(root .. '/tests/*_test.lua', false, true)
table.sort(files)
for _, f in ipairs(files) do
  local chunk = assert(loadfile(f))
  chunk()(t)
end

local failed = 0
for _, case in ipairs(tests) do
  local ok, err = pcall(case.fn)
  if ok then
    print('PASS  ' .. case.name)
  else
    failed = failed + 1
    print('FAIL  ' .. case.name .. '\n      ' .. tostring(err))
  end
end
print(string.format('\n%d tests, %d failed', #tests, failed))
vim.cmd(failed == 0 and 'qa!' or 'cq!')
