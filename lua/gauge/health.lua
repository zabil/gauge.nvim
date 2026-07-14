-- lua/gauge/health.lua
local M = {}

function M.check()
  vim.health.start('gauge.nvim')

  -- Neovim version
  if vim.fn.has('nvim-0.10') == 1 then
    vim.health.ok('Neovim >= 0.10 ✓')
  else
    vim.health.error('Neovim >= 0.10 is required')
  end

  -- gauge binary
  if vim.fn.executable('gauge') == 1 then
    local out = vim.fn.system('gauge version 2>&1')
    local ver = out:match('Gauge version: ([^\n]+)') or out:gsub('\n', '')
    vim.health.ok('gauge found: ' .. ver)
  else
    vim.health.error(
      'gauge binary not found in PATH',
      { 'Install Gauge: https://gauge.org/get-started/' }
    )
  end

  -- Active LSP clients
  local clients = vim.lsp.get_clients({ name = 'gauge' })
  if #clients > 0 then
    vim.health.ok(string.format('%d active gauge LSP client(s)', #clients))
  else
    vim.health.info('No active gauge LSP clients (open a .spec file to attach)')
  end
end

return M
