local state = require('core.state')
local logger = require('core.logger')
local sftp = require('transport.sftp')

local M = {}

local function excluded(path, patterns)
  for _, pattern in ipairs(patterns or {}) do
    local lua_pattern = pattern:gsub('([%%%^%$%(%)%.%[%]%+%-%?])', '%%%1'):gsub('%*', '.*')
    if path:match(lua_pattern) then
      return true
    end
  end
  return false
end

local function remote_path_for(host, local_path)
  local cwd = vim.fn.getcwd()
  local relative = local_path:gsub('^' .. vim.pesc(cwd .. '/'), '')
  return host.remote_path:gsub('/$', '') .. '/' .. relative
end

local function show_diff(local_path, remote_path, host)
  local tmp = vim.fn.tempname()
  sftp.download(host, remote_path, tmp, function(ok)
    if not ok then
      logger.error('Failed to download remote file for diff.')
      return
    end

    vim.schedule(function()
      vim.cmd('edit ' .. vim.fn.fnameescape(local_path))
      vim.cmd('vsplit ' .. vim.fn.fnameescape(tmp))
      vim.cmd('wincmd l | diffthis')
      vim.cmd('wincmd h | diffthis')
      vim.api.nvim_create_autocmd('VimLeavePre', {
        once = true,
        callback = function()
          pcall(vim.fn.delete, tmp)
        end,
      })
    end)
  end)
end

local function handle_save(local_path)
  local host = state.get_active_host()
  if not host then
    return
  end

  local relative = local_path:gsub('^' .. vim.pesc(vim.fn.getcwd() .. '/'), '')
  if excluded(relative, host.excludes_local) then
    return
  end

  local remote_path = remote_path_for(host, local_path)
  local local_stat = vim.loop.fs_stat(local_path)
  local local_mtime = local_stat and local_stat.mtime.sec or 0

  sftp.stat(host, remote_path, function(stat_ok, remote_stat)
    if stat_ok and remote_stat and remote_stat.mtime > local_mtime then
      vim.schedule(function()
        vim.ui.select({ 'Cancel', 'Overwrite remote', 'Show diff' }, { prompt = 'Remote file is newer:' }, function(choice)
          if choice == 'Overwrite remote' then
            sftp.upload(host, local_path, remote_path, function(ok)
              logger.info(ok and 'Auto-upload completed.' or 'Auto-upload failed.')
            end)
          elseif choice == 'Show diff' then
            show_diff(local_path, remote_path, host)
          end
        end)
      end)
      return
    end

    sftp.upload(host, local_path, remote_path, function(ok)
      logger.info(ok and ('Uploaded ' .. relative) or ('Upload failed ' .. relative))
    end)
  end)
end

function M.enable()
  vim.api.nvim_create_augroup('RemoteHostsSyncWatcher', { clear = true })
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = 'RemoteHostsSyncWatcher',
    callback = function(args)
      handle_save(args.file)
    end,
  })
end

return M
