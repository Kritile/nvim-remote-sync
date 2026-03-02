local loader = require('config.loader')
local state = require('core.state')
local logger = require('core.logger')
local ssh = require('transport.ssh')
local rsync = require('transport.rsync')
local tree = require('tui.tree')
local watcher = require('sync.watcher')

local M = {}

local function get_active_host(config)
  for _, host in ipairs(config.hosts or {}) do
    if host.name == config.active_host then
      return host
    end
  end
  return nil
end

function M.setup()
  local config = loader.load()
  logger.set_log_file('.remote_hosts_sync.log')

  local active = get_active_host(config)
  if active then
    state.set_active_host(active)
  end

  vim.api.nvim_create_user_command('RemoteConnect', function()
    local host = state.get_active_host()
    if not host then
      vim.notify('No active host in configuration', vim.log.levels.ERROR)
      return
    end

    ssh.connect(host, function(ok)
      if not ok then
        ssh.start_reconnect(host)
      end
    end)
  end, {})

  vim.api.nvim_create_user_command('RemoteTree', function()
    tree.open()
  end, {})

  vim.api.nvim_create_user_command('RemoteStatus', function()
    local host = state.get_active_host()
    local connection = state.connection
    local lines = {
      'Active host: ' .. (host and host.name or 'none'),
      'Connection: ' .. (connection.status or 'unknown'),
      'Reconnect attempts: ' .. tostring(state.reconnect_state.attempts or 0),
      'Reconnect running: ' .. tostring(state.reconnect_state.running or false),
    }
    vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
  end, {})

  vim.api.nvim_create_user_command('RemoteSync', function(opts)
    local host = state.get_active_host()
    if not host then
      vim.notify('No active host in configuration', vim.log.levels.ERROR)
      return
    end

    local dry_run = opts.args == '--dry-run'
    rsync.sync(host, vim.fn.getcwd(), dry_run, function(ok, output)
      vim.schedule(function()
        vim.notify((ok and 'Sync completed' or 'Sync failed') .. '\n' .. table.concat(output or {}, '\n'))
      end)
    end)
  end, { nargs = '?' })

  vim.api.nvim_create_user_command('RemotePush', function(opts)
    local host = state.get_active_host()
    if not host then
      vim.notify('No active host in configuration', vim.log.levels.ERROR)
      return
    end
    local dir = opts.args ~= '' and opts.args or vim.fn.getcwd()
    rsync.push(host, dir, function(ok)
      vim.schedule(function()
        vim.notify(ok and 'Push completed' or 'Push failed')
      end)
    end)
  end, { nargs = '?' })

  vim.api.nvim_create_user_command('RemoteFetch', function(opts)
    local host = state.get_active_host()
    if not host then
      vim.notify('No active host in configuration', vim.log.levels.ERROR)
      return
    end
    local dir = opts.args ~= '' and opts.args or vim.fn.getcwd()
    rsync.fetch(host, dir, function(ok)
      vim.schedule(function()
        vim.notify(ok and 'Fetch completed' or 'Fetch failed')
      end)
    end)
  end, { nargs = '?' })

  watcher.enable()
end

return M
