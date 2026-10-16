return {
  {
    'mikavilpas/yazi.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = 'Yazi',
    keys = {
      { '<leader>-', '<cmd>Yazi<cr>', mode = { 'n', 'v' }, desc = 'Open yazi at the current file' },
      { '<leader>cw', '<cmd>Yazi cwd<cr>', desc = "Open yazi in nvim's working directory" },
    },
    opts = {
      open_for_directories = false,
    },
  },
}
