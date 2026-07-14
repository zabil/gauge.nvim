-- lua/gauge/commands.lua
local M = {}

-- Track the terminal split so we can reuse it across runs.
local run_win = nil

local function gauge_client(bufnr)
  local clients = vim.lsp.get_clients({ name = 'gauge', bufnr = bufnr })
  return clients[1]
end

-- Return the 1-based line number of the nearest scenario heading (## ...) at
-- or above the cursor, or nil if none found.
local function nearest_scenario_line(bufnr)
  local row = vim.api.nvim_win_get_cursor(0)[1] -- 1-based
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, row, false)
  for i = #lines, 1, -1 do
    if lines[i]:match('^## ') then
      return i
    end
  end
  return nil
end

local function open_run_split(shell_cmd)
  -- If the previous run window is still open, close its buffer first so the
  -- terminal doesn't accumulate stale output.
  if run_win and vim.api.nvim_win_is_valid(run_win) then
    vim.api.nvim_win_close(run_win, true)
  end

  local prev_win = vim.api.nvim_get_current_win()
  vim.cmd('botright split')
  run_win = vim.api.nvim_get_current_win()

  vim.fn.termopen(shell_cmd, {
    on_exit = function(_, code)
      vim.notify(
        string.format('[gauge.nvim] Run finished (exit %d)', code),
        code == 0 and vim.log.levels.INFO or vim.log.levels.WARN
      )
    end,
  })

  -- Give the terminal buffer a stable name.
  pcall(vim.api.nvim_buf_set_name, vim.api.nvim_get_current_buf(), 'Gauge Run')
  -- Return focus to the spec buffer.
  vim.api.nvim_set_current_win(prev_win)
end

function M.run()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= 'gauge' then
    vim.notify('[gauge.nvim] :GaugeRun only works in .spec buffers', vim.log.levels.INFO)
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == '' then
    vim.notify('[gauge.nvim] Buffer has no file path', vim.log.levels.WARN)
    return
  end

  local scenario_line = nearest_scenario_line(bufnr)
  local target = scenario_line
    and (filepath .. ':' .. tostring(scenario_line))
    or filepath

  open_run_split('gauge run ' .. vim.fn.shellescape(target))
end

function M.specs()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = gauge_client(bufnr)
  if not client then
    vim.notify('[gauge.nvim] No active Gauge LSP client. Open a .spec file first.', vim.log.levels.WARN)
    return
  end

  -- gauge/specs takes no params and returns []specInfo
  client.request('gauge/specs', vim.empty_dict(), function(err, result)
    if err then
      vim.notify('[gauge.nvim] gauge/specs failed: ' .. tostring(err.message), vim.log.levels.ERROR)
      return
    end
    if not result or #result == 0 then
      vim.notify('[gauge.nvim] No spec files found in project', vim.log.levels.INFO)
      return
    end

    local qf = {}
    for _, spec in ipairs(result) do
      -- result[i] = { heading = "...", executionIdentifier = "/abs/path.spec" }
      table.insert(qf, {
        filename = spec.executionIdentifier,
        lnum     = 1,
        col      = 1,
        text     = spec.heading,
      })
    end

    vim.fn.setqflist({}, 'r', { title = 'Gauge Specs', items = qf })
    vim.cmd('copen')
  end, bufnr)
end

function M.setup()
  vim.api.nvim_create_user_command('GaugeRun', function()
    M.run()
  end, { desc = 'Run current Gauge spec or scenario in a split terminal' })

  vim.api.nvim_create_user_command('GaugeSpecs', function()
    M.specs()
  end, { desc = 'List all Gauge spec files in the quickfix list' })
end

return M
