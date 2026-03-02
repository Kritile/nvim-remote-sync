local M = {
  active_host = nil,
  connection = {
    status = 'disconnected',
    retries = 0,
    max_retries = 5,
    reconnect_interval_ms = 5000,
    last_error = nil,
  },
  sync_state = {
    last_upload = nil,
    last_sync = nil,
    in_progress = false,
  },
  reconnect_state = {
    running = false,
    attempts = 0,
  },
}

function M.set_active_host(host)
  M.active_host = host
end

function M.get_active_host()
  return M.active_host
end

function M.update_connection(patch)
  M.connection = vim.tbl_extend('force', M.connection, patch or {})
end

return M
