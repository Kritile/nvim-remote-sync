local M = {}

local utils = require('core.utils')
local config = require('core.config')

local current_host = nil
local sync_providers = {
  sftp = require('sync.sftp'),
  ftp = require('sync.ftp'),
  rsync = require('sync.rsync'),
  scp = require('sync.scp'),
}

function M.set_current_host(host)
  current_host = host
  utils.log('Switched to host: ' .. (host and host.name or 'none'))
end

function M.get_current_host()
  return current_host
end

function M.get_provider(host)
  host = host or current_host
  if not host then
    utils.log('No host selected', vim.log.levels.ERROR)
    return nil
  end
  
  local provider = sync_providers[host.type]
  if not provider then
    utils.log('Unknown sync type: ' .. host.type, vim.log.levels.ERROR)
    return nil
  end
  
  return provider
end

function M.connect(host)
  local provider = M.get_provider(host)
  if not provider then
    return false
  end
  
  return provider.connect(host)
end

function M.disconnect(host)
  local provider = M.get_provider(host)
  if not provider then
    return false
  end
  
  return provider.disconnect(host)
end

function M.upload(local_path, remote_path, host)
  host = host or current_host
  if not host then
    vim.notify('No host selected', vim.log.levels.ERROR)
    return false
  end
  
  -- Check if file is excluded
  local relative_path = utils.relative_path(local_path)
  if utils.is_excluded(relative_path, host.excludes_local) then
    utils.log('Skipping excluded file: ' .. relative_path)
    return true
  end
  
  local provider = M.get_provider(host)
  if not provider then
    return false
  end
  
  utils.log('Uploading: ' .. local_path .. ' -> ' .. remote_path)
  return provider.upload(host, local_path, remote_path)
end

function M.download(remote_path, local_path, host)
  host = host or current_host
  if not host then
    vim.notify('No host selected', vim.log.levels.ERROR)
    return false
  end
  
  -- Check if file is excluded
  if utils.is_excluded(remote_path, host.excludes_remote) then
    utils.log('Skipping excluded file: ' .. remote_path)
    return true
  end
  
  local provider = M.get_provider(host)
  if not provider then
    return false
  end
  
  utils.log('Downloading: ' .. remote_path .. ' -> ' .. local_path)
  return provider.download(host, remote_path, local_path)
end

function M.list_remote(remote_path, host)
  host = host or current_host
  if not host then
    vim.notify('No host selected', vim.log.levels.ERROR)
    return nil
  end
  
  local provider = M.get_provider(host)
  if not provider then
    return nil
  end
  
  return provider.list(host, remote_path)
end

function M.auto_sync()
  if not current_host then
    return
  end
  
  local current_file = utils.get_current_file()
  if not current_file or current_file == '' then
    return
  end
  
  local relative_path = utils.relative_path(current_file)
  local remote_path = utils.join_path(current_host.path, relative_path)
  
  M.upload(current_file, remote_path, current_host)
end

function M.sync_directory(local_dir, remote_dir, host)
  host = host or current_host
  if not host then
    vim.notify('No host selected', vim.log.levels.ERROR)
    return false
  end
  
  local provider = M.get_provider(host)
  if not provider then
    return false
  end
  
  utils.log('Syncing directory: ' .. local_dir .. ' -> ' .. remote_dir)
  return provider.sync(host, local_dir, remote_dir)
end

return M
