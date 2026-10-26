return function(t)
  local commands = require('gauge.commands')
  require('gauge.ft').setup()

  -- Run :GaugeRun with termopen stubbed; returns captured { cmd, cwd }.
  local function run_at(path, line)
    local captured
    local orig = vim.fn.termopen
    vim.fn.termopen = function(cmd, opts)
      captured = { cmd = cmd, cwd = opts.cwd }
      return 1
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(path))
    vim.bo.filetype = 'gauge'
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    local ok, err = pcall(commands.run)
    vim.fn.termopen = orig
    assert(ok, err)
    return captured
  end

  local manifest = '{"Language":"js"}'
  local spec = '# Spec\n\n## First\n* step\n\n## Second\n* step'

  t.test('GaugeRun: runs from nested project root with scenario line', function()
    local base = t.tree({
      ['manifest.json'] = manifest,
      ['pkg/manifest.json'] = manifest,
      ['pkg/specs/a.spec'] = spec,
    })
    local path = base .. '/pkg/specs/a.spec'
    local got = run_at(path, 7)
    t.truthy(got, 'termopen was not called')
    t.eq(base .. '/pkg', got.cwd)
    t.eq('gauge run ' .. vim.fn.shellescape(path) .. ':6', got.cmd)
  end)

  t.test('GaugeRun: no scenario above cursor runs whole spec', function()
    local base = t.tree({ ['manifest.json'] = manifest, ['specs/a.spec'] = spec })
    local path = base .. '/specs/a.spec'
    local got = run_at(path, 1)
    t.eq('gauge run ' .. vim.fn.shellescape(path), got.cmd)
  end)

  t.test('GaugeRun: does not run outside a gauge project', function()
    local base = t.tree({ ['specs/a.spec'] = spec })
    t.eq(nil, run_at(base .. '/specs/a.spec', 3))
  end)
end
