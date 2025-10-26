-- Модуль интеграции с Telescope
local M = {}
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local config = require("tm.config")
local core = require("tm.core")

-- Утилита для truncate текста
local function truncate_text(text, limit)
  limit = limit or config.options.truncate_limit
  if #text > limit then
    return text:sub(1, limit - 3) .. "..."
  end
  return text
end

-- Создание превью для заметки
local function create_note_previewer()
  return previewers.new_buffer_previewer({
    title = "Текст заметки",
    define_preview = function(self, entry)
      local lines = {}
      if entry.full_text then
        -- Разбиваем текст на строки
        for line in entry.full_text:gmatch("[^\r\n]+") do
          table.insert(lines, line)
        end
      else
        table.insert(lines, entry.value)
      end

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
    end,
  })
end

-- Действия для заметок
local function create_note_actions(space_id, refresh_fn)
  return function(prompt_bufnr, map)
    -- Действие: удалить заметку
    local delete_note = function()
      local selection = action_state.get_selected_entry()
      if not selection then
        return
      end

      vim.ui.select({ "Да", "Нет" }, {
        prompt = "Удалить заметку " .. selection.note_id .. "?",
      }, function(choice)
        if choice == "Да" then
          actions.close(prompt_bufnr)
          core.remove_note(selection.note_id, space_id, function(result)
            if result.success and refresh_fn then
              refresh_fn()
            end
          end)
        end
      end)
    end

    -- Действие: архивировать заметку
    local archive_note = function()
      local selection = action_state.get_selected_entry()
      if not selection then
        return
      end

      actions.close(prompt_bufnr)
      core.archive_note(selection.note_id, space_id, function(result)
        if result.success and refresh_fn then
          refresh_fn()
        end
      end)
    end

    -- Действие: открыть в split для редактирования
    local edit_note = function()
      local selection = action_state.get_selected_entry()
      if not selection then
        return
      end

      actions.close(prompt_bufnr)

      -- Создаем временный буфер для редактирования
      vim.cmd("split")
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, buf)

      -- Устанавливаем имя буфера (чтобы :w работал)
      vim.api.nvim_buf_set_name(buf, "tm-note-" .. selection.note_id)

      -- Заполняем текстом заметки
      local lines = {}
      for line in selection.full_text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
      end
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

      -- Настраиваем буфер
      vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
      vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
      vim.api.nvim_buf_set_option(buf, "modified", false)

      -- Создаем команду для сохранения
      vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
          local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")

          -- Удаляем старую и добавляем новую
          core.remove_note(selection.note_id, space_id, function(result)
            if result.success then
              core.add_note(content, space_id, function(add_result)
                if add_result.success then
                  vim.notify("Заметка обновлена", vim.log.levels.INFO)
                  -- Сбрасываем флаг modified и закрываем буфер
                  vim.api.nvim_buf_set_option(buf, "modified", false)
                  vim.cmd("bdelete!")
                end
              end)
            end
          end)
        end,
      })
    end

    -- Регистрируем привязки клавиш
    map("n", "d", delete_note)
    map("i", "<C-d>", delete_note)
    map("n", "a", archive_note)
    map("i", "<C-a>", archive_note)

    actions.select_default:replace(edit_note)

    return true
  end
end

-- TmList: показать заметки текущего пространства
function M.list_notes(space_id)
  core.list_notes(space_id, false, function(result)
    if not result.success then
      vim.notify("Не удалось получить список заметок", vim.log.levels.ERROR)
      return
    end

    if #result.notes == 0 then
      vim.notify("Нет активных заметок", vim.log.levels.INFO)
      return
    end

    local opts = require("telescope.themes")["get_" .. config.options.telescope.theme](
      config.options.telescope.layout_config
    )

    local refresh_fn = function()
      M.list_notes(space_id)
    end

    opts.attach_mappings = create_note_actions(space_id, refresh_fn)
    opts.previewer = create_note_previewer()

    pickers
      .new(opts, {
        prompt_title = "Заметки" .. (space_id and (" (пространство " .. space_id .. ")") or ""),
        finder = finders.new_table({
          results = result.notes,
          entry_maker = function(note)
            return {
              value = note.text,
              display = "[" .. note.id .. "]: " .. truncate_text(note.text),
              ordinal = note.text,
              note_id = note.id,
              full_text = note.text,
            }
          end,
        }),
        sorter = conf.generic_sorter(opts),
      })
      :find()
  end)
end

-- TmGlobalList: иерархический список workspace -> notes с collapse/expand
function M.global_list()
  -- Состояние для отслеживания expanded/collapsed workspace
  local expanded_state = {}
  local workspace_data = {}

  -- Функция для построения плоского списка entries из иерархических данных
  local function build_entries()
    local entries = {}
    for _, ws_data in ipairs(workspace_data) do
      local workspace = ws_data.workspace
      local notes = ws_data.notes
      local is_expanded = expanded_state[workspace.id] or false

      -- Добавляем workspace entry
      local expand_icon = is_expanded and "▼" or "▶"
      local note_count = #notes
      table.insert(entries, {
        type = "workspace",
        workspace = workspace,
        display = string.format("%s [%s] (%d заметок)", expand_icon, workspace.name, note_count),
        ordinal = workspace.name,
        workspace_id = workspace.id,
      })

      -- Если expanded, добавляем notes
      if is_expanded then
        for _, note in ipairs(notes) do
          table.insert(entries, {
            type = "note",
            workspace = workspace,
            note = note,
            display = "  [" .. note.id .. "]: " .. truncate_text(note.text),
            ordinal = note.text,
            note_id = note.id,
            full_text = note.text,
            workspace_id = workspace.id,
          })
        end
      end
    end
    return entries
  end

  -- Функция для обновления picker
  local function show_picker(current_picker)
    local entries = build_entries()

    local opts = require("telescope.themes")["get_" .. config.options.telescope.theme](
      config.options.telescope.layout_config
    )

    opts.previewer = create_note_previewer()

    local new_picker = pickers.new(opts, {
      prompt_title = "Рабочие пространства и заметки",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry.display,
            display = entry.display,
            ordinal = entry.ordinal,
            type = entry.type,
            workspace = entry.workspace,
            workspace_id = entry.workspace_id,
            note = entry.note,
            note_id = entry.note_id,
            full_text = entry.full_text,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        -- Toggle expand/collapse для workspace
        local toggle_expand = function()
          local selection = action_state.get_selected_entry()
          if not selection or selection.type ~= "workspace" then
            return
          end

          local ws_id = selection.workspace_id
          expanded_state[ws_id] = not (expanded_state[ws_id] or false)

          -- Закрываем текущий picker и открываем обновленный
          actions.close(prompt_bufnr)
          show_picker()
        end

        -- Удаление workspace
        local delete_workspace = function()
          local selection = action_state.get_selected_entry()
          if not selection or selection.type ~= "workspace" then
            vim.notify("Выберите рабочее пространство для удаления", vim.log.levels.WARN)
            return
          end

          vim.ui.select({ "Да", "Нет" }, {
            prompt = "Удалить рабочее пространство '" .. selection.workspace.name .. "'?",
          }, function(choice)
            if choice == "Да" then
              actions.close(prompt_bufnr)
              core.remove_workspace(selection.workspace_id, function(result)
                if result.success then
                  M.global_list()
                end
              end)
            end
          end)
        end

        -- Архивирование workspace
        local archive_workspace = function()
          local selection = action_state.get_selected_entry()
          if not selection or selection.type ~= "workspace" then
            vim.notify("Выберите рабочее пространство для архивирования", vim.log.levels.WARN)
            return
          end

          actions.close(prompt_bufnr)
          core.archive_workspace(selection.workspace_id, function(result)
            if result.success then
              M.global_list()
            end
          end)
        end

        -- Удаление note
        local delete_note = function()
          local selection = action_state.get_selected_entry()
          if not selection or selection.type ~= "note" then
            vim.notify("Выберите заметку для удаления", vim.log.levels.WARN)
            return
          end

          vim.ui.select({ "Да", "Нет" }, {
            prompt = "Удалить заметку " .. selection.note_id .. "?",
          }, function(choice)
            if choice == "Да" then
              actions.close(prompt_bufnr)
              core.remove_note(selection.note_id, selection.workspace_id, function(result)
                if result.success then
                  M.global_list()
                end
              end)
            end
          end)
        end

        -- Архивирование note
        local archive_note = function()
          local selection = action_state.get_selected_entry()
          if not selection or selection.type ~= "note" then
            vim.notify("Выберите заметку для архивирования", vim.log.levels.WARN)
            return
          end

          actions.close(prompt_bufnr)
          core.archive_note(selection.note_id, selection.workspace_id, function(result)
            if result.success then
              M.global_list()
            end
          end)
        end

        -- Редактирование note
        local edit_note = function()
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end

          -- Если workspace - toggle expand
          if selection.type == "workspace" then
            toggle_expand()
            return
          end

          -- Если note - редактировать
          actions.close(prompt_bufnr)

          vim.cmd("split")
          local buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_win_set_buf(0, buf)

          vim.api.nvim_buf_set_name(buf, "tm-note-" .. selection.note_id)

          local lines = {}
          for line in selection.full_text:gmatch("[^\r\n]+") do
            table.insert(lines, line)
          end
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

          vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
          vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
          vim.api.nvim_buf_set_option(buf, "modified", false)

          vim.api.nvim_create_autocmd("BufWriteCmd", {
            buffer = buf,
            callback = function()
              local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")

              core.remove_note(selection.note_id, selection.workspace_id, function(result)
                if result.success then
                  core.add_note(content, selection.workspace_id, function(add_result)
                    if add_result.success then
                      vim.notify("Заметка обновлена", vim.log.levels.INFO)
                      vim.api.nvim_buf_set_option(buf, "modified", false)
                      vim.cmd("bdelete!")
                    end
                  end)
                end
              end)
            end,
          })
        end

        -- Маппинги
        -- d - удаление (workspace или note в зависимости от выбора)
        map("n", "d", function()
          local selection = action_state.get_selected_entry()
          if selection.type == "workspace" then
            delete_workspace()
          else
            delete_note()
          end
        end)
        map("i", "<C-d>", function()
          local selection = action_state.get_selected_entry()
          if selection.type == "workspace" then
            delete_workspace()
          else
            delete_note()
          end
        end)

        -- a - архивирование (workspace или note)
        map("n", "a", function()
          local selection = action_state.get_selected_entry()
          if selection.type == "workspace" then
            archive_workspace()
          else
            archive_note()
          end
        end)
        map("i", "<C-a>", function()
          local selection = action_state.get_selected_entry()
          if selection.type == "workspace" then
            archive_workspace()
          else
            archive_note()
          end
        end)

        -- Enter - toggle для workspace, edit для note
        actions.select_default:replace(edit_note)

        return true
      end,
    })

    new_picker:find()
  end

  -- Загрузка данных
  core.list_workspaces(function(workspace_result)
    if not workspace_result.success or #workspace_result.workspaces == 0 then
      vim.notify("Нет рабочих пространств", vim.log.levels.INFO)
      return
    end

    local remaining = #workspace_result.workspaces

    for _, workspace in ipairs(workspace_result.workspaces) do
      core.list_notes(workspace.id, false, function(notes_result)
        local notes = notes_result.success and notes_result.notes or {}

        table.insert(workspace_data, {
          workspace = workspace,
          notes = notes,
        })

        remaining = remaining - 1

        if remaining == 0 then
          -- Все данные загружены, показываем picker
          show_picker()
        end
      end)
    end
  end)
end

return M
