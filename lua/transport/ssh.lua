local Job = require('plenary.job')
local logger = require('core.logger')
local state = require('core.state')

local M = {}
local reconnect_timer = nil
local heartbeat_timer = nil

local function auth_env(host)
  if host.password_env then
    return os.getenv(host.password_env)
  end
  return host.password
end

function M.ssh_args(host)
  local args = {
    '-p', tostring(host.port or 22),
    '-o', 'ServerAliveInterval=15',
    '-o', 'ServerAliveCountMax=3',
  }

  if host.ssh_key then
    table.insert(args, '-i')
    table.insert(args, vim.fn.expand(host.ssh_key))
  end

  table.insert(args, string.format('%s@%s', host.user, host.host))
  return args
end

function M.run(host, remote_cmd, cb)
  local args = M.ssh_args(host)
  table.insert(args, remote_cmd)

  local command = 'ssh'
  local env = nil
  if host.password or host.password_env then
    command = 'sshpass'
    env = { SSHPASS = auth_env(host) }
    table.insert(args, 1, '-e')
    table.insert(args, 2, 'ssh')
  end

  Job:new({
    command = command,
    args = args,
    env = env,
    on_exit = function(j, code)
      if code == 0 then
        cb(true, table.concat(j:result(), '\n'))
      else
        cb(false, table.concat(j:stderr_result(), '\n'))
      end
    end,
  }):start()
end

function M.connect(host, cb)
  state.update_connection({ status = 'connecting', last_error = nil })
  M.run(host, 'echo remote_hosts_sync_connected', function(ok, out)
    if ok then
      state.update_connection({ status = 'connected', retries = 0 })
      logger.info('SSH connected to ' .. host.name)
      M.start_heartbeat(host)
      cb(true, out)
    else
      state.update_connection({ status = 'disconnected', last_error = out })
      logger.error('SSH connection failed for ' .. host.name .. ': ' .. out)
      cb(false, out)
    end
  end)
end

function M.start_heartbeat(host)
  if heartbeat_timer then
    heartbeat_timer:stop()
    heartbeat_timer:close()
    heartbeat_timer = nil
  end

  heartbeat_timer = vim.loop.new_timer()
  heartbeat_timer:start(15000, 15000, vim.schedule_wrap(function()
    if state.connection.status ~= 'connected' then
      return
    end

    M.run(host, 'echo heartbeat', function(ok)
      if not ok then
        logger.warn('SSH heartbeat failed; marking disconnected and starting reconnect.')
        state.update_connection({ status = 'disconnected' })
        M.start_reconnect(host)
      end
    end)
  end))
end

function M.start_reconnect(host)
  if reconnect_timer then
    reconnect_timer:stop()
    reconnect_timer:close()
  end

  state.reconnect_state = { running = true, attempts = 0 }
  reconnect_timer = vim.loop.new_timer()
  reconnect_timer:start(0, state.connection.reconnect_interval_ms, vim.schedule_wrap(function()
    if state.reconnect_state.attempts >= state.connection.max_retries then
      logger.warn('Reconnect retries exhausted for ' .. host.name)
      reconnect_timer:stop()
      reconnect_timer:close()
      reconnect_timer = nil
      state.reconnect_state.running = false
      if heartbeat_timer then
        heartbeat_timer:stop()
        heartbeat_timer:close()
        heartbeat_timer = nil
      end
      return
    end

    state.reconnect_state.attempts = state.reconnect_state.attempts + 1
    logger.info(string.format('Reconnect attempt %d for %s', state.reconnect_state.attempts, host.name))
    M.connect(host, function(ok)
      if ok and reconnect_timer then
        reconnect_timer:stop()
        reconnect_timer:close()
        reconnect_timer = nil
        state.reconnect_state.running = false
        M.start_heartbeat(host)
      end
    end)
  end))
end

return M
