local Job = require('plenary.job')
local logger = require('core.logger')

local M = {}

local function auth_env(host)
  if host.password_env then
    return os.getenv(host.password_env)
  end
  return host.password
end

local function build_ssh(host)
  local args = { 'ssh', '-p', tostring(host.port or 22) }
  if host.ssh_key then
    table.insert(args, '-i')
    table.insert(args, vim.fn.expand(host.ssh_key))
  end
  return table.concat(args, ' ')
end

local function run(host, source, target, excludes, dry_run, cb)
  local args = { '--archive', '--delete', '--checksum', '-e', build_ssh(host) }
  if dry_run then
    table.insert(args, '--dry-run')
  end

  for _, pattern in ipairs(excludes or {}) do
    table.insert(args, '--exclude')
    table.insert(args, pattern)
  end

  table.insert(args, source)
  table.insert(args, target)

  local command = 'rsync'
  local env = nil
  if host.password or host.password_env then
    command = 'sshpass'
    env = { SSHPASS = auth_env(host) }
    args = vim.list_extend({ '-e', 'rsync' }, args)
  end

  Job:new({
    command = command,
    args = args,
    env = env,
    on_exit = function(j, code)
      local output = vim.list_extend(j:result(), j:stderr_result())
      cb(code == 0, output)
    end,
  }):start()
end

function M.sync(host, local_root, dry_run, cb)
  local src = local_root .. '/'
  local dst = string.format('%s@%s:%s/', host.user, host.host, host.remote_path)
  run(host, src, dst, host.excludes_local, dry_run, function(ok, output)
    logger.info('RemoteSync ' .. (ok and 'completed' or 'failed'))
    cb(ok, output)
  end)
end

function M.push(host, local_dir, cb)
  local src = local_dir .. '/'
  local dst = string.format('%s@%s:%s/', host.user, host.host, host.remote_path)
  run(host, src, dst, host.excludes_local, false, cb)
end

function M.fetch(host, local_dir, cb)
  local src = string.format('%s@%s:%s/', host.user, host.host, host.remote_path)
  local dst = local_dir .. '/'
  run(host, src, dst, host.excludes_remote, false, cb)
end

return M
