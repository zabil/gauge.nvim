-- lua/gauge/lsp.lua
local M = {}

-- Track which cwds we've already warned about so we only notify once.
local warned = {}

local function find_root(bufnr)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  if fname == '' then return nil end
  local matches = vim.fs.find('manifest.json', {
    path    = vim.fs.dirname(fname),
    upward  = true,
    limit   = 1,
  })
  if matches[1] then
    return vim.fs.dirname(matches[1])
  end
  return nil
end

function M.attach(bufnr, opts)
  if vim.fn.executable('gauge') == 0 then
    vim.notify('[gauge.nvim] gauge not found in PATH. LSP will not start.', vim.log.levels.ERROR)
    return
  end

  local root_dir = find_root(bufnr)
  if not root_dir then
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local dir = vim.fs.dirname(fname)
    if not warned[dir] then
      warned[dir] = true
      vim.notify(
        '[gauge.nvim] No manifest.json found — not a Gauge project. LSP will not start.',
        vim.log.levels.WARN
      )
    end
    return
  end

  local cmd = opts.cmd or { 'gauge', 'daemon', '--lsp', '--dir', root_dir }

  vim.lsp.start({
    name         = 'gauge',
    cmd          = cmd,
    root_dir     = root_dir,
    capabilities = opts.capabilities or vim.lsp.protocol.make_client_capabilities(),
    settings     = opts.settings or {},
    on_attach    = opts.on_attach,
  }, { bufnr = bufnr })
end

function M.setup(opts)
  vim.api.nvim_create_autocmd('FileType', {
    pattern  = { 'gauge', 'gauge_concept' },
    group    = vim.api.nvim_create_augroup('GaugeLsp', { clear = true }),
    callback = function(ev)
      M.attach(ev.buf, opts)
    end,
  })
end

return M
