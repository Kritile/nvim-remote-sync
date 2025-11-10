local M = {}
local manager = require('sync.manager')
local utils = require('core.utils')

local tree_bufnr = nil
local tree_winnr = nil
local current_path = nil
local tree_state = {}

local function render_tree(files, path)
  if not tree_bufnr or not vim.api.nvim_buf_is_valid(tree_bufnr) then
    return
  end
  
  local lines = {}
  table.insert(lines, '=== Remote Files: ' .. path .. ' ===')
  table.insert(lines, '')
  table.insert(lines, 'Keymaps:')
  table.insert(lines, '  <Enter> - Open/Download file')
  table.insert(lines, '  r - Refresh')
  table.insert(lines, '  d - Download')
  table.insert(lines, '  u - Upload')
  table.insert(lines, '  q - Close')
  table.insert(lines, '')
  table.insert(lines, '--- Files ---')
  
  if path ~= '/' then
    table.insert(lines, '../ (parent directory)')
  end
  
  for _, file in ipairs(files or {}) do
    table.insert(lines, file)
  end
  
  vim.api.nvim_buf_set_option(tree_bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(tree_bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(tree_bufnr, 'modifiable', false)
end

local function load_directory(path, host)
  local files = manager.list_remote(path, host)
  tree_state[path] = files
  render_tree(files, path)
end

local function get_selected_file()
  if not tree_bufnr or not vim.api.nvim_buf_is_valid(tree_bufnr) then
    return nil
  end
  
  local cursor = vim.api.nvim_win_get_cursor(tree_winnr)
  local line_num = cursor[1]
  local line = vim.api.nvim_buf_get_lines(tree_bufnr, line_num - 1, line_num, false)[1]
  
  if not line or line:match('^===') or line:match('^---') or line:match('^%s*$') or line:match('Keymaps') or line:match('^%s+') then
    return nil
  end
  
  return line:match('^%s*(.-)%s*$')
end

local function setup_keymaps()
  if not tree_bufnr then
    return
  end
  
  local opts = { noremap = true, silent = true, buffer = tree_bufnr }
  
  -- Enter: Open/Download file
  vim.keymap.set('n', '<CR>', function()
    local file = get_selected_file()
    if not file then
      return
    end
    
    local host = manager.get_current_host()
    if not host then
      vim.notify('No host selected', vim.log.levels.ERROR)
      return
    end
    
    if file == '../ (parent directory)' then
      local parent = current_path:match('(.*/)[^/]+/$') or '/'
      current_path = parent
      load_directory(current_path, host)
    elseif file:match('/$') then
      -- Directory
      current_path = current_path .. file
      load_directory(current_path, host)
    else
      -- File - download and open
      local remote_path = current_path .. file
      local local_path = utils.join_path(vim.fn.getcwd(), file)
      
      manager.download(remote_path, local_path, host)
      vim.schedule(function()
        vim.cmd('edit ' .. local_path)
      end)
    end
  end, opts)
  
  -- r: Refresh
  vim.keymap.set('n', 'r', function()
    local host = manager.get_current_host()
    if host then
      load_directory(current_path, host)
    end
  end, opts)
  
  -- d: Download selected file
  vim.keymap.set('n', 'd', function()
    local file = get_selected_file()
    if not file or file == '../ (parent directory)' then
      return
    end
    
    local host = manager.get_current_host()
    if not host then
      vim.notify('No host selected', vim.log.levels.ERROR)
      return
    end
    
    local remote_path = current_path .. file
    local local_path = utils.join_path(vim.fn.getcwd(), file)
    
    manager.download(remote_path, local_path, host)
  end, opts)
  
  -- u: Upload current file
  vim.keymap.set('n', 'u', function()
    local host = manager.get_current_host()
    if not host then
      vim.notify('No host selected', vim.log.levels.ERROR)
      return
    end
    
    local current_file = utils.get_current_file()
    if not current_file or current_file == '' then
      vim.notify('No file selected', vim.log.levels.WARN)
      return
    end
    
    local relative_path = utils.relative_path(current_file)
    local remote_path = utils.join_path(host.path, relative_path)
    
    manager.upload(current_file, remote_path, host)
  end, opts)
  
  -- q: Close tree
  vim.keymap.set('n', 'q', function()
    M.close()
  end, opts)
end

function M.open(host)
  host = host or manager.get_current_host()
  
  if not host then
    vim.notify('No host selected', vim.log.levels.ERROR)
    return
  end
  
  -- Create buffer if it doesn't exist
  if not tree_bufnr or not vim.api.nvim_buf_is_valid(tree_bufnr) then
    tree_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(tree_bufnr, 'Remote Files - ' .. host.name)
    vim.api.nvim_buf_set_option(tree_bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(tree_bufnr, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(tree_bufnr, 'swapfile', false)
    vim.api.nvim_buf_set_option(tree_bufnr, 'modifiable', false)
  end
  
  -- Open split window
  vim.cmd('vsplit')
  tree_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(tree_winnr, tree_bufnr)
  vim.api.nvim_win_set_width(tree_winnr, 40)
  
  -- Initialize path
  current_path = host.path
  if not current_path:match('/$') then
    current_path = current_path .. '/'
  end
  
  -- Setup keymaps
  setup_keymaps()
  
  -- Load initial directory
  load_directory(current_path, host)
  
  manager.set_current_host(host)
end

function M.close()
  if tree_winnr and vim.api.nvim_win_is_valid(tree_winnr) then
    vim.api.nvim_win_close(tree_winnr, true)
  end
  
  tree_winnr = nil
end

function M.toggle(host)
  if tree_winnr and vim.api.nvim_win_is_valid(tree_winnr) then
    M.close()
  else
    M.open(host)
  end
end

return M
