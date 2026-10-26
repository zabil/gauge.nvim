return function(t)
  require('gauge.ft').setup()

  t.test('filetype: .spec is gauge', function()
    t.eq('gauge', vim.filetype.match({ filename = 'x/a.spec' }))
  end)

  t.test('filetype: .cpt is gauge_concept', function()
    t.eq('gauge_concept', vim.filetype.match({ filename = 'x/a.cpt' }))
  end)
end
