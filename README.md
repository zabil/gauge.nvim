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
  -- Only override if you need a non-standard project path.
  -- The default automatically detects the per-project root at attach time.
  -- cmd = { 'gauge', 'daemon', '--lsp', '--dir', '/absolute/path/to/project' },

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
