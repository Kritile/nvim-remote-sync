local M = {}

-- Logging function
function M.log(message, level)
  level = level or vim.log.levels.INFO
  
  local config = require('core.config')
  local log_file = config.get('log_file')
  
  -- Log to file
  local file = io.open(log_file, 'a')
  if file then
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local level_name = ({ 'TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR' })[level] or 'INFO'
    file:write(string.format('[%s] [%s] %s\n', timestamp, level_name, message))
    file:close()
  end
  
  -- Also notify user for warnings and errors
  if level >= vim.log.levels.WARN then
    vim.notify(message, level)
  end
end

-- Check if path matches exclude patterns
function M.is_excluded(path, excludes)
  if not excludes then
    return false
  end
  
  for _, pattern in ipairs(excludes) do
    if path:match(pattern:gsub('/', '\\'):gsub('*', '.*')) then
      return true
    end
  end
  
  return false
end

-- Normalize path for current OS
function M.normalize_path(path)
  if vim.fn.has('win32') == 1 then
    return path:gsub('/', '\\')
  else
    return path:gsub('\\', '/')
  end
end

-- Join paths
function M.join_path(...)
  local parts = {...}
  local separator = package.config:sub(1, 1)
  return table.concat(parts, separator)
end

-- Get relative path from base
function M.relative_path(path, base)
  base = base or vim.fn.getcwd()
  
  -- Normalize paths
  path = M.normalize_path(path)
  base = M.normalize_path(base)
  
  -- Remove base from path
  if path:sub(1, #base) == base then
    return path:sub(#base + 2) -- +2 to skip separator
  end
  
  return path
end

-- Check if file exists
function M.file_exists(path)
  local file = io.open(path, 'r')
  if file then
    file:close()
    return true
  end
  return false
end

-- Create directory recursively
function M.mkdir(path)
  local separator = package.config:sub(1, 1)
  local parts = {}
  
  for part in path:gmatch('[^' .. separator .. ']+') do
    table.insert(parts, part)
    local current = table.concat(parts, separator)
    
    if vim.fn.isdirectory(current) == 0 then
      vim.fn.mkdir(current)
    end
  end
end

-- Execute shell command and return output
function M.execute(cmd, callback)
  M.log('Executing: ' .. cmd, vim.log.levels.DEBUG)
  
  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if callback and data then
        callback(true, table.concat(data, '\n'))
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 then
        local err = table.concat(data, '\n')
        if err ~= '' then
          M.log('Error: ' .. err, vim.log.levels.ERROR)
          if callback then
            callback(false, err)
          end
        end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 and callback then
        callback(false, 'Command exited with code ' .. code)
      end
    end,
  })
end

-- Get current file path
function M.get_current_file()
  return vim.fn.expand('%:p')
end

-- Get current buffer content
function M.get_buffer_content(bufnr)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return table.concat(lines, '\n')
end

return M
