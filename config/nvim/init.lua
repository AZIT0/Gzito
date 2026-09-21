-- Rice: oscuro #0e0e12 + Tokyo Night, leader <Espacio>
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Opciones base
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8
vim.opt.updatetime = 250

-- lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "folke/tokyonight.nvim", lazy = false, priority = 1000,
    opts = {
      style = "night",
      on_colors = function(c) c.bg = "#0e0e12" c.bg_dark = "#0e0e12" end,
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight")
    end,
  },
  { "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { options = { theme = "tokyonight", component_separators = "", section_separators = "" } },
  },
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Archivos" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Buscar" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
    },
  },
  { "nvim-treesitter/nvim-treesitter", branch = "master", build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },
})

-- Atajos
vim.keymap.set("n", "<leader>e", ":Ex<cr>", { desc = "Explorador" })
vim.keymap.set("n", "<leader>w", ":w<cr>", { desc = "Guardar" })
vim.keymap.set("n", "<leader>q", ":q<cr>", { desc = "Salir" })
