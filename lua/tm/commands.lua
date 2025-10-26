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
      "tm не установлен. Установите его из https://github.com/yourusername/tm",
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

-- Команда: TmFind
function M.find(opts)
  if not core.is_tm_installed() then
    vim.notify("tm не установлен", vim.log.levels.ERROR)
    return
  end

  -- Парсим аргументы: текст для поиска и опциональный -p [id]
  local args = opts.fargs
  local search_text = ""
  local space_id = nil
  local i = 1

  while i <= #args do
    if args[i] == "-p" and args[i + 1] then
      space_id = tonumber(args[i + 1])
      i = i + 2
    else
      if search_text ~= "" then
        search_text = search_text .. " "
      end
      search_text = search_text .. args[i]
      i = i + 1
    end
  end

  if search_text == "" then
    vim.notify("Необходимо указать текст для поиска", vim.log.levels.WARN)
    return
  end

  telescope.find_notes(search_text, space_id)
end

-- Команда: TmFindGlobal
function M.find_global(opts)
  if not core.is_tm_installed() then
    vim.notify("tm не установлен", vim.log.levels.ERROR)
    return
  end

  local search_text = table.concat(opts.fargs, " ")

  if search_text == "" then
    vim.notify("Необходимо указать текст для поиска", vim.log.levels.WARN)
    return
  end

  telescope.find_global(search_text)
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

  vim.api.nvim_create_user_command("TmFind", M.find, {
    nargs = "+",
    desc = "Найти заметки по тексту",
  })

  vim.api.nvim_create_user_command("TmFindGlobal", M.find_global, {
    nargs = "+",
    desc = "Глобальный поиск заметок",
  })

  vim.api.nvim_create_user_command("TmInit", M.init, {
    nargs = 0,
    desc = "Инициализировать рабочее пространство",
  })
end

return M
