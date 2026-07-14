-- lua/gauge/ft.lua
local M = {}

function M.setup()
  vim.filetype.add({
    extension = {
      spec = 'gauge',
      cpt  = 'gauge_concept',
    },
  })
end

return M
