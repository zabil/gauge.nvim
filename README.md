# gauge.nvim

Neovim plugin for [Gauge](https://gauge.org/) — wires the Gauge LSP server to
`.spec` and `.cpt` files using Neovim's native LSP client. Zero external
dependencies.

## Features

- **LSP auto-attach** — completion, diagnostics, go-to-definition, formatting,
  rename, code actions, and document/workspace symbols out of the box
- **`:GaugeRun`** — run the current spec or the nearest scenario under the
  cursor in a split terminal
- **`:GaugeSpecs`** — list every spec file in the project via the quickfix list
- **`:checkhealth gauge`** — verify your setup at a glance
- No nvim-lspconfig required — uses `vim.lsp` directly

## Requirements

- Neovim >= 0.10
- [`gauge`](https://gauge.org/get-started/) on your `$PATH`

## Installation

### pack (built-in, no plugin manager needed)

```bash
git clone https://github.com/zabil/gauge.nvim \
  ~/.config/nvim/pack/plugins/start/gauge.nvim
```

Then add to your `~/.config/nvim/init.lua`:

```lua
require('gauge').setup()
```

### lazy.nvim

```lua
{
  'zabil/gauge.nvim',
  ft = { 'gauge', 'gauge_concept' },
  config = function()
    require('gauge').setup()
  end,
}
```

### mini.deps / vim.pack.add

```lua
vim.pack.add('https://github.com/zabil/gauge.nvim')
require('gauge').setup()
```

## Configuration

All options are optional — `setup({})` and `setup()` both work:

```lua
require('gauge').setup({
  -- Override the LSP server command.
  -- Default: { 'gauge', 'daemon', '--lsp', '--dir', <project-root> }
  -- The default detects the root (manifest.json) per-project at attach time.
  -- cmd = { 'gauge', 'daemon', '--lsp', '--dir', '/path/to/project' },

  -- Called after the LSP client attaches to a buffer — use it for keymaps,
  -- inlay hints, or any per-buffer setup.
  on_attach = function(client, bufnr)
    local map = function(key, cmd, desc)
      vim.keymap.set('n', key, cmd, { buffer = bufnr, silent = true, desc = desc })
    end
    map('<leader>Gr', '<cmd>GaugeRun<cr>',   'Gauge: run spec/scenario')
    map('<leader>Gs', '<cmd>GaugeSpecs<cr>', 'Gauge: list specs')
  end,

  -- Merge extra LSP client capabilities (e.g. from nvim-cmp or blink.cmp).
  -- capabilities = require('cmp_nvim_lsp').default_capabilities(),

  -- LSP workspace settings forwarded to the server.
  settings = {},

  -- Set true to enable built-in keymaps <leader>gr / <leader>gs in gauge buffers.
  -- Prefer on_attach above if you need a different prefix.
  keymaps = false,
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:GaugeRun` | Run the current `.spec` file, or the nearest `## Scenario` under the cursor |
| `:GaugeSpecs` | List all spec files in the project (opens quickfix) |
| `:GaugeSymbols` | Search specs and scenarios by name across the whole project |

> **Note:** `:GaugeSymbols` prompts for a query. The Gauge LSP server requires
> at least 2 characters — shorter queries silently return nothing, which is why
> plain `vim.lsp.buf.workspace_symbol()` appears to produce no results.

Output from `:GaugeRun` appears in a reusable horizontal split terminal.
The previous run's buffer (and its process) is cleaned up automatically.

## LSP Features

All features are provided by the Gauge language server (`gauge daemon --lsp`),
which ships inside the `gauge` binary:

| Feature | Details |
|---------|---------|
| Completion | Step completions; triggers on `*`, `"`, `<`, `:`, `,` |
| Go-to-definition | Jump from a step call to its implementation |
| Diagnostics | Inline errors and warnings as you type |
| Formatting | `gq` / `:Format` auto-formats spec files |
| Code actions | Quick-fix suggestions |
| Rename | Rename a step and all its usages across the project |
| Document symbols | Navigate scenarios and steps in the current file |
| Workspace symbols | Search across the whole project |

## Health Check

```
:checkhealth gauge
```

Checks Neovim version, `gauge` binary availability, whether `setup()` has been
called, and the number of currently active LSP clients.

## File Types

| Extension | Filetype |
|-----------|----------|
| `.spec` | `gauge` |
| `.cpt` | `gauge_concept` |

Filetype detection runs automatically on load — no `setup()` call required for
syntax highlighting alone.

## How It Works

1. `plugin/gauge.lua` registers `.spec` → `gauge` and `.cpt` → `gauge_concept`
   filetypes via `vim.filetype.add()` at startup.
2. `setup()` registers a `FileType` autocmd that calls `vim.lsp.start()` for
   every gauge buffer, starting `gauge daemon --lsp --dir <root>` once per
   project root (detected by walking up to `manifest.json`).
3. `:GaugeRun` shells out to `gauge run <file>[:<line>]`; `:GaugeSpecs` calls
   the custom `gauge/specs` LSP method and feeds the result into the quickfix
   list.

## License

Apache 2.0 — same as the Gauge project itself.

