-- lua/gauge/health.lua
local M = {}

function M.check()
  vim.health.start('gauge.nvim')

  -- Neovim version
  if vim.fn.has('nvim-0.10') == 1 then
    vim.health.ok('Neovim >= 0.10 ✓')
  else
    vim.health.error(
      'Neovim >= 0.10 is required but this version is older.',
      { 'Upgrade Neovim: https://github.com/neovim/neovim/releases' }
    )
  end

  -- gauge binary
  if vim.fn.executable('gauge') == 1 then
    local out = vim.fn.system('gauge version 2>&1')
    local ver = out:match('Gauge version: ([^\n]+)') or out:gsub('\n', '')
    vim.health.ok('gauge binary found: ' .. ver)
  else
    vim.health.error(
      '"gauge" not found in PATH — the LSP server cannot start.',
      {
        'Install Gauge from https://gauge.org/get-started/',
        'Make sure the install directory is on your PATH (run: echo $PATH)',
      }
    )
  end

  -- setup() called check
  local aus = vim.api.nvim_get_autocmds({ group = 'GaugeLsp' })
  if #aus > 0 then
    vim.health.ok('setup() has been called — LSP autocmd is registered')
  else
    vim.health.warn(
      'setup() has not been called — the LSP will not auto-attach.',
      { 'Add require("gauge").setup() to your Neovim config (init.lua)' }
    )
  end

  -- Active LSP clients
  local clients = vim.lsp.get_clients({ name = 'gauge' })
  if #clients > 0 then
    local roots = {}
    for _, c in ipairs(clients) do
      table.insert(roots, c.config.root_dir or '(unknown)')
    end
    vim.health.ok(string.format(
      '%d active gauge LSP client(s): %s',
      #clients,
      table.concat(roots, ', ')
    ))
  else
    vim.health.info(
      'No active gauge LSP clients — open a .spec file inside a Gauge project to attach.'
    )
  end
end

return M
