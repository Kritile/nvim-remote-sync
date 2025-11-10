local M = {}
local crypto = require('core.crypto')

local default_config = {
  auto_sync = false,
  log_file = '.remote_hosts_sync.log',
  config_file = '.remote_hosts_sync.toml',
  global_config = vim.fn.expand('~/.config/nvim/remote_hosts_sync.toml'),
  reconnect_interval = 5,
  max_reconnect_attempts = 3,
  encrypt_passwords = true,  -- Enable password encryption by default
}

local current_config = vim.deepcopy(default_config)

-- Simple TOML parser (basic implementation)
local function parse_toml(content)
  local hosts = {}
  local current_host = nil
  
  for line in content:gmatch('[^\r\n]+') do
    line = line:gsub('^%s+', ''):gsub('%s+$', '')
    
    if line:match('^%[%[hosts%]%]') then
      if current_host then
        table.insert(hosts, current_host)
      end
      current_host = {}
    elseif current_host and line ~= '' and not line:match('^#') then
      local key, value = line:match('^([%w_]+)%s*=%s*(.+)$')
      if key and value then
        -- Remove quotes
        value = value:gsub('^"', ''):gsub('"$', '')
        
        -- Parse arrays
        if value:match('^%[') then
          local array = {}
          for item in value:gmatch('"([^"]+)"') do
            table.insert(array, item)
          end
          current_host[key] = array
        else
          -- Parse numbers
          if tonumber(value) then
            current_host[key] = tonumber(value)
          else
            current_host[key] = value
          end
        end
      end
    end
  end
  
  if current_host then
    table.insert(hosts, current_host)
  end
  
  return { hosts = hosts }
end

-- Serialize to TOML
local function serialize_toml(data)
  local lines = {}
  
  for _, host in ipairs(data.hosts or {}) do
    table.insert(lines, '[[hosts]]')
    for key, value in pairs(host) do
      if type(value) == 'table' then
        local items = {}
        for _, item in ipairs(value) do
          table.insert(items, '"' .. item .. '"')
        end
        table.insert(lines, key .. ' = [' .. table.concat(items, ', ') .. ']')
      elseif type(value) == 'string' then
        table.insert(lines, key .. ' = "' .. value .. '"')
      else
        table.insert(lines, key .. ' = ' .. tostring(value))
      end
    end
    table.insert(lines, '')
  end
  
  return table.concat(lines, '\n')
end

function M.setup(opts)
  current_config = vim.tbl_deep_extend('force', default_config, opts or {})
end

function M.get(key)
  return current_config[key]
end

function M.set(key, value)
  current_config[key] = value
end

function M.load_hosts(config_path)
  config_path = config_path or M.get('config_file')
  
  local file = io.open(config_path, 'r')
  if not file then
    return { hosts = {} }
  end
  
  local content = file:read('*all')
  file:close()
  
  local parsed = parse_toml(content)
  
  -- Decrypt passwords if encryption is enabled
  if M.get('encrypt_passwords') then
    parsed.hosts = crypto.decrypt_hosts_passwords(parsed.hosts)
  end
  
  return parsed
end

function M.save_hosts(hosts, config_path)
  config_path = config_path or M.get('config_file')
  
  local file = io.open(config_path, 'w')
  if not file then
    vim.notify('Failed to save hosts configuration', vim.log.levels.ERROR)
    return false
  end
  
  -- Encrypt passwords if encryption is enabled
  local hosts_to_save = hosts
  if M.get('encrypt_passwords') then
    hosts_to_save = crypto.encrypt_hosts_passwords(hosts)
  end
  
  local content = serialize_toml({ hosts = hosts_to_save })
  file:write(content)
  file:close()
  
  return true
end

function M.get_host_by_name(name)
  local config = M.load_hosts()
  for _, host in ipairs(config.hosts) do
    if host.name == name then
      return host
    end
  end
  return nil
end

return M
