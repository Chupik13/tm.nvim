-- Основной модуль для работы с tm CLI
local M = {}
local config = require("tm.config")

-- Проверка установки tm
function M.is_tm_installed()
  local handle = io.popen("tm --version 2>&1")
  if not handle then
    return false
  end
  local result = handle:read("*a")
  handle:close()
  return result ~= nil and result ~= ""
end

-- Проверка наличия рабочего пространства в текущей директории
function M.workspace_exists()
  local path = vim.fn.getcwd() .. "/.tm/tasks.json"
  return vim.fn.filereadable(path) == 1
end

-- Выполнение команды tm асинхронно
function M.execute_tm_command(args, on_exit)
  local cmd = { "tm" }
  vim.list_extend(cmd, args)

  vim.system(cmd, {
    text = true,
    cwd = vim.fn.getcwd(),
  }, function(obj)
    vim.schedule(function()
      if on_exit then
        on_exit(obj)
      end
    end)
  end)
end

-- Инициализация рабочего пространства
function M.init_workspace(callback)
  if M.workspace_exists() then
    if callback then
      callback({ success = true, message = "Рабочее пространство уже существует" })
    end
    return
  end

  M.execute_tm_command({ "init" }, function(obj)
    if obj.code == 0 then
      vim.notify("Рабочее пространство инициализировано", vim.log.levels.INFO)
      if callback then
        callback({ success = true, output = obj.stdout })
      end
    else
      vim.notify("Ошибка инициализации: " .. (obj.stderr or ""), vim.log.levels.ERROR)
      if callback then
        callback({ success = false, error = obj.stderr })
      end
    end
  end)
end

-- Добавление заметки
function M.add_note(text, space_id, callback)
  local args = { "add", text }
  if space_id then
    table.insert(args, "-p")
    table.insert(args, tostring(space_id))
  end

  M.execute_tm_command(args, function(obj)
    if obj.code == 0 then
      vim.notify("Заметка добавлена", vim.log.levels.INFO)
      if callback then
        callback({ success = true, output = obj.stdout })
      end
      -- Обновить статусную строку
      require("tm.statusline").update()
    else
      vim.notify("Ошибка добавления заметки: " .. (obj.stderr or ""), vim.log.levels.ERROR)
      if callback then
        callback({ success = false, error = obj.stderr })
      end
    end
  end)
end

-- Получение списка заметок
function M.list_notes(space_id, global, callback)
  local args = { "list" }
  if global then
    table.insert(args, "-g")
  elseif space_id then
    table.insert(args, "-p")
    table.insert(args, tostring(space_id))
  end

  M.execute_tm_command(args, function(obj)
    if obj.code == 0 then
      local notes = M.parse_notes_list(obj.stdout)
      if callback then
        callback({ success = true, notes = notes, raw = obj.stdout })
      end
    else
      vim.notify("Ошибка получения списка: " .. (obj.stderr or ""), vim.log.levels.ERROR)
      if callback then
        callback({ success = false, error = obj.stderr })
      end
    end
  end)
end

-- Парсинг списка заметок
-- Формат: [id]: [text]
function M.parse_notes_list(output)
  local notes = {}
  if not output or output == "" then
    return notes
  end

  for line in output:gmatch("[^\r\n]+") do
    local id, text = line:match("^%[?(%d+)%]?:%s*(.+)$")
    if id and text then
      table.insert(notes, {
        id = tonumber(id),
        text = text,
      })
    end
  end

  return notes
end

-- Удаление заметки
function M.remove_note(note_id, space_id, callback)
  local args = { "remove", tostring(note_id) }
  if space_id then
    table.insert(args, "-p")
    table.insert(args, tostring(space_id))
  end

  M.execute_tm_command(args, function(obj)
    if obj.code == 0 then
      vim.notify("Заметка " .. note_id .. " удалена", vim.log.levels.INFO)
      if callback then
        callback({ success = true })
      end
      require("tm.statusline").update()
    else
      vim.notify("Ошибка удаления: " .. (obj.stderr or ""), vim.log.levels.ERROR)
      if callback then
        callback({ success = false, error = obj.stderr })
      end
    end
  end)
end

-- Архивирование заметки
function M.archive_note(note_id, space_id, callback)
  local args = { "archive", tostring(note_id) }
  if space_id then
    table.insert(args, "-p")
    table.insert(args, tostring(space_id))
  end

  M.execute_tm_command(args, function(obj)
    if obj.code == 0 then
      vim.notify("Заметка " .. note_id .. " архивирована", vim.log.levels.INFO)

      -- Автоматический compact если включен
      if config.options.auto_compact then
        M.compact_notes(space_id, callback)
      elseif callback then
        callback({ success = true })
      end

      require("tm.statusline").update()
    else
      vim.notify("Ошибка архивирования: " .. (obj.stderr or ""), vim.log.levels.ERROR)
      if callback then
        callback({ success = false, error = obj.stderr })
      end
    end
  end)
end

-- Компактизация ID заметок
function M.compact_notes(space_id, callback)
  local args = { "compact" }
  if space_id then
    table.insert(args, "-p")
    table.insert(args, tostring(space_id))
  end

  M.execute_tm_command(args, function(obj)
    if obj.code == 0 then
      vim.notify("Компактизация выполнена", vim.log.levels.INFO)
      if callback then
        callback({ success = true })
      end
      require("tm.statusline").update()
    else
      vim.notify("Ошибка компактизации: " .. (obj.stderr or ""), vim.log.levels.ERROR)
      if callback then
        callback({ success = false, error = obj.stderr })
      end
    end
  end)
end

-- Получение списка рабочих пространств
function M.list_workspaces(callback)
  M.execute_tm_command({ "plist" }, function(obj)
    if obj.code == 0 then
      local workspaces = M.parse_workspaces_list(obj.stdout)
      if callback then
        callback({ success = true, workspaces = workspaces, raw = obj.stdout })
      end
    else
      vim.notify("Ошибка получения списка пространств: " .. (obj.stderr or ""), vim.log.levels.ERROR)
      if callback then
        callback({ success = false, error = obj.stderr })
      end
    end
  end)
end

-- Парсинг списка рабочих пространств
-- Формат: [id]: [name] ([path])
function M.parse_workspaces_list(output)
  local workspaces = {}
  if not output or output == "" then
    return workspaces
  end

  for line in output:gmatch("[^\r\n]+") do
    local id, name, path = line:match("^%[?(%d+)%]?:%s*([^%(]+)%s*%(([^%)]+)%)$")
    if id and name and path then
      table.insert(workspaces, {
        id = tonumber(id),
        name = vim.trim(name),
        path = vim.trim(path),
      })
    end
  end

  return workspaces
end

-- Получение количества активных заметок для статусной строки
function M.get_active_count(callback)
  M.list_notes(nil, false, function(result)
    if result.success then
      if callback then
        callback(#result.notes)
      end
    else
      if callback then
        callback(0)
      end
    end
  end)
end

return M
