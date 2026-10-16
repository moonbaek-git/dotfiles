-- Entry point. Each piece lives in its own file under lua/.
--   lua/config/options.lua   core options and leader key
--   lua/config/keymaps.lua   keymaps, diagnostics, autocmds
--   lua/config/lazy.lua      lazy.nvim bootstrap
--   lua/plugins/*.lua        one file per plugin (or small group)
require 'config.options'
require 'config.keymaps'
require 'config.lazy'

-- vim: ts=2 sts=2 sw=2 et
