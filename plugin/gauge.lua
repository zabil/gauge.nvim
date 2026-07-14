-- plugin/gauge.lua
if vim.fn.has('nvim-0.10') == 0 then
  vim.notify('[gauge.nvim] Requires Neovim >= 0.10', vim.log.levels.ERROR)
  return
end

-- Filetype detection is always registered on load.
-- LSP and commands require require('gauge').setup() in user config.
require('gauge.ft').setup()
