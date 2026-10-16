return {
  {
    'folke/todo-comments.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      -- Highlight todo, notes, etc in comments
      require('todo-comments').setup { signs = false }
    end,
  },
}
