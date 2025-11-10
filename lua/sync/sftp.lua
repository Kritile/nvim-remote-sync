local M = {}
local utils = require('core.utils')

local function build_sftp_command(host, command)
  local auth = ''
  
  if host.password and not host.password:match('^/') then
    -- Password authentication
    auth = string.format('sshpass -p "%s" ', host.password)
  end
  
  local port = host.port or 22
  local ssh_opts = '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
  
  if host.password and host.password:match('^/') then
    -- SSH key authentication
    ssh_opts = ssh_opts .. ' -i ' .. host.password
  end
  
  return string.format('%ssftp -P %d %s %s@%s',
    auth, port, ssh_opts, host.user, host.host)
end

function M.connect(host)
  utils.log('Testing SFTP connection to ' .. host.name)
  
  local cmd = build_sftp_command(host, '') .. ' <<EOF\nbye\nEOF'
  
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
  -- SFTP doesn't maintain persistent connections in this implementation
  return true
end

function M.upload(host, local_path, remote_path)
  local remote_dir = remote_path:match('(.*/)')
  
  local cmd = build_sftp_command(host, '') .. string.format(
    ' <<EOF\n-mkdir %s\nput "%s" "%s"\nbye\nEOF',
    remote_dir or host.path,
    local_path,
    remote_path
  )
  
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
  -- Create local directory if needed
  local local_dir = local_path:match('(.*/)')
  if local_dir then
    utils.mkdir(local_dir)
  end
  
  local cmd = build_sftp_command(host, '') .. string.format(
    ' <<EOF\nget "%s" "%s"\nbye\nEOF',
    remote_path,
    local_path
  )
  
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
  local cmd = build_sftp_command(host, '') .. string.format(
    ' <<EOF\nls -la "%s"\nbye\nEOF',
    remote_path or host.path
  )
  
  local files = {}
  utils.execute(cmd, function(ok, output)
    if ok and output then
      for line in output:gmatch('[^\r\n]+') do
        local file = line:match('%S+$')
        if file and file ~= '.' and file ~= '..' then
          table.insert(files, file)
        end
      end
    end
  end)
  
  return files
end

function M.sync(host, local_dir, remote_dir)
  -- Use rsync over ssh for directory sync
  local port = host.port or 22
  local auth = ''
  
  if host.password and host.password:match('^/') then
    auth = '-e "ssh -i ' .. host.password .. '"'
  end
  
  local excludes = ''
  if host.excludes_local then
    for _, pattern in ipairs(host.excludes_local) do
      excludes = excludes .. ' --exclude="' .. pattern .. '"'
    end
  end
  
  local cmd = string.format(
    'rsync -avz %s %s "%s/" %s@%s:"%s/"',
    auth, excludes, local_dir, host.user, host.host, remote_dir
  )
  
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
