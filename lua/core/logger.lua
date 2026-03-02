local M = {}

local LOG_FILE = '.remote_hosts_sync.log'

local function redact(text)
  if not text then
    return ''
  end

  local masked = tostring(text)
  masked = masked:gsub('SSHPASS=[^%s]+', 'SSHPASS=***')
  masked = masked:gsub('password%s*=%s*"[^"]+"', 'password="***"')
  masked = masked:gsub('password%s*=%s*[^,%s]+', 'password=***')
  return masked
end

function M.set_log_file(path)
  if path and path ~= '' then
    LOG_FILE = path
  end
end

function M.log(level, message)
  local file = io.open(LOG_FILE, 'a')
  if file then
    file:write(string.format('[%s] [%s] %s\n', os.date('%Y-%m-%d %H:%M:%S'), level, redact(message)))
    file:close()
  end
end

function M.info(message)
  M.log('INFO', message)
end

function M.warn(message)
  M.log('WARN', message)
  vim.schedule(function()
    vim.notify(message, vim.log.levels.WARN)
  end)
end

function M.error(message)
  M.log('ERROR', message)
  vim.schedule(function()
    vim.notify(message, vim.log.levels.ERROR)
  end)
end

function M.debug(message)
  M.log('DEBUG', message)
end

return M
