local M = {}
local logger = require('core.logger')

local function trim(value)
  return value:gsub('^%s+', ''):gsub('%s+$', '')
end

local function parse_value(raw)
  local value = trim(raw)

  if value:match('^".*"$') then
    return value:sub(2, -2)
  end

  if value:match('^%[.*%]$') then
    local result = {}
    for item in value:gmatch('"([^"]+)"') do
      table.insert(result, item)
    end
    return result
  end

  if tonumber(value) then
    return tonumber(value)
  end

  return value
end

local function parse_toml(content)
  local data = { hosts = {} }
  local current = nil

  for line in content:gmatch('[^\r\n]+') do
    local clean = trim(line)
    if clean ~= '' and not clean:match('^#') then
      if clean == '[[hosts]]' then
        current = {}
        table.insert(data.hosts, current)
      else
        local key, raw = clean:match('^([%w_]+)%s*=%s*(.+)$')
        if key and raw then
          local value = parse_value(raw)
          if current then
            current[key] = value
          else
            data[key] = value
          end
        end
      end
    end
  end

  return data
end

local function validate_host(host)
  if not host.name or not host.type or not host.host or not host.user or not host.remote_path then
    return false, 'host requires name/type/host/user/remote_path'
  end

  if host.type ~= 'sftp' and host.type ~= 'ssh' and host.type ~= 'rsync' then
    return false, 'host type must be ssh/sftp/rsync'
  end

  local auth_count = 0
  if host.ssh_key then auth_count = auth_count + 1 end
  if host.password then auth_count = auth_count + 1 end
  if host.password_env then auth_count = auth_count + 1 end

  if auth_count == 0 then
    return false, 'authentication method is required'
  end

  return true
end

local function load_file(path)
  local f = io.open(path, 'r')
  if not f then
    return nil
  end
  local content = f:read('*all')
  f:close()
  return parse_toml(content)
end

function M.load()
  local global_path = vim.fn.expand('~/.config/nvim/remote_hosts_sync.toml')
  local project_path = vim.fn.getcwd() .. '/.remote_hosts_sync.toml'

  local global_data = load_file(global_path) or { hosts = {} }
  local project_data = load_file(project_path) or { hosts = {} }

  local merged = vim.tbl_deep_extend('force', global_data, project_data)
  merged.hosts = merged.hosts or {}

  if #merged.hosts > 10 then
    logger.warn('Maximum hosts per project exceeded (10). Extra hosts are ignored.')
    while #merged.hosts > 10 do
      table.remove(merged.hosts)
    end
  end

  for _, host in ipairs(merged.hosts) do
    local ok, err = validate_host(host)
    if not ok then
      error('Invalid host config for ' .. (host.name or 'unknown') .. ': ' .. err)
    end
  end

  local active = merged.active_host
  if active then
    local exists = false
    for _, host in ipairs(merged.hosts) do
      if host.name == active then
        exists = true
        break
      end
    end
    if not exists then
      logger.warn('Configured active_host does not exist; falling back to first host.')
      merged.active_host = merged.hosts[1] and merged.hosts[1].name or nil
    end
  else
    merged.active_host = merged.hosts[1] and merged.hosts[1].name or nil
  end

  return merged
end

return M
