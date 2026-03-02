local state = require('core.state')
local sftp = require('transport.sftp')
local logger = require('core.logger')

local M = {
  cache = {},
  page_size = 200,
  node_index = {},
  rendered_children = {},
}

local function loading_node(Tree, loaded, total)
  return Tree.Node({
    text = string.format('[loading %d/%d]', loaded, total),
    path = '__loading__',
    is_dir = false,
  })
end

local function node_key(path)
  return path
end

local function build_nodes(Tree, parent_path, names)
  local children = {}
  for _, name in ipairs(names or {}) do
    if name ~= '' and name ~= '.' and name ~= '..' then
      local path = parent_path:gsub('/$', '') .. '/' .. name:gsub('/$', '')
      local is_dir = name:sub(-1) == '/'
      table.insert(children, Tree.Node({ text = name, path = path, is_dir = is_dir }))
    end
  end
  table.sort(children, function(a, b)
    if a.is_dir ~= b.is_dir then
      return a.is_dir
    end
    return a.text:lower() < b.text:lower()
  end)
  return children
end

local function chunked_set_nodes(tree, parent, children)
  local Tree = require('nui.tree')

  if #children == 0 then
    tree:set_nodes({}, parent:get_id())
    tree:render()
    return
  end

  local page_size = M.page_size
  local first_page = {}
  for i = 1, math.min(page_size, #children) do
    table.insert(first_page, children[i])
  end

  local parent_id = parent:get_id()
  local first_render = vim.deepcopy(first_page)
  if #children > #first_page then
    table.insert(first_render, loading_node(Tree, #first_page, #children))
  end

  tree:set_nodes(first_render, parent_id)
  M.rendered_children[parent_id] = vim.deepcopy(first_render)
  tree:render()

  local idx = page_size + 1
  local function append_next()
    if idx > #children then
      return
    end

    local current = M.rendered_children[parent_id] or {}
    if #current > 0 and current[#current].path == '__loading__' then
      table.remove(current, #current)
    end

    local limit = math.min(idx + page_size - 1, #children)
    for i = idx, limit do
      table.insert(current, children[i])
    end

    if limit < #children then
      table.insert(current, loading_node(Tree, limit, #children))
    end

    tree:set_nodes(current, parent_id)
    M.rendered_children[parent_id] = vim.deepcopy(current)
    tree:render()
    idx = limit + 1

    vim.defer_fn(append_next, 5)
  end

  vim.defer_fn(append_next, 5)
end

function M.open()
  local host = state.get_active_host()
  if not host then
    vim.notify('No active host configured', vim.log.levels.ERROR)
    return
  end

  local ok_tree, Tree = pcall(require, 'nui.tree')
  local ok_popup, Popup = pcall(require, 'nui.popup')
  if not ok_tree or not ok_popup then
    vim.notify('nui.nvim is required for RemoteTree', vim.log.levels.ERROR)
    return
  end

  local popup = Popup({
    enter = true,
    border = 'rounded',
    position = '50%',
    size = { width = '60%', height = '70%' },
  })

  local root_node = Tree.Node({ text = host.remote_path, path = host.remote_path, expanded = false })

  local tree = Tree({
    winid = popup.winid,
    nodes = { root_node },
    prepare_node = function(node)
      return node.text
    end,
  })

  local function refresh_node(node)
    sftp.list(host, node.path, function(ok, output)
      if not ok then
        logger.error('Failed to list directory: ' .. node.path)
        return
      end

      local children = build_nodes(Tree, node.path, output)
      local key = node_key(node.path)
      M.cache[key] = children

      -- Keep incremental update scoped to the expanded node to avoid full tree redraws.
      chunked_set_nodes(tree, node, children)

      -- Maintain quick lookup for selective node updates.
      M.node_index[key] = node:get_id()
    end)
  end

  tree:on('expand', function(node)
    if M.cache[node.path] then
      tree:set_nodes(M.cache[node.path], node:get_id())
      tree:render()
      return
    end
    refresh_node(node)
  end)

  tree:map('n', '<CR>', function()
    local node = tree:get_node()
    if not node then
      return
    end

    if node.path == '__loading__' then
      return
    end

    if node.is_dir then
      tree:toggle(node:get_id())
      return
    end

    local tmp = vim.fn.tempname()
    sftp.download(host, node.path, tmp, function(ok)
      if ok then
        vim.schedule(function()
          vim.cmd('edit ' .. vim.fn.fnameescape(tmp))
        end)
      end
    end)
  end)

  tree:map('n', 'r', function()
    local node = tree:get_node()
    if node then
      M.cache[node_key(node.path)] = nil
      refresh_node(node)
    end
  end)

  -- R: force refresh from the root only if needed
  tree:map('n', 'R', function()
    M.cache = {}
    refresh_node(root_node)
  end)

  tree:map('n', 'u', function()
    local local_file = vim.fn.expand('%:p')
    local rel = local_file:gsub('^' .. vim.pesc(vim.fn.getcwd() .. '/'), '')
    local remote = host.remote_path:gsub('/$', '') .. '/' .. rel
    sftp.upload(host, local_file, remote, function() end)
  end)

  tree:map('n', 'd', function()
    local node = tree:get_node()
    if node and node.path ~= '__loading__' and not node.is_dir then
      sftp.download(host, node.path, vim.fn.fnamemodify(node.text, ':t'), function() end)
    end
  end)

  tree:map('n', 'q', function()
    popup:unmount()
  end)

  popup:mount()
  tree:render()
end

return M
