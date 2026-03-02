if vim.g.loaded_remote_hosts_sync then
  return
end
vim.g.loaded_remote_hosts_sync = 1

if vim.fn.has('nvim-0.9') == 0 then
  vim.api.nvim_err_writeln('remote_hosts_sync requires Neovim >= 0.9')
  return
end

local ok, commands = pcall(require, 'commands')
if not ok then
  vim.api.nvim_err_writeln('Failed to initialize remote_hosts_sync commands')
  return
end

commands.setup()
