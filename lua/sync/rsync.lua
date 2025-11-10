local M = {}
local utils = require('core.utils')

local function build_rsync_command(host, local_path, remote_path, options)
  options = options or '-avz'
  
  local port = host.port or 22
  local ssh_opts = string.format('-e "ssh -p %d', port)
  
  if host.password and host.password:match('^/') then
    -- SSH key authentication
    ssh_opts = ssh_opts .. ' -i ' .. host.password
  end
  
  ssh_opts = ssh_opts .. ' -o StrictHostKeyChecking=no"'
  
  local excludes = ''
  if host.excludes_local then
    for _, pattern in ipairs(host.excludes_local) do
      excludes = excludes .. ' --exclude="' .. pattern .. '"'
    end
  end
  
  local remote = string.format('%s@%s:%s', host.user, host.host, remote_path)
  
  return string.format('rsync %s %s %s "%s" %s',
    options, ssh_opts, excludes, local_path, remote)
end

function M.connect(host)
  utils.log('Testing rsync connection to ' .. host.name)
  
  -- Test with a simple dry-run
  local cmd = string.format(
    'rsync -e "ssh -p %d -o StrictHostKeyChecking=no" --dry-run %s@%s:%s .',
    host.port or 22,
    host.user,
    host.host,
    host.path
  )
  
  local success = false
  utils.execute(cmd, function(ok, output)
    success = ok
    if ok then
      utils.log('Successfully connected to ' .. host.name)
    else
      utils.log('Failed to connect to ' .. host.name .. ': ' .. (output or ''), vim.log.levels.ERROR)
    end
  end)
  
  return success
end

function M.disconnect(host)
  return true
end

function M.upload(host, local_path, remote_path)
  local cmd = build_rsync_command(host, local_path, remote_path)
  
  local success = false
  utils.execute(cmd, function(ok, output)
    success = ok
    if ok then
      vim.notify('Uploaded: ' .. local_path, vim.log.levels.INFO)
    else
      utils.log('Upload failed: ' .. (output or ''), vim.log.levels.ERROR)
    end
  end)
  
  return success
end

function M.download(host, remote_path, local_path)
  local local_dir = local_path:match('(.*/)')
  if local_dir then
    utils.mkdir(local_dir)
  end
  
  local port = host.port or 22
  local ssh_opts = string.format('-e "ssh -p %d -o StrictHostKeyChecking=no"', port)
  
  if host.password and host.password:match('^/') then
    ssh_opts = string.format('-e "ssh -p %d -i %s -o StrictHostKeyChecking=no"',
      port, host.password)
  end
  
  local remote = string.format('%s@%s:%s', host.user, host.host, remote_path)
  local cmd = string.format('rsync -avz %s %s "%s"', ssh_opts, remote, local_path)
  
  local success = false
  utils.execute(cmd, function(ok, output)
    success = ok
    if ok then
      vim.notify('Downloaded: ' .. remote_path, vim.log.levels.INFO)
    else
      utils.log('Download failed: ' .. (output or ''), vim.log.levels.ERROR)
    end
  end)
  
  return success
end

function M.list(host, remote_path)
  local port = host.port or 22
  local cmd = string.format(
    'ssh -p %d -o StrictHostKeyChecking=no %s@%s "ls -1 %s"',
    port,
    host.user,
    host.host,
    remote_path or host.path
  )
  
  local files = {}
  utils.execute(cmd, function(ok, output)
    if ok and output then
      for line in output:gmatch('[^\r\n]+') do
        local file = line:match('^%s*(.-)%s*$')
        if file and file ~= '' and file ~= '.' and file ~= '..' then
          table.insert(files, file)
        end
      end
    end
  end)
  
  return files
end

function M.sync(host, local_dir, remote_dir)
  -- Ensure trailing slashes for directory sync
  if not local_dir:match('/$') then
    local_dir = local_dir .. '/'
  end
  if not remote_dir:match('/$') then
    remote_dir = remote_dir .. '/'
  end
  
  local cmd = build_rsync_command(host, local_dir, remote_dir, '-avz --delete')
  
  local success = false
  utils.execute(cmd, function(ok, output)
    success = ok
    if ok then
      vim.notify('Synced: ' .. local_dir, vim.log.levels.INFO)
    else
      utils.log('Sync failed: ' .. (output or ''), vim.log.levels.ERROR)
    end
  end)
  
  return success
end

return M
