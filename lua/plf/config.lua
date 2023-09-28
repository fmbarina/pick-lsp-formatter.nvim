local M = {}

local defaults = {
  data_dir = vim.fn.expand(vim.fn.stdpath('state') .. '/picklspfmt/'),
  when_unset = 'pick', -- nil, 'pick', fun()->bool
  set_on_pick = true,
  find_project = false,
  find_patterns = { '.git/' },
  exclude_lsp = {},
}

M.opts = {}

function M.build(opts)
  M.opts = vim.tbl_extend('force', {}, defaults, opts)
end

return M
