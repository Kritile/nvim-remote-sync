local M = {}

M.config = require('core.config')
M.utils = require('core.utils')

function M.setup(opts)
  opts = opts or {}
  M.config.setup(opts)
  
  -- Create autocommands for auto-sync
  if M.config.get('auto_sync') then
    vim.api.nvim_create_autocmd('BufWritePost', {
      pattern = '*',
      callback = function()
        require('sync.manager').auto_sync()
      end,
    })
  end
end

return M
