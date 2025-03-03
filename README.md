# plf.nvim

**pick-lsp-formatter** is a plugin to choose a language server to format with.

https://github.com/fmbarina/pick-lsp-formatter.nvim/assets/70731450/c2102d63-2f99-4288-9727-adc280570553

<sub>Notifications are for the sake of demonstration and aren't part of the plugin.</sub>

## Features

- Lets you pick a single language server when formatting
- Remembers per-filetype choices between sessions, which can be saved:
  - per working directory
  - per project

By default, [`vim.buf.lsp.format()`](https://neovim.io/doc/user/lsp.html#vim.lsp.buf.format()) will format the buffer with all attached language servers capable of it, which is less than ideal. It *does* let you filter which language servers to use, but doing that every time isn't very nice. This is the issue this plugin aims to alleviate.

It exists because I wanted to format lua using stylua, so I installed efm. I soon realized I didn't want *every* lua file formatted with stylua. Later, I even thought to stop using stylua at all—editorconfig is right there! Alas, pick-lsp-formatter already existed by then, so stylua gets another chance... in select environments.

Anyway, please hear me out... [efm](https://github.com/mattn/efm-langserver) + [configs](https://github.com/creativenull/efmls-configs-nvim) = good stuff.

## Installation

- Install `fmbarina/pick-lsp-formatter.nvim`
- Ensure `require('plf').setup(opts)` is called.
- Optionally, install [telescope](https://github.com/nvim-telescope/telescope.nvim) or [snacks.picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md) for a better picker.

Using lazy.nvim:

```lua
{
  'fmbarina/pick-lsp-formatter.nvim',
  -- Optional, just one will do
  dependencies = {
    'nvim-telescope/telescope.nvim',
    {
      'folke/snacks.nvim',
      opts = {
        picker = {enabled = true, ui_select = true}
      }
    },
  },
  main = 'plf',
  lazy = true,
  opts = {},
}
```

Again, if you want a better picker (you really should), you only need to install one of the dependencies, but having both installed will work, too.

## Usage

At least for now, pick-lsp-formatter won't create any commands, and it'll likely never create any keybindings.

**Recommendation:** anywhere you `vim.lsp.buf.format()`'ed, use `require('plf').format()` instead. That's it.

For example, here's a snip of my (simplified) lsp config:

```lua
lsp.on_attach(function(client, bufnr)
-- Stuff...
vim.keymap.set('n', '<leader>lf', function()
  -- vim.lsp.buf.format(opts) -- We take this out
  require('plf').format(opts) -- And put this in
end, { buffer = bufnr, desc = 'LSP format buffer' })
-- More stuff...
end)
```

### API

pick-lsp-formatter exposes a simple API to:

- Automatically format with previously chosen server, or open picker to choose one.
- Open picker with formatting capable servers and format buffer with chosen server.
- Format with a specific server (*very* simple wrapper around `vim.lsp.buf.format`)

Relevant functions are near the end of `lua/plf/init.lua`.

## Configuration

The settings table (`opts`) may define the following fields.

| Setting       | Type                                 | Description                                                                  |
|---------------|--------------------------------------|------------------------------------------------------------------------------|
| data_dir      | `string`                             | Path to store plugin data in.                                                |
| when_unset    | `string`: `pick` or `fun(): boolean` | What to do when no server has been set as the formatter yet. See note below. |
| set_on_pick   | `boolean`                            | Whether to remember chosen server for this filetype. Note: see Scope below.  |
| find_project  | `boolean`                            | Whether to save chosen servers for entire current project.                   |
| find_patterns | `string[]`                           | Patterns to look for that define the root of a projet.                       |
| exclude_lsp   | `string[]`                           | Names of servers to never use for formatting.                                |

Note that `when_unset` can be a function. When this is the case, it must return `true` to open picker or `false` to format normally.

And "format normally" here means calling `vim.lsp.buf.format` as you would without this plugin.

### Scope

By default (when `find_project == false`), plf will save your choices for the current working directory. This may not be the best choice if your working directory rarely coincides with the root of projects you're working on. Worst case? You'll need to pick servers again.

If you would like to save your choices for the current project instead, use `find_project == true`. It'll then search upwards for files or directories in `find_patterns` and once it finds one, it will save your choices for that directory. It also falls back to the cwd if the root can't be found.

### Default settings

The plugin comes with the following defaults:

```lua
data_dir = vim.fn.expand(vim.fn.stdpath('state') .. '/picklspfmt/'),
when_unset = 'pick',
set_on_pick = true,
find_project = false,
find_patterns = { '.git/' },
exclude_lsp = {},
```
