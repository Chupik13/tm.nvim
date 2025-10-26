-- Модуль интеграции со статусной строкой (lualine)
local M = {}
local config = require("tm.config")

-- Кэш для количества заметок
M.cached_count = 0
M.last_update = 0

-- Обновление счетчика заметок
function M.update()
  if not config.options.statusline.enabled then
    return
  end

  local core = require("tm.core")

  -- Проверяем, есть ли рабочее пространство
  if not core.workspace_exists() then
    M.cached_count = 0
    return
  end

  core.get_active_count(function(count)
    M.cached_count = count
    M.last_update = os.time()

    -- Обновить lualine если доступен
    local ok = pcall(require, "lualine")
    if ok then
      require("lualine").refresh()
    end
  end)
end

-- Компонент для lualine
function M.component()
  if M.cached_count == 0 then
    return ""
  end

  return config.options.statusline.format:format(M.cached_count)
end

-- Настройка автообновления
function M.setup_autocommands()
  if not config.options.statusline.enabled then
    return
  end

  local group = vim.api.nvim_create_augroup("TmStatusline", { clear = true })

  -- Обновлять при смене директории
  vim.api.nvim_create_autocmd({ "DirChanged" }, {
    group = group,
    callback = function()
      M.update()
    end,
  })

  -- Обновлять при входе в буфер
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = group,
    callback = function()
      -- Обновлять не чаще раза в 5 секунд
      if os.time() - M.last_update > 5 then
        M.update()
      end
    end,
  })

  -- Первичное обновление
  M.update()
end

-- Получение конфигурации для lualine
function M.get_lualine_config()
  return {
    function()
      return M.component()
    end,
    cond = function()
      return M.cached_count > 0
    end,
  }
end

return M
