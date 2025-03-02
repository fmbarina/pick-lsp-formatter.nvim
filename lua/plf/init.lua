local config = require('plf.config')

local M = {}

--- Dictionary defining which language server to use for each filetype
--- The key is the filetype and the language server name is its value
---@alias plf.Format { [string]: string }

--- Get save file path for current working directory or project.
---@return string path
local function get_save_file()
  local sep = '/'
  if vim.fn.has('win32') == 1 then
    sep = '[\\:]'
  end

  local current = vim.fn.getcwd()
  if config.opts.find_project then
    local files = vim.fs.find(config.opts.find_patterns, {
      upward = true,
      stop = vim.uv.os_homedir(),
      path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
      limit = 1, -- default value, just to be explicit
    })
    if files[1] ~= nil then
      current = vim.fs.dirname(files[1])
    end
  end

  return config.opts.data_dir .. string.gsub(current, sep, '%%')
end

---@param fmt plf.Format Format dictionary
---@return string
local function serialize(fmt)
  local ret = ''
  for ft, server in pairs(fmt) do
    ret = ret .. ft .. ' @uses ' .. server .. '\n'
  end
  return ret
end

---@param fmt string Serialized format dictionary
---@return plf.Format
local function deserialize(fmt)
  local ret = {}
  for _, line in ipairs(vim.fn.split(fmt, '\n')) do
    local pair = vim.fn.split(line, ' @uses ')
    ret[pair[1]] = pair[2]
  end
  return ret
end

--- Save format dictionary
---@param path string Path to save data in
---@param fmt plf.Format Format dictionary
local function save(path, fmt)
  local handle = io.open(path, 'w+')
  if handle then
    handle:write(serialize(fmt))
    handle:close()
  end
end

--- Load format dictionary
---@param path string Path to load data from
---@return plf.Format
local function load(path)
  local fmt = {}

  if vim.fn.filereadable(path) == 0 then
    return fmt
  end

  local handle = io.open(path, 'r')
  if handle then
    fmt = deserialize(handle:read('*all'))
    handle:close()
  end

  return fmt
end

--- Get active LSP servers capable of formatting
---@return string[] servers
local function get_format_servers()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  local servers = {}

  for i, client in ipairs(clients) do
    if vim.tbl_contains(config.opts.exclude_lsp, client.name) then
      table.remove(clients, i)
    end
  end

  for _, client in ipairs(clients) do
    if client.supports_method('textDocument/formatting') then
      table.insert(servers, client.name)
    end
  end

  return servers
end

--- Calls vim.lsp.buf.format with opts, extended with { name = server }.
---@param server string Language server to format with
---@param opts? table Options passed to vim.lsp.buf.format()
function M.format_with(server, opts)
  opts = vim.tbl_extend('force', opts or {}, { name = server })
  vim.lsp.buf.format(opts)
end

--- Opens picker to choose LSP server for current filetype, then formats buffer.
--- Buffer will only be formatted if an LSP server is picked. Picked server may
--- be set as the default formatter for that filetype in the current working
--- directory or project, following the `set_on_pick` setting.
--- This behavior can be overridden using the set parameter.
---@param opts? table Options passed to vim.lsp.buf.format()
---@param set? boolean Override set_on_pick setting, defaults when nil
function M.pick_format(opts, set)
  opts = opts or {}
  if set == nil then
    set = config.opts.set_on_pick
  end

  local ft = vim.bo.filetype
  local servers = get_format_servers()
  local server_count = vim.fn.len(servers)

  if server_count == 1 then
    M.format_with(servers[1], opts)
    return
  elseif server_count == 0 then
    -- will fail, but we don't want plf to change *how* it fails (for now)
    -- notifications, warnings, errors, etc. should stay the same with plf
    vim.lsp.buf.format(opts)
    return
  end

  local prompt = 'Format ' .. ft .. ' files with'
  local function select(choice)
    if set then
      config.fmt[ft] = choice
    end
    M.format_with(choice, opts)
  end

  local has_telescope, _ = pcall(require, 'telescope')
  if has_telescope then
    -- I love telescope, but wow is this a lot of code for the
    -- simplest picker I can think of (pick string of string[])
    -- TODO: pretty sure this can be improved
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local actions = require('telescope.actions')
    local state = require('telescope.actions.state')
    local conf = require('telescope.config').values
    local theme = require('telescope.themes').get_dropdown()
    pickers
        .new(theme, {
          prompt_title = prompt,
          finder = finders.new_table({ results = servers }),
          sorter = conf.generic_sorter(),
          attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
              actions.close(prompt_bufnr)
              local server = state.get_selected_entry()[1]
              select(server)
            end)
            return true
          end,
        })
        :find()
    return
  end

  vim.ui.select(servers, {
    prompt = prompt,
  }, function(server)
    if server ~= nil then
      select(server)
    end
  end)
end

--- Format buffer using selected LSP server for filetype.
--- When no server is selected, `plf.pick_format()` will be called if:
--- - `when_unset` == `pick` OR
--- - `when_unset()` -> `true`
---@param opts? table Options passed to vim.lsp.buf.format()
function M.format(opts)
  opts = opts or {}

  local ft = vim.bo.filetype
  local server = config.fmt[ft]
  local behavior = config.opts.when_unset
  local b_type = type(behavior)

  if server ~= nil then
    M.format_with(server, opts)
  elseif (b_type == 'string') and (behavior == 'pick') then
    M.pick_format()
  elseif (b_type == 'function') and behavior() then
    M.pick_format()
  else
    vim.lsp.buf.format(opts)
  end
end

--- Setup plugin, must be called before `plf.format` and `plf.pick_format`.
---@param opts? plf.Opts Plugin options
function M.setup(opts)
  config.build(opts or {})
  vim.fn.mkdir(config.opts.data_dir, 'p')
  local save_file = get_save_file()
  config.fmt = load(save_file)
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('PickLspFormatter', {}),
    callback = function()
      save(save_file, config.fmt)
    end,
  })
end

return M
