-- Plugin entry point for remote_hosts_sync

-- Prevent loading the plugin twice
if vim.g.loaded_remote_hosts_sync then
  return
end
vim.g.loaded_remote_hosts_sync = 1

-- Check Neovim version
if vim.fn.has('nvim-0.9') == 0 then
  vim.api.nvim_err_writeln('remote_hosts_sync requires Neovim >= 0.9')
  return
end

-- Setup the plugin
local ok, core = pcall(require, 'core')
if not ok then
  vim.api.nvim_err_writeln('Failed to load remote_hosts_sync core module')
  return
end

-- Initialize with default configuration
core.setup({})

-- Register commands
local commands = require('commands')
commands.setup()

-- Create a global function for easy access
_G.RemoteHostsSync = {
  setup = core.setup,
  config = require('core.config'),
  manager = require('sync.manager'),
  hosts = require('tui.hosts'),
  tree = require('tui.tree'),
}
