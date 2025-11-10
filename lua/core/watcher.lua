local M = {}
local utils = require('core.utils')
local manager = require('sync.manager')

local watcher_state = {
  enabled = false,
  timer = nil,
  watch_interval = 2000, -- milliseconds
  modified_files = {},
  last_check = {},
}

-- Check if file has been modified
local function file_modified(filepath)
  local stat = vim.loop.fs_stat(filepath)
  if not stat then
    return false
  end
  
  local last_time = watcher_state.last_check[filepath]
  local current_time = stat.mtime.sec
  
  if not last_time then
    watcher_state.last_check[filepath] = current_time
    return false
  end
  
  if current_time > last_time then
    watcher_state.last_check[filepath] = current_time
    return true
  end
  
  return false
end

-- Get all files in directory recursively
local function get_all_files(dir, excludes)
  local files = {}
  
  local function scan_dir(path)
    local handle = vim.loop.fs_scandir(path)
    if not handle then
      return
    end
    
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then
        break
      end
      
      local full_path = path .. '/' .. name
      
      -- Check if excluded
      if not utils.is_excluded(full_path, excludes) then
        if type == 'directory' then
          scan_dir(full_path)
        elseif type == 'file' then
          table.insert(files, full_path)
        end
      end
    end
  end
  
  scan_dir(dir)
  return files
end

-- Sync modified files
local function sync_modified_files()
  local host = manager.get_current_host()
  if not host then
    return
  end
  
  local cwd = vim.fn.getcwd()
  local files = get_all_files(cwd, host.excludes_local)
  
  for _, filepath in ipairs(files) do
    if file_modified(filepath) then
      local relative_path = utils.relative_path(filepath)
      local remote_path = utils.join_path(host.path, relative_path)
      
      table.insert(watcher_state.modified_files, {
        local_path = filepath,
        remote_path = remote_path,
        timestamp = os.time(),
      })
      
      utils.log('File modified: ' .. filepath .. ', queued for sync')
    end
  end
  
  -- Process queue
  if #watcher_state.modified_files > 0 then
    local file_info = table.remove(watcher_state.modified_files, 1)
    
    vim.schedule(function()
      manager.upload(file_info.local_path, file_info.remote_path, host)
    end)
  end
end

-- Timer callback
local function on_timer()
  if not watcher_state.enabled then
    return
  end
  
  local ok, err = pcall(sync_modified_files)
  if not ok then
    utils.log('Watcher error: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

-- Start watching
function M.start(interval)
  if watcher_state.enabled then
    vim.notify('Watcher is already running', vim.log.levels.WARN)
    return
  end
  
  local host = manager.get_current_host()
  if not host then
    vim.notify('No host selected. Use :RemoteOpenTree first', vim.log.levels.ERROR)
    return
  end
  
  watcher_state.watch_interval = interval or watcher_state.watch_interval
  watcher_state.enabled = true
  
  -- Create timer
  watcher_state.timer = vim.loop.new_timer()
  watcher_state.timer:start(0, watcher_state.watch_interval, vim.schedule_wrap(on_timer))
  
  utils.log('File watcher started with interval: ' .. watcher_state.watch_interval .. 'ms')
  vim.notify('Background sync enabled', vim.log.levels.INFO)
end

-- Stop watching
function M.stop()
  if not watcher_state.enabled then
    vim.notify('Watcher is not running', vim.log.levels.WARN)
    return
  end
  
  watcher_state.enabled = false
  
  if watcher_state.timer then
    watcher_state.timer:stop()
    watcher_state.timer:close()
    watcher_state.timer = nil
  end
  
  -- Clear state
  watcher_state.modified_files = {}
  watcher_state.last_check = {}
  
  utils.log('File watcher stopped')
  vim.notify('Background sync disabled', vim.log.levels.INFO)
end

-- Toggle watcher
function M.toggle(interval)
  if watcher_state.enabled then
    M.stop()
  else
    M.start(interval)
  end
end

-- Check status
function M.is_running()
  return watcher_state.enabled
end

-- Get statistics
function M.get_stats()
  return {
    enabled = watcher_state.enabled,
    interval = watcher_state.watch_interval,
    queue_size = #watcher_state.modified_files,
    tracked_files = vim.tbl_count(watcher_state.last_check),
  }
end

-- Manual trigger
function M.trigger_sync()
  if not watcher_state.enabled then
    vim.notify('Watcher is not running. Use :RemoteWatchStart', vim.log.levels.WARN)
    return
  end
  
  sync_modified_files()
  vim.notify('Manual sync triggered', vim.log.levels.INFO)
end

-- Watch specific directory
function M.watch_directory(dir, host)
  host = host or manager.get_current_host()
  
  if not host then
    vim.notify('No host selected', vim.log.levels.ERROR)
    return
  end
  
  local files = get_all_files(dir, host.excludes_local)
  
  -- Initialize last_check for all files
  for _, filepath in ipairs(files) do
    local stat = vim.loop.fs_stat(filepath)
    if stat then
      watcher_state.last_check[filepath] = stat.mtime.sec
    end
  end
  
  utils.log('Watching directory: ' .. dir .. ' (' .. #files .. ' files)')
end

-- Alternative: Use Neovim's built-in file system watcher (libuv)
function M.start_fs_watch()
  local host = manager.get_current_host()
  if not host then
    vim.notify('No host selected', vim.log.levels.ERROR)
    return
  end
  
  local cwd = vim.fn.getcwd()
  
  local handle = vim.loop.new_fs_event()
  if not handle then
    vim.notify('Failed to create fs watcher', vim.log.levels.ERROR)
    return
  end
  
  local function on_change(err, filename, events)
    if err then
      utils.log('FS Watch error: ' .. err, vim.log.levels.ERROR)
      return
    end
    
    if filename then
      local full_path = cwd .. '/' .. filename
      
      -- Check if file should be excluded
      if not utils.is_excluded(full_path, host.excludes_local) then
        local relative_path = utils.relative_path(full_path)
        local remote_path = utils.join_path(host.path, relative_path)
        
        vim.schedule(function()
          manager.upload(full_path, remote_path, host)
        end)
      end
    end
  end
  
  handle:start(cwd, {recursive = true}, on_change)
  watcher_state.fs_handle = handle
  
  utils.log('FS watcher started for: ' .. cwd)
  vim.notify('Filesystem watcher enabled', vim.log.levels.INFO)
end

-- Stop FS watcher
function M.stop_fs_watch()
  if watcher_state.fs_handle then
    watcher_state.fs_handle:stop()
    watcher_state.fs_handle = nil
    
    utils.log('FS watcher stopped')
    vim.notify('Filesystem watcher disabled', vim.log.levels.INFO)
  end
end

return M
