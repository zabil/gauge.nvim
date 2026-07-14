# gauge.nvim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a zero-dependency Neovim plugin that wires the Gauge LSP server to `.spec`/`.cpt` files and provides `:GaugeRun` and `:GaugeSpecs` commands.

**Architecture:** The plugin registers filetypes on load via `plugin/gauge.lua`, then attaches the Gauge LSP server (started via `gauge daemon --lsp --dir <root>` over stdio) to those buffers once `require('gauge').setup()` is called. Commands are registered globally; keymaps are buffer-local and opt-in.

**Tech Stack:** Lua, Neovim 0.10+ native APIs (`vim.lsp`, `vim.filetype`, `vim.fs`, `vim.api`). No external dependencies.

## Global Constraints

- Neovim >= 0.10 required (uses `vim.lsp.start`, `vim.fs.find`, `vim.filetype.add`)
- Zero runtime dependencies — no nvim-lspconfig, no plenary
- All Lua modules live under `lua/gauge/`
- Public entry point: `require('gauge').setup(opts)`
- LSP server command: `gauge daemon --lsp --dir <root_dir>` (stdio transport)
- Gauge project root marker: presence of `manifest.json` walking upward from buffer path
- File extensions: `.spec` → filetype `gauge`, `.cpt` → filetype `gauge_concept`

---

### Task 1: Project scaffold, filetype detection, and ftplugin

**Files:**
- Create: `lua/gauge/ft.lua`
- Create: `plugin/gauge.lua`
- Create: `ftplugin/gauge.vim`
- Create: `ftplugin/gauge_concept.vim`

**Interfaces:**
- Produces: `require('gauge.ft').setup()` — registers `.spec` → `gauge` and `.cpt` → `gauge_concept` with `vim.filetype.add()`

- [ ] **Step 1: Create the directory structure**

```bash
cd /Users/zabilcm/projects/gauge.nvim
mkdir -p lua/gauge ftplugin plugin
```

- [ ] **Step 2: Create `lua/gauge/ft.lua`**

```lua
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
```

- [ ] **Step 3: Create `plugin/gauge.lua`**

This file runs automatically when Neovim loads the plugin via pack. It registers filetypes so they work even before the user calls `setup()`. It also guards against old Neovim versions.

```lua
-- plugin/gauge.lua
if vim.fn.has('nvim-0.10') == 0 then
  vim.notify('[gauge.nvim] Requires Neovim >= 0.10', vim.log.levels.ERROR)
  return
end

-- Filetype detection is always registered on load.
-- LSP and commands require require('gauge').setup() in user config.
require('gauge.ft').setup()
```

- [ ] **Step 4: Create `ftplugin/gauge.vim`**

```vim
" ftplugin/gauge.vim
if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=#\ %s
setlocal tabstop=2 shiftwidth=2 expandtab
```

- [ ] **Step 5: Create `ftplugin/gauge_concept.vim`**

```vim
" ftplugin/gauge_concept.vim
if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=#\ %s
setlocal tabstop=2 shiftwidth=2 expandtab
```

- [ ] **Step 6: Verify filetype detection**

Open any file with a `.spec` extension:

```
nvim /tmp/test.spec
```

Inside Neovim run: `:set ft?`

Expected output: `filetype=gauge`

Then open `/tmp/test.cpt`, run `:set ft?`

Expected output: `filetype=gauge_concept`

- [ ] **Step 7: Commit**

```bash
cd /Users/zabilcm/projects/gauge.nvim
git init
git add lua/gauge/ft.lua plugin/gauge.lua ftplugin/
git commit -m "feat: add filetype detection for .spec and .cpt files

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: LSP module

**Files:**
- Create: `lua/gauge/lsp.lua`

**Interfaces:**
- Consumes: nothing (uses Neovim native `vim.lsp.start`, `vim.fs.find`)
- Produces: `require('gauge.lsp').setup(opts)` — registers a `FileType gauge,gauge_concept` autocmd that calls `vim.lsp.start()` for each buffer

`opts` shape (all fields optional):
```lua
{
  cmd          = { 'gauge', 'daemon', '--lsp', '--dir', root_dir }, -- []string
  on_attach    = function(client, bufnr) end,
  capabilities = vim.lsp.protocol.make_client_capabilities(),       -- table
  settings     = {},                                                  -- table
}
```

- [ ] **Step 1: Create `lua/gauge/lsp.lua`**

```lua
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
    local cwd = vim.fn.getcwd()
    if not warned[cwd] then
      warned[cwd] = true
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
```

- [ ] **Step 2: Verify LSP attaches in a real Gauge project**

You need a Gauge project on disk with a `manifest.json` and at least one `.spec` file. If you have one at hand, open it:

```
nvim /path/to/gauge-project/specs/example.spec
```

Add `require('gauge').setup()` to your Neovim config temporarily (see Task 4 for final wiring), or run:

```
:lua require('gauge.ft').setup(); require('gauge.lsp').setup({})
```

Then check:

```
:checkhealth lsp
```

or in older Neovim:

```
:lua vim.print(vim.lsp.get_clients({ name = 'gauge' }))
```

Expected: a table with one client named `gauge`.

- [ ] **Step 3: Commit**

```bash
git add lua/gauge/lsp.lua
git commit -m "feat: add LSP client module using vim.lsp.start

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: Commands module (`:GaugeRun`, `:GaugeSpecs`)

**Files:**
- Create: `lua/gauge/commands.lua`

**Interfaces:**
- Consumes: active Gauge LSP client (`vim.lsp.get_clients({ name = 'gauge', bufnr = bufnr })`)
- Produces: `require('gauge.commands').setup()` — registers `:GaugeRun` and `:GaugeSpecs` as global user commands

`gauge/specs` LSP response shape (one entry per spec):
```lua
{ heading = "Spec Title", executionIdentifier = "/abs/path/to/file.spec" }
```

- [ ] **Step 1: Create `lua/gauge/commands.lua`**

```lua
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
```

- [ ] **Step 2: Verify `:GaugeRun` in a gauge buffer**

Open a `.spec` file in a real Gauge project, run:

```
:lua require('gauge.commands').setup()
:GaugeRun
```

Expected: a horizontal split terminal opens at the bottom showing `gauge run` output. Focus returns to the spec buffer.

- [ ] **Step 3: Verify `:GaugeRun` on a scenario line**

Place the cursor on or below a `## Scenario Name` heading line, then run `:GaugeRun`.

Expected: terminal runs `gauge run /path/to/file.spec:<line>` (scenario-scoped run).

- [ ] **Step 4: Verify `:GaugeSpecs`**

With LSP attached, run:

```
:GaugeSpecs
```

Expected: quickfix window opens listing spec files with their headings as text entries. Press `Enter` on any to jump to it.

- [ ] **Step 5: Verify guard — `:GaugeRun` outside gauge buffer**

Open a non-spec buffer (e.g. `:enew`) and run `:GaugeRun`.

Expected: notification `:GaugeRun only works in .spec buffers`, no terminal opens.

- [ ] **Step 6: Commit**

```bash
git add lua/gauge/commands.lua
git commit -m "feat: add :GaugeRun and :GaugeSpecs commands

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 4: Public API — `setup()`, keymaps, and health check

**Files:**
- Create: `lua/gauge/init.lua`
- Create: `lua/gauge/health.lua`

**Interfaces:**
- Consumes:
  - `require('gauge.ft').setup()` — no args
  - `require('gauge.lsp').setup(opts)` — `opts` table (see Task 2 Interfaces)
  - `require('gauge.commands').setup()` — no args
- Produces:
  - `require('gauge').setup(opts)` — the single public entry point users call in their config

`opts` shape passed to `setup()`:
```lua
{
  cmd          = nil,    -- []string | nil: override gauge LSP command
  on_attach    = nil,    -- function(client, bufnr) | nil
  capabilities = nil,    -- table | nil
  settings     = {},     -- table
  keymaps      = false,  -- boolean: enable <leader>gr / <leader>gs in gauge buffers
}
```

- [ ] **Step 1: Create `lua/gauge/init.lua`**

```lua
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
```

- [ ] **Step 2: Create `lua/gauge/health.lua`**

```lua
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
```

- [ ] **Step 3: Verify `setup()` wires everything**

Add to your Neovim config:

```lua
require('gauge').setup({ keymaps = true })
```

Restart Neovim, open a `.spec` file. Verify:

1. `:set ft?` → `filetype=gauge`
2. `:lua vim.print(vim.lsp.get_clients({ name = 'gauge' }))` → one client entry
3. `:GaugeRun` → terminal split opens
4. `<leader>gr` → same as `:GaugeRun` (because `keymaps = true`)

- [ ] **Step 4: Verify `:checkhealth gauge`**

Run `:checkhealth gauge` inside Neovim.

Expected: all three checks pass (Neovim version, gauge binary found, LSP client count).

- [ ] **Step 5: Commit**

```bash
git add lua/gauge/init.lua lua/gauge/health.lua
git commit -m "feat: add setup() public API, keymaps, and :checkhealth gauge

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 5: README

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: nothing — documentation only
- Produces: `README.md` with installation, configuration, usage, and requirements

- [ ] **Step 1: Create `README.md`**

```markdown
# gauge.nvim

Neovim plugin for [Gauge](https://gauge.org/) — wires the Gauge LSP server to
`.spec` and `.cpt` files using Neovim's native LSP client. No external
dependencies.

## Requirements

- Neovim >= 0.10
- [`gauge`](https://gauge.org/get-started/) installed and on your `$PATH`

## Installation

### Using Neovim's built-in package manager (pack)

```bash
mkdir -p ~/.config/nvim/pack/plugins/start
git clone https://github.com/yourname/gauge.nvim \
  ~/.config/nvim/pack/plugins/start/gauge.nvim
```

Then add to your `~/.config/nvim/init.lua`:

```lua
require('gauge').setup()
```

## Configuration

All options are optional — `setup()` works with no arguments:

```lua
require('gauge').setup({
  -- Override the LSP server command (default: gauge daemon --lsp --dir <root>)
  cmd = { 'gauge', 'daemon', '--lsp', '--dir', vim.fn.getcwd() },

  -- Called when the LSP client attaches to a buffer
  on_attach = function(client, bufnr)
    -- e.g. set keymaps, enable inlay hints, etc.
  end,

  -- Override LSP client capabilities
  capabilities = vim.lsp.protocol.make_client_capabilities(),

  -- LSP workspace settings
  settings = {},

  -- Enable <leader>gr (GaugeRun) and <leader>gs (GaugeSpecs) in gauge buffers
  keymaps = false,
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:GaugeRun` | Run the current `.spec` file, or the nearest scenario if the cursor is inside one |
| `:GaugeSpecs` | List all spec files in the project via the quickfix list |

## LSP Features

The Gauge LSP server provides:

- **Completion** — step completions with trigger characters `*`, `"`, `<`, `:`, `,`
- **Go-to-definition** — jump to step implementations
- **Formatting** — auto-format spec files
- **Diagnostics** — inline errors and warnings
- **Document/workspace symbols** — navigate specs and scenarios
- **Code actions** — quick fixes
- **Rename** — rename steps across the project

## Health Check

Run `:checkhealth gauge` to verify the plugin is set up correctly.

## File Types

| Extension | Filetype |
|-----------|----------|
| `.spec` | `gauge` |
| `.cpt` | `gauge_concept` |
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with installation and usage

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```
