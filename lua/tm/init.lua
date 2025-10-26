-- Главный модуль плагина tm.nvim
local M = {}

-- Флаг инициализации
local initialized = false

-- Функция setup для инициализации плагина
function M.setup(user_config)
  if initialized then
    vim.notify("tm.nvim уже инициализирован", vim.log.levels.WARN)
    return
  end

  -- Загружаем и настраиваем конфигурацию
  local config = require("tm.config")
  config.setup(user_config or {})

  -- Проверяем зависимости
  local ok, telescope = pcall(require, "telescope")
  if not ok then
    vim.notify(
      "tm.nvim требует telescope.nvim. Установите его через ваш менеджер плагинов.",
      vim.log.levels.ERROR
    )
    return
  end

  -- Регистрируем команды
  require("tm.commands").setup()

  -- Настраиваем ключевые привязки
  M.setup_keymaps()

  -- Настраиваем автокоманды для статусной строки
  require("tm.statusline").setup_autocommands()

  initialized = true
  vim.notify("tm.nvim инициализирован", vim.log.levels.INFO)
end

-- Настройка ключевых привязок
function M.setup_keymaps()
  local config = require("tm.config")
  local mappings = config.options.mappings

  -- Регистрация ключевых привязок
  if mappings.add_note then
    vim.keymap.set("n", mappings.add_note, ":TmAddNote<CR>", { desc = "Добавить заметку" })
  end

  if mappings.list then
    vim.keymap.set("n", mappings.list, ":TmList<CR>", { desc = "Список заметок" })
  end

  if mappings.global_list then
    vim.keymap.set("n", mappings.global_list, ":TmGlobalList<CR>", { desc = "Глобальный список заметок" })
  end

  if mappings.find then
    vim.keymap.set("n", mappings.find, function()
      vim.ui.input({ prompt = "Поиск: " }, function(text)
        if text and text ~= "" then
          vim.cmd("TmFind " .. text)
        end
      end)
    end, { desc = "Поиск заметок" })
  end

  if mappings.find_global then
    vim.keymap.set("n", mappings.find_global, function()
      vim.ui.input({ prompt = "Глобальный поиск: " }, function(text)
        if text and text ~= "" then
          vim.cmd("TmFindGlobal " .. text)
        end
      end)
    end, { desc = "Глобальный поиск заметок" })
  end
end

-- Экспорт компонента для lualine
M.statusline = require("tm.statusline").get_lualine_config()

return M
