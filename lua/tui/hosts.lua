local M = {}
local config = require('core.config')
local manager = require('sync.manager')

-- Check if telescope is available
local has_telescope, telescope = pcall(require, 'telescope')
local pickers, finders, actions, action_state

if has_telescope then
  pickers = require('telescope.pickers')
  finders = require('telescope.finders')
  actions = require('telescope.actions')
  action_state = require('telescope.actions.state')
end

function M.show_hosts()
  if not has_telescope then
    vim.notify('Telescope.nvim is required for TUI', vim.log.levels.ERROR)
    return
  end
  
  local hosts_config = config.load_hosts()
  local hosts = hosts_config.hosts or {}
  
  if #hosts == 0 then
    vim.notify('No hosts configured. Add hosts to ' .. config.get('config_file'), vim.log.levels.WARN)
    return
  end
  
  local opts = require('telescope.themes').get_dropdown({})
  
  pickers.new(opts, {
    prompt_title = 'Remote Hosts',
    finder = finders.new_table({
      results = hosts,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format('%s (%s@%s:%s)', 
            entry.name, entry.user, entry.host, entry.path),
          ordinal = entry.name,
        }
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          manager.set_current_host(selection.value)
          vim.notify('Connected to ' .. selection.value.name, vim.log.levels.INFO)
        end
      end)

      map('i', '<C-e>', function()
        local selection = action_state.get_selected_entry()
        if selection then
          actions.close(prompt_bufnr)
          M.edit_host(selection.value)
        end
      end)

      map('i', '<C-d>', function()
        local selection = action_state.get_selected_entry()
        if selection then
          M.delete_host(selection.value)
          actions.close(prompt_bufnr)
          M.show_hosts()  -- рекурсивно обновляем список
        end
      end)

      map('i', '<C-t>', function()
        local selection = action_state.get_selected_entry()
        if selection then
          M.test_connection(selection.value)
        end
      end)

      return true
    end,  -- <-- запятая здесь нужна
  }):find()
end

function M.edit_host(host)
  -- Simple implementation: open the config file for editing
  vim.cmd('edit ' .. config.get('config_file'))
  vim.notify('Edit host configuration and save', vim.log.levels.INFO)
end

function M.delete_host(host)
  local hosts_config = config.load_hosts()
  local new_hosts = {}
  
  for _, h in ipairs(hosts_config.hosts) do
    if h.name ~= host.name then
      table.insert(new_hosts, h)
    end
  end
  
  if config.save_hosts(new_hosts) then
    vim.notify('Deleted host: ' .. host.name, vim.log.levels.INFO)
  end
end

function M.test_connection(host)
  vim.notify('Testing connection to ' .. host.name .. '...', vim.log.levels.INFO)
  
  local success = manager.connect(host)
  if success then
    vim.notify('Successfully connected to ' .. host.name, vim.log.levels.INFO)
  else
    vim.notify('Failed to connect to ' .. host.name, vim.log.levels.ERROR)
  end
end

function M.add_host()
  -- Open config file to add a new host manually
  local config_file = config.get('config_file')
  
  if not vim.fn.filereadable(config_file) then
    -- Create template
    local template = [=[
[[hosts]]
name = "New Host"
type = "sftp"
host = "example.com"
port = 22
user = "username"
password = "password"
path = "/var/www/project"
excludes_local = ["node_modules/", ".git/"]
excludes_remote = ["cache/", "logs/"]
]=]

    local file = io.open(config_file, 'w')
    if file then
      file:write(template)
      file:close()
    end
  end
  
  vim.cmd('edit ' .. config_file)
  vim.notify('Add new host configuration and save', vim.log.levels.INFO)
end

return M
