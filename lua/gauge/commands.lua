-- lua/gauge/commands.lua
local M = {}

-- Track the terminal split so we can reuse it across runs.
local run_win = nil
local run_buf = nil

local function gauge_client(bufnr)
  local clients = vim.lsp.get_clients({ name = 'gauge', bufnr = bufnr })
  return clients[1]
end

-- Return the 1-based line number of the nearest scenario heading (## ...) at
-- or above the cursor, or nil if none found.
-- Note: the Gauge spec format requires a space after ##, so this matches
-- "## Scenario Name" but not "##ScenarioName". The latter is non-standard.
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
  -- Delete previous terminal buffer (also kills the attached job).
  if run_buf and vim.api.nvim_buf_is_valid(run_buf) then
    vim.api.nvim_buf_delete(run_buf, { force = true })
  end
  run_win = nil
  run_buf = nil

  local prev_win = vim.api.nvim_get_current_win()
  vim.cmd('botright new')
  run_win = vim.api.nvim_get_current_win()

  vim.fn.termopen(shell_cmd, {
    on_exit = function(_, code)
      vim.notify(
        string.format('[gauge.nvim] Run finished (exit %d)', code),
        code == 0 and vim.log.levels.INFO or vim.log.levels.WARN
      )
    end,
  })

  run_buf = vim.api.nvim_get_current_buf()
  pcall(vim.api.nvim_buf_set_name, run_buf, 'Gauge Run')
  vim.api.nvim_set_current_win(prev_win)
end

function M.run()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= 'gauge' then
    vim.notify(
      '[gauge.nvim] :GaugeRun only works in .spec buffers.\n'
        .. 'Open a Gauge spec file (*.spec) and try again.',
      vim.log.levels.INFO
    )
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == '' then
    vim.notify(
      '[gauge.nvim] Buffer has no file path — save the file before running.',
      vim.log.levels.WARN
    )
    return
  end

  local scenario_line = nearest_scenario_line(bufnr)
  local cmd = 'gauge run ' .. vim.fn.shellescape(filepath)
  if scenario_line then
    cmd = cmd .. ':' .. tostring(scenario_line)
  end
  open_run_split(cmd)
end

function M.specs()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = gauge_client(bufnr)
  if not client then
    vim.notify(
      '[gauge.nvim] No active Gauge LSP client.\n'
        .. 'Open a .spec file inside a Gauge project (one containing manifest.json) first.',
      vim.log.levels.WARN
    )
    return
  end

  -- gauge/specs takes no params (nil omits the "params" field in JSON-RPC)
  client.request('gauge/specs', nil, function(err, result)
    if err then
      vim.notify(
        '[gauge.nvim] Failed to fetch spec list from LSP server: ' .. tostring(err.message),
        vim.log.levels.ERROR
      )
      return
    end
    if not result or #result == 0 then
      vim.notify(
        '[gauge.nvim] No spec files found in this project.\n'
          .. 'Make sure your specs directory exists and contains *.spec files.',
        vim.log.levels.INFO
      )
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

function M.workspace_symbols()
  -- The Gauge LSP server silently returns nothing for queries shorter than 2
  -- characters (server-side guard in symbols.go). vim.lsp.buf.workspace_symbol()
  -- sends an empty string by default, which always gets nil back. We prompt
  -- first and enforce the minimum length before sending.
  vim.ui.input({ prompt = 'Gauge workspace symbol (min 2 chars): ' }, function(query)
    if not query then return end  -- user cancelled
    if #query < 2 then
      vim.notify(
        '[gauge.nvim] Workspace symbol query must be at least 2 characters.\n'
          .. 'The Gauge LSP server requires a minimum 2-character query.',
        vim.log.levels.WARN
      )
      return
    end
    vim.lsp.buf.workspace_symbol(query)
  end)
end

function M.setup()
  vim.api.nvim_create_user_command('GaugeRun', function()
    M.run()
  end, { desc = 'Run current Gauge spec or scenario in a split terminal', force = true })

  vim.api.nvim_create_user_command('GaugeSpecs', function()
    M.specs()
  end, { desc = 'List all Gauge spec files in the quickfix list', force = true })

  vim.api.nvim_create_user_command('GaugeSymbols', function()
    M.workspace_symbols()
  end, { desc = 'Search Gauge workspace symbols (specs + scenarios)', force = true })
end

return M
