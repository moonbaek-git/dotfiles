return {
  {
    'sphamba/smear-cursor.nvim',
    event = 'VeryLazy',
    config = function()
      -- Animated cursor trail to make the cursor easier to follow
      require('smear_cursor').setup {}
    end,
  },
}
