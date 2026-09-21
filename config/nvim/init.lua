-- Rice: paleta Ghostty #121815 + Tokyo Night, leader <Espacio>
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
      -- Paleta igualada a Ghostty (Gzito/config/ghostty/config)
      on_colors = function(c)
        c.bg = "#121815"
        c.bg_dark = "#121815"
        c.bg_float = "#1c2420"
        c.bg_highlight = "#2a3833"
        c.bg_popup = "#1c2420"
        c.bg_search = "#2a3833"
        c.bg_sidebar = "#121815"
        c.bg_statusline = "#121815"
        c.bg_visual = "#2a3833"
        c.border = "#5a6b62"
        c.fg = "#e6e2d4"
        c.fg_dark = "#cfc9b8"
        c.fg_float = "#e6e2d4"
        c.fg_gutter = "#5a6b62"
        c.fg_sidebar = "#cfc9b8"
        c.comment = "#5a6b62"
        c.red = "#c96a6a"
        c.green = "#7fd6b5"
        c.yellow = "#d9b36c"
        c.blue = "#7aa8c9"
        c.magenta = "#b49ae0"
        c.cyan = "#6fc2c2"
        c.orange = "#d9b36c"
        c.teal = "#6fc2c2"
        c.purple = "#b49ae0"
      end,
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
