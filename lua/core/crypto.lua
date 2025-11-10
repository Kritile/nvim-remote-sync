local M = {}

-- Simple XOR cipher for password obfuscation
-- Note: This is NOT secure encryption, just basic obfuscation
-- For real security, use SSH keys instead of passwords

local function get_machine_key()
  -- Generate a key based on machine-specific data
  local hostname = vim.fn.hostname()
  local user = vim.fn.expand('$USER') or vim.fn.expand('$USERNAME')
  return hostname .. user .. 'nvim-remote-sync-salt'
end

local function xor_cipher(text, key)
  local result = {}
  local key_len = #key
  
  for i = 1, #text do
    local char = string.byte(text, i)
    local key_char = string.byte(key, ((i - 1) % key_len) + 1)
    table.insert(result, string.char(bit.bxor(char, key_char)))
  end
  
  return table.concat(result)
end

-- Base64 encoding (for when bit operations are not available)
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64_encode(data)
  return ((data:gsub('.', function(x) 
    local r, b = '', x:byte()
    for i = 8, 1, -1 do
      r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0')
    end
    return r
  end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if (#x < 6) then return '' end
    local c = 0
    for i = 1, 6 do
      c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0)
    end
    return b64chars:sub(c + 1, c + 1)
  end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

local function base64_decode(data)
  data = string.gsub(data, '[^' .. b64chars .. '=]', '')
  return (data:gsub('.', function(x)
    if (x == '=') then return '' end
    local r, f = '', (b64chars:find(x) - 1)
    for i = 6, 1, -1 do
      r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
    end
    return r
  end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
    if (#x ~= 8) then return '' end
    local c = 0
    for i = 1, 8 do
      c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0)
    end
    return string.char(c)
  end))
end

-- Encrypt password
function M.encrypt(password)
  if not password or password == '' then
    return ''
  end
  
  -- Check if already encrypted (starts with 'encrypted:')
  if password:match('^encrypted:') then
    return password
  end
  
  -- Skip encryption for file paths (SSH keys)
  if password:match('^/') or password:match('^~') then
    return password
  end
  
  local key = get_machine_key()
  
  -- Try XOR cipher with bit operations
  local has_bit, bit_module = pcall(require, 'bit')
  if not has_bit then
    has_bit, bit_module = pcall(require, 'bit32')
  end
  
  local encrypted
  if has_bit then
    bit = bit_module
    encrypted = xor_cipher(password, key)
  else
    -- Fallback: simple character shifting
    local result = {}
    for i = 1, #password do
      local char = string.byte(password, i)
      local shift = string.byte(key, ((i - 1) % #key) + 1)
      table.insert(result, string.char((char + shift) % 256))
    end
    encrypted = table.concat(result)
  end
  
  -- Encode to base64 for safe storage
  return 'encrypted:' .. base64_encode(encrypted)
end

-- Decrypt password
function M.decrypt(encrypted_password)
  if not encrypted_password or encrypted_password == '' then
    return ''
  end
  
  -- Not encrypted, return as is
  if not encrypted_password:match('^encrypted:') then
    return encrypted_password
  end
  
  -- Remove 'encrypted:' prefix
  local encoded = encrypted_password:gsub('^encrypted:', '')
  
  -- Decode from base64
  local encrypted = base64_decode(encoded)
  
  local key = get_machine_key()
  
  -- Try XOR cipher with bit operations
  local has_bit, bit_module = pcall(require, 'bit')
  if not has_bit then
    has_bit, bit_module = pcall(require, 'bit32')
  end
  
  if has_bit then
    bit = bit_module
    return xor_cipher(encrypted, key)
  else
    -- Fallback: simple character shifting (reverse)
    local result = {}
    for i = 1, #encrypted do
      local char = string.byte(encrypted, i)
      local shift = string.byte(key, ((i - 1) % #key) + 1)
      table.insert(result, string.char((char - shift) % 256))
    end
    return table.concat(result)
  end
end

-- Encrypt all passwords in hosts configuration
function M.encrypt_hosts_passwords(hosts)
  local encrypted_hosts = {}
  
  for _, host in ipairs(hosts) do
    local new_host = vim.deepcopy(host)
    if new_host.password then
      new_host.password = M.encrypt(new_host.password)
    end
    table.insert(encrypted_hosts, new_host)
  end
  
  return encrypted_hosts
end

-- Decrypt all passwords in hosts configuration
function M.decrypt_hosts_passwords(hosts)
  local decrypted_hosts = {}
  
  for _, host in ipairs(hosts) do
    local new_host = vim.deepcopy(host)
    if new_host.password then
      new_host.password = M.decrypt(new_host.password)
    end
    table.insert(decrypted_hosts, new_host)
  end
  
  return decrypted_hosts
end

return M
