-- 1. 基础设置
vim.g.mapleader = " " -- 空格键作为 Leader
vim.opt.number = true -- 显示行号
vim.opt.relativenumber = true -- 相对行号
vim.opt.shiftwidth = 4 -- 缩进
vim.opt.tabstop = 4
vim.opt.expandtab = true
vim.opt.cursorline = true -- 高亮当前行
vim.opt.termguicolors = true -- 真彩色支持

-- 2. 插件管理器 (lazy.nvim)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- 3. 插件列表
require("lazy").setup({
  "folke/tokyonight.nvim",          -- 主题
  "nvim-treesitter/nvim-treesitter",-- 语法高亮
  "neovim/nvim-lspconfig",          -- 基础 LSP 配置
  "hrsh7th/nvim-cmp",               -- 补全引擎
  "hrsh7th/cmp-nvim-lsp",           -- LSP 补全源
  "nvim-telescope/telescope.nvim",  -- 模糊搜索 (需 dependencies)
  dependencies = { 'nvim-lua/plenary.nvim' }
})

-- 4. 简单外观与功能配置
vim.cmd[[colorscheme tokyonight]]
require'nvim-treesitter.configs'.setup { highlight = { enable = true } }

-- 5. 常用快捷键
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {}) -- 找文件
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})  -- 搜文字
vim.keymap.set('n', 'gd', vim.lsp.buf.definition, {})     -- 跳转定义
vim.keymap.set('n', 'K', vim.lsp.buf.hover, {})           -- 悬浮文档
