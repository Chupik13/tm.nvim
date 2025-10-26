-- Модуль конфигурации плагина tm.nvim
local M = {}

-- Дефолтная конфигурация
M.defaults = {
  -- Автоматический compact после архивирования
  auto_compact = true,

  -- Лимит символов для truncate в списках
  truncate_limit = 50,

  -- Интеграция со статусной строкой
  statusline = {
    enabled = true,
    format = "TM: %d", -- %d заменяется на количество заметок
  },

  -- Ключевые привязки (можно переопределить)
  mappings = {
    add_note = "<leader>ta",
    list = "<leader>tl",
    global_list = "<leader>tL",
  },

  -- Настройки Telescope
  telescope = {
    theme = "dropdown", -- или "ivy", "cursor"
    layout_config = {
      width = 0.8,
      height = 0.7,
    },
  },
}

-- Текущая конфигурация (будет заполнена в setup)
M.options = {}

-- Функция для объединения конфигураций
function M.setup(user_config)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_config or {})
  return M.options
end

return M
