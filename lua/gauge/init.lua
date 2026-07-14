-- lua/gauge/init.lua
local M = {}

local defaults = {
  cmd          = nil,
  on_attach    = nil,
  capabilities = nil,
  settings     = {},
  keymaps      = false,
}

function M.setup(opts)
  opts = vim.tbl_deep_extend('force', defaults, opts or {})

  -- ft.setup() is also called in plugin/gauge.lua, but calling it again here
  -- is harmless (vim.filetype.add is idempotent) and ensures setup() works
  -- standalone without the plugin/ autoload.
  require('gauge.ft').setup()
  require('gauge.lsp').setup(opts)
  require('gauge.commands').setup()

  if opts.keymaps then
    vim.api.nvim_create_autocmd('FileType', {
      pattern  = { 'gauge', 'gauge_concept' },
      group    = vim.api.nvim_create_augroup('GaugeKeymaps', { clear = true }),
      callback = function(ev)
        local ko = { buffer = ev.buf, silent = true }
        vim.keymap.set('n', '<leader>gr', '<cmd>GaugeRun<cr>',
          vim.tbl_extend('force', ko, { desc = 'Gauge: run spec/scenario' }))
        vim.keymap.set('n', '<leader>gs', '<cmd>GaugeSpecs<cr>',
          vim.tbl_extend('force', ko, { desc = 'Gauge: list specs' }))
      end,
    })
  end
end

return M
