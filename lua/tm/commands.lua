-- Модуль команд плагина
local M = {}
local core = require("tm.core")
local telescope = require("tm.telescope")

-- Парсинг аргумента -p [id]
local function parse_space_id(args)
  for i, arg in ipairs(args) do
    if arg == "-p" and args[i + 1] then
      return tonumber(args[i + 1])
    end
  end
  return nil
end

-- Команда: TmAddNote
function M.add_note(opts)
  -- Проверяем установку tm
  if not core.is_tm_installed() then
    vim.notify(
      "tm не установлен. Установите его из https://github.com/Chupik13/TaskManager",
      vim.log.levels.ERROR
    )
    return
  end

  local space_id = parse_space_id(opts.fargs)

  -- Запрашиваем текст заметки через vim.ui.input
  vim.ui.input({
    prompt = "Текст заметки: ",
  }, function(text)
    if not text or text == "" then
      vim.notify("Заметка не может быть пустой", vim.log.levels.WARN)
      return
    end

    -- Проверяем наличие workspace и инициализируем если нужно
    if not core.workspace_exists() and not space_id then
      core.init_workspace(function(result)
        if result.success then
          core.add_note(text, space_id)
        end
      end)
    else
      core.add_note(text, space_id)
    end
  end)
end

-- Команда: TmList
function M.list(opts)
  if not core.is_tm_installed() then
    vim.notify("tm не установлен", vim.log.levels.ERROR)
    return
  end

  local space_id = parse_space_id(opts.fargs)

  -- Проверяем наличие workspace
  if not core.workspace_exists() and not space_id then
    vim.notify("Рабочее пространство не инициализировано. Используйте :TmAddNote для создания.", vim.log.levels.WARN)
    return
  end

  telescope.list_notes(space_id)
end

-- Команда: TmGlobalList
function M.global_list()
  if not core.is_tm_installed() then
    vim.notify("tm не установлен", vim.log.levels.ERROR)
    return
  end

  telescope.global_list()
end

-- Команда: TmInit (опциональная, для ручной инициализации)
function M.init()
  if not core.is_tm_installed() then
    vim.notify("tm не установлен", vim.log.levels.ERROR)
    return
  end

  core.init_workspace()
end

-- Регистрация всех команд
function M.setup()
  vim.api.nvim_create_user_command("TmAddNote", M.add_note, {
    nargs = "*",
    desc = "Добавить новую заметку",
  })

  vim.api.nvim_create_user_command("TmList", M.list, {
    nargs = "*",
    desc = "Показать список заметок",
  })

  vim.api.nvim_create_user_command("TmGlobalList", M.global_list, {
    nargs = 0,
    desc = "Показать все заметки из всех пространств",
  })

  vim.api.nvim_create_user_command("TmInit", M.init, {
    nargs = 0,
    desc = "Инициализировать рабочее пространство",
  })
end

return M
