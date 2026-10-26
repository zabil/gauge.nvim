return function(t)
  local lsp = require('gauge.lsp')

  local function root_of(path)
    vim.cmd('edit ' .. vim.fn.fnameescape(path))
    return lsp.find_root(vim.api.nvim_get_current_buf())
  end

  local gauge_manifest = '{"Language":"java","Plugins":[]}'

  t.test('find_root: single project', function()
    local base = t.tree({
      ['manifest.json'] = gauge_manifest,
      ['specs/a.spec'] = '# A',
    })
    t.eq(base, root_of(base .. '/specs/a.spec'))
  end)

  t.test('find_root: nearest of nested projects wins', function()
    local base = t.tree({
      ['manifest.json'] = gauge_manifest,
      ['services/api/manifest.json'] = gauge_manifest,
      ['services/api/specs/a.spec'] = '# A',
      ['specs/b.spec'] = '# B',
    })
    t.eq(base .. '/services/api', root_of(base .. '/services/api/specs/a.spec'))
    t.eq(base, root_of(base .. '/specs/b.spec'))
  end)

  t.test('find_root: sibling projects resolve independently', function()
    local base = t.tree({
      ['one/manifest.json'] = gauge_manifest,
      ['one/specs/a.spec'] = '# A',
      ['two/manifest.json'] = gauge_manifest,
      ['two/specs/b.spec'] = '# B',
    })
    t.eq(base .. '/one', root_of(base .. '/one/specs/a.spec'))
    t.eq(base .. '/two', root_of(base .. '/two/specs/b.spec'))
  end)

  t.test('find_root: skips non-gauge manifest.json', function()
    local base = t.tree({
      ['manifest.json'] = gauge_manifest,
      ['web/manifest.json'] = '{"name":"pwa"}',
      ['web/specs/a.spec'] = '# A',
    })
    t.eq(base, root_of(base .. '/web/specs/a.spec'))
  end)

  t.test('find_root: skips invalid json manifest', function()
    local base = t.tree({
      ['manifest.json'] = gauge_manifest,
      ['bad/manifest.json'] = 'not json {',
      ['bad/a.spec'] = '# A',
    })
    t.eq(base, root_of(base .. '/bad/a.spec'))
  end)

  t.test('find_root: nil when no gauge project', function()
    local base = t.tree({ ['specs/a.spec'] = '# A' })
    t.eq(nil, root_of(base .. '/specs/a.spec'))
  end)

  t.test('find_root: nil for unnamed buffer', function()
    vim.cmd('enew')
    t.eq(nil, lsp.find_root(vim.api.nvim_get_current_buf()))
  end)
end
