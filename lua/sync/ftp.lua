local M = {}
local utils = require('core.utils')

local function build_ftp_command(host, commands)
  local port = host.port or 21
  local auth = string.format('user %s %s', host.user, host.password or '')
  
  local cmd_string = table.concat({
    'open ' .. host.host .. ' ' .. port,
    auth,
    'binary',
    commands,
    'bye'
  }, '\n')
  
  return string.format('ftp -n <<EOF\n%s\nEOF', cmd_string)
end

function M.connect(host)
  utils.log('Testing FTP connection to ' .. host.name)
  
  local cmd = build_ftp_command(host, 'pwd')
  
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
  local commands = string.format('put "%s" "%s"', local_path, remote_path)
  local cmd = build_ftp_command(host, commands)
  
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
  
  local commands = string.format('get "%s" "%s"', remote_path, local_path)
  local cmd = build_ftp_command(host, commands)
  
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
  local commands = string.format('cd "%s"\nls', remote_path or host.path)
  local cmd = build_ftp_command(host, commands)
  
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
  -- FTP doesn't have native sync, use lftp if available
  local excludes = ''
  if host.excludes_local then
    for _, pattern in ipairs(host.excludes_local) do
      excludes = excludes .. ' --exclude "' .. pattern .. '"'
    end
  end
  
  local cmd = string.format(
    'lftp -u %s,%s -e "mirror -R %s %s %s; bye" %s',
    host.user,
    host.password or '',
    excludes,
    local_dir,
    remote_dir,
    host.host
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
