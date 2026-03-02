local Job = require('plenary.job')
local logger = require('core.logger')

local M = {}

local function auth_env(host)
  if host.password_env then
    return os.getenv(host.password_env)
  end
  return host.password
end

local function sanitize_output(lines)
  local cleaned = {}
  for _, line in ipairs(lines or {}) do
    if line and line ~= '' and not line:match('^sftp>') and not line:match('^Connected to') then
      table.insert(cleaned, line)
    end
  end
  return cleaned
end

local function remote_quote(path)
  return '"' .. tostring(path):gsub('"', '\\"') .. '"'
end

local function sftp_command(host, batch_cmd, cb)
  local args = {
    '-P', tostring(host.port or 22),
  }

  if host.ssh_key then
    table.insert(args, '-i')
    table.insert(args, vim.fn.expand(host.ssh_key))
  end

  table.insert(args, string.format('%s@%s', host.user, host.host))

  local command = 'sftp'
  local env = nil
  if host.password or host.password_env then
    command = 'sshpass'
    env = { SSHPASS = auth_env(host) }
    args = vim.list_extend({ '-e', 'sftp' }, args)
  end

  Job:new({
    command = command,
    args = args,
    env = env,
    writer = { batch_cmd, 'quit' },
    on_exit = function(j, code)
      if code == 0 then
        cb(true, sanitize_output(j:result()))
      else
        cb(false, sanitize_output(j:stderr_result()))
      end
    end,
  }):start()
end

function M.upload(host, local_path, remote_path, cb)
  sftp_command(host, string.format('put %s %s', remote_quote(local_path), remote_quote(remote_path)), function(ok, out)
    if ok then logger.info('Upload ' .. local_path .. ' -> ' .. remote_path) end
    cb(ok, out)
  end)
end

function M.download(host, remote_path, local_path, cb)
  sftp_command(host, string.format('get %s %s', remote_quote(remote_path), remote_quote(local_path)), function(ok, out)
    if ok then logger.info('Download ' .. remote_path .. ' -> ' .. local_path) end
    cb(ok, out)
  end)
end

function M.list(host, remote_path, cb)
  sftp_command(host, string.format('ls -1p %s', remote_quote(remote_path)), function(ok, out)
    local files = {}
    for _, line in ipairs(out or {}) do
      if line and line ~= '' then
        table.insert(files, vim.trim(line))
      end
    end
    cb(ok, files)
  end)
end

function M.stat(host, remote_path, cb)
  local ssh = require('transport.ssh')
  local stat_cmd = string.format('stat -c %%Y %s 2>/dev/null || stat -f %%m %s 2>/dev/null', remote_quote(remote_path), remote_quote(remote_path))
  ssh.run(host, stat_cmd, function(ok, output)
    if not ok then
      cb(false, nil)
      return
    end

    local mtime = tonumber((output or ''):match('(%d+)'))
    cb(true, { mtime = mtime or 0 })
  end)
end

return M
