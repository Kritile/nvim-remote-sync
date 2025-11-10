local M = {}
local utils = require('core.utils')

local function build_scp_base(host)
  local port = host.port or 22
  local ssh_opts = '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
  
  if host.password and host.password:match('^/') then
    -- SSH key authentication
    ssh_opts = ssh_opts .. ' -i ' .. host.password
  end
  
  return string.format('scp -P %d %s', port, ssh_opts)
end

local function build_ssh_command(host, command)
  local port = host.port or 22
  local ssh_opts = '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
  
  if host.password and host.password:match('^/') then
    ssh_opts = ssh_opts .. ' -i ' .. host.password
  end
  
  return string.format('ssh -p %d %s %s@%s "%s"',
    port, ssh_opts, host.user, host.host, command)
end

function M.connect(host)
  utils.log('Testing SCP connection to ' .. host.name)
  
  -- Test connection with a simple SSH command
  local cmd = build_ssh_command(host, 'echo "Connection test"')
  
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
  -- SCP doesn't maintain persistent connections
  return true
end

function M.upload(host, local_path, remote_path)
  -- Ensure remote directory exists
  local remote_dir = remote_path:match('(.*/)')
  if remote_dir then
    local mkdir_cmd = build_ssh_command(host, 'mkdir -p ' .. remote_dir)
    utils.execute(mkdir_cmd, function() end)
  end
  
  local scp_base = build_scp_base(host)
  local cmd = string.format('%s "%s" %s@%s:"%s"',
    scp_base, local_path, host.user, host.host, remote_path)
  
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
  
  local scp_base = build_scp_base(host)
  local cmd = string.format('%s %s@%s:"%s" "%s"',
    scp_base, host.user, host.host, remote_path, local_path)
  
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
  local cmd = build_ssh_command(host, 'ls -1 "' .. (remote_path or host.path) .. '"')
  
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
  -- SCP doesn't have native sync, use rsync over SSH instead
  local port = host.port or 22
  local ssh_opts = string.format('-e "ssh -p %d -o StrictHostKeyChecking=no', port)
  
  if host.password and host.password:match('^/') then
    ssh_opts = ssh_opts .. ' -i ' .. host.password
  end
  
  ssh_opts = ssh_opts .. '"'
  
  local excludes = ''
  if host.excludes_local then
    for _, pattern in ipairs(host.excludes_local) do
      excludes = excludes .. ' --exclude="' .. pattern .. '"'
    end
  end
  
  -- Ensure trailing slashes
  if not local_dir:match('/$') then
    local_dir = local_dir .. '/'
  end
  if not remote_dir:match('/$') then
    remote_dir = remote_dir .. '/'
  end
  
  local cmd = string.format(
    'rsync -avz %s %s "%s" %s@%s:"%s"',
    ssh_opts, excludes, local_dir, host.user, host.host, remote_dir
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

-- Batch upload multiple files (more efficient than individual uploads)
function M.upload_batch(host, file_pairs)
  local temp_script = '/tmp/scp_upload_' .. os.time() .. '.sh'
  local script_lines = {'#!/bin/bash', 'set -e'}
  
  local scp_base = build_scp_base(host)
  
  for _, pair in ipairs(file_pairs) do
    local local_path = pair.local_path
    local remote_path = pair.remote_path
    local remote_dir = remote_path:match('(.*/)')
    
    if remote_dir then
      table.insert(script_lines, build_ssh_command(host, 'mkdir -p ' .. remote_dir))
    end
    
    table.insert(script_lines, string.format('%s "%s" %s@%s:"%s"',
      scp_base, local_path, host.user, host.host, remote_path))
  end
  
  local file = io.open(temp_script, 'w')
  if file then
    file:write(table.concat(script_lines, '\n'))
    file:close()
    
    local cmd = 'bash ' .. temp_script
    local success = false
    
    utils.execute(cmd, function(ok, output)
      success = ok
      os.remove(temp_script)
      
      if ok then
        vim.notify('Batch upload completed', vim.log.levels.INFO)
      else
        utils.log('Batch upload failed: ' .. (output or ''), vim.log.levels.ERROR)
      end
    end)
    
    return success
  end
  
  return false
end

return M
