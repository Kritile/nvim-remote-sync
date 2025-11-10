local M = {}
local utils = require('core.utils')
local manager = require('sync.manager')

-- Download remote file to temporary location
local function download_to_temp(remote_path, host)
  local temp_dir = vim.fn.stdpath('cache') .. '/remote_hosts_sync'
  vim.fn.mkdir(temp_dir, 'p')
  
  local temp_file = temp_dir .. '/' .. remote_path:gsub('[/\\]', '_')
  
  local success = manager.download(remote_path, temp_file, host)
  
  if success then
    return temp_file
  end
  
  return nil
end

-- Open diff view between local and remote file
function M.diff_files(local_path, remote_path, host)
  host = host or manager.get_current_host()
  
  if not host then
    vim.notify('No host selected', vim.log.levels.ERROR)
    return false
  end
  
  -- Download remote file to temp
  local temp_remote = download_to_temp(remote_path, host)
  
  if not temp_remote then
    vim.notify('Failed to download remote file for comparison', vim.log.levels.ERROR)
    return false
  end
  
  -- Open diff in vertical split
  vim.cmd('edit ' .. local_path)
  vim.cmd('vertical diffsplit ' .. temp_remote)
  
  -- Set buffer options for temp file
  vim.api.nvim_buf_set_option(0, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(0, 'bufhidden', 'wipe')
  
  -- Add buffer name to identify it
  vim.api.nvim_buf_set_name(0, 'Remote: ' .. remote_path)
  
  vim.notify('Comparing local and remote versions', vim.log.levels.INFO)
  utils.log('Diff opened: ' .. local_path .. ' <-> ' .. remote_path)
  
  return true
end

-- Compare current file with its remote version
function M.diff_current_file()
  local host = manager.get_current_host()
  
  if not host then
    vim.notify('No host selected. Use :RemoteOpenTree first', vim.log.levels.ERROR)
    return false
  end
  
  local local_path = utils.get_current_file()
  
  if not local_path or local_path == '' then
    vim.notify('No file to compare', vim.log.levels.ERROR)
    return false
  end
  
  local relative_path = utils.relative_path(local_path)
  local remote_path = utils.join_path(host.path, relative_path)
  
  return M.diff_files(local_path, remote_path, host)
end

-- Three-way merge helper (if needed in future)
function M.three_way_merge(local_path, remote_path, base_path, host)
  host = host or manager.get_current_host()
  
  if not host then
    vim.notify('No host selected', vim.log.levels.ERROR)
    return false
  end
  
  -- Download remote file
  local temp_remote = download_to_temp(remote_path, host)
  
  if not temp_remote then
    vim.notify('Failed to download remote file', vim.log.levels.ERROR)
    return false
  end
  
  -- Open three-way diff
  vim.cmd('edit ' .. local_path)
  vim.cmd('diffthis')
  vim.cmd('vertical diffsplit ' .. base_path)
  vim.cmd('diffthis')
  vim.cmd('vertical diffsplit ' .. temp_remote)
  vim.cmd('diffthis')
  
  vim.notify('Three-way merge view opened', vim.log.levels.INFO)
  
  return true
end

-- Get diff statistics
function M.get_diff_stats(local_path, remote_path, host)
  host = host or manager.get_current_host()
  
  if not host then
    return nil
  end
  
  local temp_remote = download_to_temp(remote_path, host)
  
  if not temp_remote then
    return nil
  end
  
  -- Use diff command to get statistics
  local cmd = string.format('diff -u "%s" "%s" | diffstat -s', local_path, temp_remote)
  
  local stats = nil
  utils.execute(cmd, function(ok, output)
    if ok and output then
      stats = output
    end
  end)
  
  -- Cleanup
  os.remove(temp_remote)
  
  return stats
end

-- Quick check if files are different
function M.files_differ(local_path, remote_path, host)
  host = host or manager.get_current_host()
  
  if not host then
    return nil
  end
  
  local temp_remote = download_to_temp(remote_path, host)
  
  if not temp_remote then
    return nil
  end
  
  -- Compare file checksums
  local local_sum = vim.fn.system('md5sum "' .. local_path .. '"'):match('^%S+')
  local remote_sum = vim.fn.system('md5sum "' .. temp_remote .. '"'):match('^%S+')
  
  -- Cleanup
  os.remove(temp_remote)
  
  return local_sum ~= remote_sum
end

-- Show diff in floating window
function M.show_diff_preview(local_path, remote_path, host)
  host = host or manager.get_current_host()
  
  if not host then
    vim.notify('No host selected', vim.log.levels.ERROR)
    return false
  end
  
  local temp_remote = download_to_temp(remote_path, host)
  
  if not temp_remote then
    vim.notify('Failed to download remote file', vim.log.levels.ERROR)
    return false
  end
  
  -- Generate unified diff
  local cmd = string.format('diff -u "%s" "%s"', local_path, temp_remote)
  local diff_output = {}
  
  utils.execute(cmd, function(ok, output)
    if output then
      for line in output:gmatch('[^\r\n]+') do
        table.insert(diff_output, line)
      end
    end
  end)
  
  -- Create floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, diff_output)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'diff')
  
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
  }
  
  local win = vim.api.nvim_open_win(buf, true, opts)
  
  -- Set keymaps for closing
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', { noremap = true, silent = true })
  
  -- Cleanup temp file when window closes
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    callback = function()
      os.remove(temp_remote)
    end,
  })
  
  return true
end

return M
