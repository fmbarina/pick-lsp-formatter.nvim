local M = {}

---@class plf.Opts
---@field data_dir? string
---@field when_unset? 'pick' | fun():boolean
---@field set_on_pick? boolean
---@field find_project? boolean
---@field find_patterns? string[]
---@field exclude_lsp? string[]
M.opts = {}

---@type plf.Opts
local defaults = {
  data_dir = vim.fn.expand(vim.fn.stdpath('state') .. '/picklspfmt/'),
  when_unset = 'pick',
  set_on_pick = true,
  find_project = false,
  find_patterns = { '.git/' },
  exclude_lsp = {},
}

---@param opts? plf.Opts
function M.build(opts)
  M.opts = vim.tbl_extend('force', {}, defaults, opts or {})
end

return M
