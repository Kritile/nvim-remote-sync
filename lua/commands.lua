local M = {}

local manager = require('sync.manager')
local tree = require('tui.tree')
local hosts = require('tui.hosts')
local config = require('core.config')
local utils = require('core.utils')
local diff = require('core.diff')
local watcher = require('core.watcher')

function M.setup()
  -- RemoteOpenTree: Open remote file tree
  vim.api.nvim_create_user_command('RemoteOpenTree', function(opts)
    local host_name = opts.args
    
    if host_name and host_name ~= '' then
      local host = config.get_host_by_name(host_name)
      if host then
        tree.open(host)
      else
        vim.notify('Host not found: ' .. host_name, vim.log.levels.ERROR)
      end
    else
      -- Show host selector
      hosts.show_hosts()
    end
  end, { nargs = '?', desc = 'Open remote file tree' })
  
  -- RemoteCloseTree: Close remote file tree
  vim.api.nvim_create_user_command('RemoteCloseTree', function()
    tree.close()
  end, { desc = 'Close remote file tree' })
  
  -- RemoteUpload: Upload file to remote server
  vim.api.nvim_create_user_command('RemoteUpload', function(opts)
    local host = manager.get_current_host()
    if not host then
      vim.notify('No host selected. Use :RemoteOpenTree first', vim.log.levels.ERROR)
      return
    end
    
    local local_path = opts.args
    if not local_path or local_path == '' then
      local_path = utils.get_current_file()
    end
    
    if not local_path or local_path == '' then
      vim.notify('No file specified', vim.log.levels.ERROR)
      return
    end
    
    local relative_path = utils.relative_path(local_path)
    local remote_path = utils.join_path(host.path, relative_path)
    
    manager.upload(local_path, remote_path, host)
  end, { nargs = '?', desc = 'Upload file to remote server', complete = 'file' })
  
  -- RemoteDownload: Download file from remote server
  vim.api.nvim_create_user_command('RemoteDownload', function(opts)
    local host = manager.get_current_host()
    if not host then
      vim.notify('No host selected. Use :RemoteOpenTree first', vim.log.levels.ERROR)
      return
    end
    
    local remote_path = opts.args
    if not remote_path or remote_path == '' then
      vim.notify('Please specify remote path', vim.log.levels.ERROR)
      return
    end
    
    local filename = remote_path:match('[^/]+$')
    local local_path = utils.join_path(vim.fn.getcwd(), filename)
    
    manager.download(remote_path, local_path, host)
  end, { nargs = 1, desc = 'Download file from remote server' })
  
  -- RemoteSync: Sync changed files with server
  vim.api.nvim_create_user_command('RemoteSync', function()
    local host = manager.get_current_host()
    if not host then
      vim.notify('No host selected. Use :RemoteOpenTree first', vim.log.levels.ERROR)
      return
    end
    
    local current_file = utils.get_current_file()
    if not current_file or current_file == '' then
      vim.notify('No file to sync', vim.log.levels.ERROR)
      return
    end
    
    local relative_path = utils.relative_path(current_file)
    local remote_path = utils.join_path(host.path, relative_path)
    
    manager.upload(current_file, remote_path, host)
  end, { desc = 'Sync current file with server' })
  
  -- RemoteFetch: Download all files from directory
  vim.api.nvim_create_user_command('RemoteFetch', function(opts)
    local host = manager.get_current_host()
    if not host then
      vim.notify('No host selected. Use :RemoteOpenTree first', vim.log.levels.ERROR)
      return
    end
    
    local remote_dir = opts.args
    if not remote_dir or remote_dir == '' then
      remote_dir = host.path
    end
    
    local local_dir = vim.fn.getcwd()
    
    manager.sync_directory(local_dir, remote_dir, host)
  end, { nargs = '?', desc = 'Download all files from directory' })
  
  -- RemotePush: Upload all files to server
  vim.api.nvim_create_user_command('RemotePush', function(opts)
    local host = manager.get_current_host()
    if not host then
      vim.notify('No host selected. Use :RemoteOpenTree first', vim.log.levels.ERROR)
      return
    end
    
    local local_dir = opts.args
    if not local_dir or local_dir == '' then
      local_dir = vim.fn.getcwd()
    end
    
    local remote_dir = host.path
    
    manager.sync_directory(local_dir, remote_dir, host)
  end, { nargs = '?', desc = 'Upload all files to server', complete = 'dir' })
  
  -- RemoteHosts: Show host management interface
  vim.api.nvim_create_user_command('RemoteHosts', function()
    hosts.show_hosts()
  end, { desc = 'Show remote hosts' })
  
  -- RemoteAddHost: Add new host
  vim.api.nvim_create_user_command('RemoteAddHost', function()
    hosts.add_host()
  end, { desc = 'Add new remote host' })
  
  -- RemoteDisconnect: Disconnect from current host
  vim.api.nvim_create_user_command('RemoteDisconnect', function()
    local host = manager.get_current_host()
    if host then
      manager.disconnect(host)
      manager.set_current_host(nil)
      vim.notify('Disconnected from ' .. host.name, vim.log.levels.INFO)
    end
  end, { desc = 'Disconnect from current host' })
  
  -- RemoteDiff: Show diff between local and remote file
  vim.api.nvim_create_user_command('RemoteDiff', function()
    diff.diff_current_file()
  end, { desc = 'Compare current file with remote version' })
  
  -- RemoteDiffPreview: Show diff in floating window
  vim.api.nvim_create_user_command('RemoteDiffPreview', function()
    local host = manager.get_current_host()
    if not host then
      vim.notify('No host selected. Use :RemoteOpenTree first', vim.log.levels.ERROR)
      return
    end
    
    local local_path = utils.get_current_file()
    if not local_path or local_path == '' then
      vim.notify('No file to compare', vim.log.levels.ERROR)
      return
    end
    
    local relative_path = utils.relative_path(local_path)
    local remote_path = utils.join_path(host.path, relative_path)
    
    diff.show_diff_preview(local_path, remote_path, host)
  end, { desc = 'Show diff preview in floating window' })
  
  -- RemoteWatchStart: Start background file watcher
  vim.api.nvim_create_user_command('RemoteWatchStart', function(opts)
    local interval = tonumber(opts.args)
    watcher.start(interval)
  end, { nargs = '?', desc = 'Start background file synchronization' })
  
  -- RemoteWatchStop: Stop background file watcher
  vim.api.nvim_create_user_command('RemoteWatchStop', function()
    watcher.stop()
  end, { desc = 'Stop background file synchronization' })
  
  -- RemoteWatchToggle: Toggle background file watcher
  vim.api.nvim_create_user_command('RemoteWatchToggle', function(opts)
    local interval = tonumber(opts.args)
    watcher.toggle(interval)
  end, { nargs = '?', desc = 'Toggle background file synchronization' })
  
  -- RemoteWatchStatus: Show watcher status
  vim.api.nvim_create_user_command('RemoteWatchStatus', function()
    local stats = watcher.get_stats()
    local status = string.format(
      'Watcher: %s\nInterval: %dms\nQueue: %d files\nTracked: %d files',
      stats.enabled and 'Running' or 'Stopped',
      stats.interval,
      stats.queue_size,
      stats.tracked_files
    )
    vim.notify(status, vim.log.levels.INFO)
  end, { desc = 'Show background sync status' })
end

return M
