-- Пример конфигурации tm.nvim для различных менеджеров плагинов

-- ============================================================
-- lazy.nvim (рекомендуется)
-- ============================================================

-- Минимальная конфигурация
{
  "yourusername/tm.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("tm").setup()
  end,
}

-- Полная конфигурация с настройками
{
  "yourusername/tm.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  opts = {
    auto_compact = true,
    truncate_limit = 60,
    statusline = {
      enabled = true,
      format = "📝 %d",
    },
    mappings = {
      add_note = "<leader>ta",
      list = "<leader>tl",
      global_list = "<leader>tL",
      find = "<leader>tf",
      find_global = "<leader>tF",
    },
    telescope = {
      theme = "ivy",
      layout_config = {
        height = 0.8,
      },
    },
  },
  keys = {
    { "<leader>ta", "<cmd>TmAddNote<cr>", desc = "Добавить заметку" },
    { "<leader>tl", "<cmd>TmList<cr>", desc = "Список заметок" },
    { "<leader>tL", "<cmd>TmGlobalList<cr>", desc = "Глобальный список" },
  },
}

-- С интеграцией lualine
{
  "yourusername/tm.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-lualine/lualine.nvim",
  },
  config = function()
    require("tm").setup({
      statusline = {
        enabled = true,
        format = "TM: %d",
      },
    })

    -- Добавить компонент в lualine
    require("lualine").setup({
      sections = {
        lualine_x = {
          require("tm").statusline,
          "encoding",
          "fileformat",
          "filetype",
        },
      },
    })
  end,
}

-- ============================================================
-- packer.nvim
-- ============================================================

use {
  "yourusername/tm.nvim",
  requires = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("tm").setup({
      auto_compact = true,
      truncate_limit = 50,
      mappings = {
        add_note = "<leader>ta",
        list = "<leader>tl",
        global_list = "<leader>tL",
        find = "<leader>tf",
        find_global = "<leader>tF",
      },
    })
  end,
}

-- ============================================================
-- vim-plug
-- ============================================================

-- В .vimrc или init.vim:
--[[
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'yourusername/tm.nvim'

lua << EOF
require("tm").setup({
  auto_compact = true,
  truncate_limit = 50,
  mappings = {
    add_note = "<leader>ta",
    list = "<leader>tl",
    global_list = "<leader>tL",
    find = "<leader>tf",
    find_global = "<leader>tF",
  },
})
EOF
]]

-- ============================================================
-- Отключение автоматических ключевых привязок
-- ============================================================

require("tm").setup({
  mappings = {
    add_note = false,
    list = false,
    global_list = false,
    find = false,
    find_global = false,
  },
})

-- Установка своих привязок
vim.keymap.set("n", "<C-n>", ":TmAddNote<CR>", { desc = "Новая заметка" })
vim.keymap.set("n", "<C-l>", ":TmList<CR>", { desc = "Список" })

-- ============================================================
-- Отключение статусной строки
-- ============================================================

require("tm").setup({
  statusline = {
    enabled = false,
  },
})

-- ============================================================
-- Изменение темы Telescope
-- ============================================================

require("tm").setup({
  telescope = {
    theme = "cursor",  -- или "dropdown", "ivy"
    layout_config = {
      width = 0.9,
      height = 0.8,
      preview_width = 0.6,
    },
  },
})

-- ============================================================
-- Отключение автоматической компактизации
-- ============================================================

require("tm").setup({
  auto_compact = false,
})

-- Вызов компактизации вручную через команду tm CLI:
-- :!tm compact
