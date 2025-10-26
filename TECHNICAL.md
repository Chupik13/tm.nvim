# Техническая документация tm.nvim

Этот документ предназначен для разработчиков и пользователей, желающих понять внутреннее устройство плагина tm.nvim.

## Оглавление

- [Архитектура](#архитектура)
- [Структура проекта](#структура-проекта)
- [Модули](#модули)
- [Процессы и потоки данных](#процессы-и-потоки-данных)
- [Интеграция с tm CLI](#интеграция-с-tm-cli)
- [Работа с Telescope](#работа-с-telescope)
- [Асинхронность](#асинхронность)
- [Расширение функциональности](#расширение-функциональности)

## Архитектура

tm.nvim построен по модульной архитектуре, где каждый модуль отвечает за свою область функциональности:

```
tm.nvim
├── Конфигурация (config.lua)
├── Ядро (core.lua)
│   └── Взаимодействие с tm CLI
├── UI слой (telescope.lua)
│   └── Telescope pickers и actions
├── Статусная строка (statusline.lua)
│   └── Интеграция с lualine
├── Команды (commands.lua)
│   └── Neovim user commands
└── Entry point (init.lua)
    └── setup() и координация модулей
```

## Структура проекта

```
tm.nvim/
├── lua/tm/           # Основные модули плагина
│   ├── init.lua      # Entry point, функция setup()
│   ├── config.lua    # Конфигурация и дефолтные настройки
│   ├── core.lua      # Логика работы с tm CLI
│   ├── telescope.lua # Интеграция с Telescope
│   ├── statusline.lua# Интеграция с lualine
│   └── commands.lua  # Регистрация Neovim команд
├── plugin/           # Автозагрузка плагина
│   └── tm.lua        # Проверка версии и защита от повторной загрузки
├── README.md         # Документация для пользователей
└── TECHNICAL.md      # Техническая документация (этот файл)
```

## Модули

### lua/tm/init.lua

**Назначение:** Главная точка входа в плагин. Координирует инициализацию всех подмодулей.

**Основные функции:**

- `setup(user_config)` - инициализация плагина
  - Проверяет, что плагин еще не инициализирован
  - Настраивает конфигурацию через `config.setup()`
  - Проверяет наличие зависимостей (telescope.nvim)
  - Регистрирует команды через `commands.setup()`
  - Настраивает ключевые привязки через `setup_keymaps()`
  - Инициализирует автокоманды статусной строки

- `setup_keymaps()` - регистрирует ключевые привязки
  - Читает mappings из конфигурации
  - Создает keymap для каждой команды
  - Для команд поиска использует `vim.ui.input` для ввода текста

**Экспорт:**
- `statusline` - компонент для lualine

### lua/tm/config.lua

**Назначение:** Управление конфигурацией плагина.

**Структура данных:**

```lua
M.defaults = {
  auto_compact = true,           -- Автокомпактизация после архивирования
  truncate_limit = 50,           -- Лимит символов в списках
  statusline = {
    enabled = true,
    format = "TM: %d",           -- Формат отображения в статусной строке
  },
  mappings = {                   -- Ключевые привязки
    add_note = "<leader>ta",
    list = "<leader>tl",
    global_list = "<leader>tL",
    find = "<leader>tf",
    find_global = "<leader>tF",
  },
  telescope = {                  -- Настройки Telescope
    theme = "dropdown",
    layout_config = {
      width = 0.8,
      height = 0.7,
    },
  },
}
```

**Основные функции:**

- `setup(user_config)` - объединяет пользовательскую конфигурацию с дефолтной
  - Использует `vim.tbl_deep_extend("force", defaults, user_config)`
  - Сохраняет результат в `M.options`

### lua/tm/core.lua

**Назначение:** Ядро плагина, отвечающее за взаимодействие с tm CLI.

**Основные функции:**

- `is_tm_installed()` - проверяет установку tm
  - Выполняет `tm --version` через `io.popen`
  - Возвращает `true/false`

- `workspace_exists()` - проверяет наличие workspace
  - Проверяет существование файла `.tm/tasks.json` в текущей директории
  - Использует `vim.fn.getcwd()` и `vim.fn.filereadable()`

- `execute_tm_command(args, on_exit)` - выполняет команду tm асинхронно
  - Использует `vim.system()` для асинхронного выполнения
  - Callback оборачивается в `vim.schedule()` для безопасности
  - Параметры:
    - `args` - массив аргументов команды
    - `on_exit` - callback с результатом `{ code, stdout, stderr }`

- `init_workspace(callback)` - инициализирует workspace
  - Проверяет, существует ли уже workspace
  - Выполняет `tm init`
  - Уведомляет пользователя через `vim.notify`

- `add_note(text, space_id, callback)` - добавляет заметку
  - Формирует команду `tm add [text] [-p space_id]`
  - Обновляет статусную строку после успеха

- `list_notes(space_id, global, callback)` - получает список заметок
  - Формирует команду `tm list [-p space_id] [-g]`
  - Парсит вывод через `parse_notes_list()`

- `parse_notes_list(output)` - парсинг вывода `tm list`
  - Формат: `[id]: [text]`
  - Использует паттерн: `"^%[?(%d+)%]?:%s*(.+)$"`
  - Возвращает массив: `{ { id = number, text = string }, ... }`

- `remove_note(note_id, space_id, callback)` - удаляет заметку
- `archive_note(note_id, space_id, callback)` - архивирует заметку
  - После архивирования автоматически вызывает `compact_notes()` если `auto_compact = true`

- `compact_notes(space_id, callback)` - компактизирует ID
- `find_notes(search_text, space_id, global, callback)` - поиск заметок
  - Парсит результаты через `parse_find_results()`

- `parse_find_results(output)` - парсинг вывода `tm find`
  - Формат: `ID: [id], ...[контекст]...`
  - Паттерн: `"^ID:%s*(%d+),%s*(.+)$"`

- `list_workspaces(callback)` - получает список пространств
  - Выполняет `tm plist`
  - Парсит через `parse_workspaces_list()`

- `parse_workspaces_list(output)` - парсинг вывода `tm plist`
  - Формат: `[id]: [name] ([path])`
  - Паттерн: `"^%[?(%d+)%]?:%s*([^%(]+)%s*%(([^%)]+)%)$"`

- `get_active_count(callback)` - получает количество активных заметок
  - Используется для статусной строки

### lua/tm/telescope.lua

**Назначение:** Интеграция с Telescope для отображения пикеров и действий над заметками.

**Внутренние функции:**

- `truncate_text(text, limit)` - обрезает текст до лимита
  - По умолчанию использует `config.options.truncate_limit`

- `create_note_previewer()` - создает previewer для заметок
  - Использует `previewers.new_buffer_previewer`
  - Разбивает текст заметки на строки
  - Устанавливает `filetype = "markdown"` для подсветки

- `create_note_actions(space_id, refresh_fn)` - создает actions для заметок
  - **delete_note** - удаление с подтверждением через `vim.ui.select`
  - **archive_note** - архивирование (с auto-compact)
  - **edit_note** - редактирование в split-буфере
    - Создает новый буфер через `vim.api.nvim_create_buf`
    - Устанавливает `buftype = "acwrite"`
    - Регистрирует autocmd на `BufWriteCmd` для сохранения
    - При сохранении: удаляет старую заметку + добавляет новую

  Привязки клавиш:
  - `d` (normal) / `<C-d>` (insert) - удалить
  - `a` (normal) / `<C-a>` (insert) - архивировать
  - `<CR>` - редактировать

**Основные функции:**

- `list_notes(space_id)` - показывает заметки в picker
  - Получает заметки через `core.list_notes()`
  - Создает Telescope picker с темой из конфигурации
  - Entry maker: `[id]: truncated_text`
  - Добавляет previewer и actions

- `global_list()` - глобальный список заметок
  - Получает все workspace через `core.list_workspaces()`
  - Для каждого workspace получает заметки
  - Объединяет все в `all_entries`
  - Entry maker: `[workspace_name] [id]: truncated_text`
  - Actions учитывают `workspace_id`

- `find_notes(search_text, space_id)` - поиск в пространстве
  - Выполняет `core.find_notes()`
  - Отображает результаты с контекстом
  - Entry maker: `[id]: context`

- `find_global(search_text)` - глобальный поиск
  - Выполняет `core.find_notes(..., global=true)`
  - Simplified actions (нет workspace_id в парсинге)

### lua/tm/statusline.lua

**Назначение:** Интеграция со статусной строкой (lualine).

**Кэширование:**

```lua
M.cached_count = 0     -- Кэшированное количество заметок
M.last_update = 0      -- Timestamp последнего обновления
```

**Основные функции:**

- `update()` - обновляет счетчик заметок
  - Проверяет наличие workspace
  - Получает количество через `core.get_active_count()`
  - Обновляет кэш и timestamp
  - Вызывает `require("lualine").refresh()` если доступен

- `component()` - возвращает строку для lualine
  - Форматирует `cached_count` через `config.options.statusline.format`
  - Возвращает пустую строку если заметок нет

- `setup_autocommands()` - настраивает автообновление
  - Autocmd на `DirChanged` - обновление при смене директории
  - Autocmd на `BufEnter` - обновление не чаще раза в 5 секунд
  - Вызывает первичное обновление

- `get_lualine_config()` - возвращает конфигурацию для lualine
  - Функция: `M.component()`
  - Условие: `M.cached_count > 0`

### lua/tm/commands.lua

**Назначение:** Регистрация пользовательских команд Neovim.

**Вспомогательные функции:**

- `parse_space_id(args)` - парсинг аргумента `-p [id]`
  - Ищет `-p` в массиве аргументов
  - Возвращает следующий элемент как number или nil

**Основные функции:**

- `add_note(opts)` - обработчик `:TmAddNote`
  - Проверяет установку tm
  - Парсит space_id из аргументов
  - Открывает `vim.ui.input` для ввода текста
  - Инициализирует workspace если нужно
  - Вызывает `core.add_note()`

- `list(opts)` - обработчик `:TmList`
  - Проверяет workspace
  - Вызывает `telescope.list_notes()`

- `global_list()` - обработчик `:TmGlobalList`
  - Вызывает `telescope.global_list()`

- `find(opts)` - обработчик `:TmFind`
  - Парсит текст поиска и space_id из аргументов
  - Поддерживает пробелы в тексте поиска
  - Вызывает `telescope.find_notes()`

- `find_global(opts)` - обработчик `:TmFindGlobal`
  - Объединяет все аргументы в строку поиска
  - Вызывает `telescope.find_global()`

- `init()` - обработчик `:TmInit`
  - Ручная инициализация workspace

- `setup()` - регистрирует все команды
  - Использует `vim.api.nvim_create_user_command()`
  - Указывает `nargs` и `desc` для каждой команды

## Процессы и потоки данных

### Инициализация плагина

```
Пользователь вызывает setup()
    ↓
init.lua проверяет initialized flag
    ↓
config.setup() объединяет конфигурацию
    ↓
Проверка зависимостей (telescope)
    ↓
commands.setup() регистрирует команды
    ↓
setup_keymaps() регистрирует привязки
    ↓
statusline.setup_autocommands() настраивает autocmd
    ↓
Плагин готов к работе
```

### Добавление заметки (TmAddNote)

```
Пользователь нажимает <leader>ta или :TmAddNote
    ↓
commands.add_note() вызывается
    ↓
Проверка установки tm (core.is_tm_installed)
    ↓
vim.ui.input() запрашивает текст заметки
    ↓
Пользователь вводит текст и нажимает Enter
    ↓
Проверка workspace (core.workspace_exists)
    ↓
Если нет workspace → core.init_workspace()
    │                       ↓
    │                   tm init выполняется асинхронно
    │                       ↓
    │                   Callback вызывает core.add_note()
    ↓
core.add_note() формирует команду
    ↓
vim.system() выполняет tm add [text] [-p id]
    ↓
Callback получает результат
    ↓
vim.notify() показывает результат
    ↓
statusline.update() обновляет счетчик
```

### Просмотр заметок (TmList)

```
Пользователь нажимает <leader>tl или :TmList
    ↓
commands.list() вызывается
    ↓
Проверка workspace
    ↓
telescope.list_notes() вызывается
    ↓
core.list_notes() получает список асинхронно
    ↓
Callback получает массив заметок
    ↓
parse_notes_list() парсит вывод tm list
    ↓
Telescope picker создается
    ↓
Entry maker форматирует каждую заметку
    ↓
Previewer показывает полный текст справа
    ↓
Пользователь взаимодействует с picker:
    │
    ├─ <CR> → edit_note()
    │           ↓
    │       Создается split-буфер
    │           ↓
    │       BufWriteCmd autocmd регистрируется
    │           ↓
    │       Пользователь редактирует и :w
    │           ↓
    │       remove_note() + add_note()
    │
    ├─ d → delete_note()
    │       ↓
    │   vim.ui.select для подтверждения
    │       ↓
    │   core.remove_note()
    │       ↓
    │   Refresh picker
    │
    └─ a → archive_note()
            ↓
        core.archive_note()
            ↓
        core.compact_notes() (если auto_compact)
            ↓
        Refresh picker
```

### Обновление статусной строки

```
Событие: DirChanged или BufEnter
    ↓
statusline.update() вызывается
    ↓
Проверка workspace_exists()
    ↓
core.get_active_count() получает количество
    ↓
Callback обновляет cached_count
    ↓
require("lualine").refresh() вызывается
    ↓
lualine вызывает statusline.component()
    ↓
Возвращается отформатированная строка "TM: 5"
```

## Интеграция с tm CLI

### Выполнение команд

Все команды tm выполняются асинхронно через `vim.system()`:

```lua
vim.system({ "tm", "list" }, {
  text = true,
  cwd = vim.fn.getcwd(),
}, function(obj)
  vim.schedule(function()
    -- obj.code - код возврата
    -- obj.stdout - стандартный вывод
    -- obj.stderr - вывод ошибок
    callback(obj)
  end)
end)
```

**Важные моменты:**

1. `text = true` - вывод в текстовом формате (не bytes)
2. `cwd = vim.fn.getcwd()` - выполнение в текущей директории
3. `vim.schedule()` - безопасное выполнение callback в главном потоке

### Парсинг вывода

Вывод tm парсится с помощью Lua паттернов:

**Список заметок:**
```lua
-- Вход: "[1]: Купить молоко"
-- Паттерн: "^%[?(%d+)%]?:%s*(.+)$"
-- Выход: { id = 1, text = "Купить молоко" }
```

**Результаты поиска:**
```lua
-- Вход: "ID: 1, ...Купить молоко..."
-- Паттерн: "^ID:%s*(%d+),%s*(.+)$"
-- Выход: { id = 1, context = "...Купить молоко..." }
```

**Список пространств:**
```lua
-- Вход: "[1]: my-project (/home/user/projects/my-project)"
-- Паттерн: "^%[?(%d+)%]?:%s*([^%(]+)%s*%(([^%)]+)%)$"
-- Выход: { id = 1, name = "my-project", path = "/home/user/projects/my-project" }
```

## Работа с Telescope

### Создание picker

```lua
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values

pickers.new(opts, {
  prompt_title = "Заметки",
  finder = finders.new_table({
    results = notes_array,
    entry_maker = function(note)
      return {
        value = note.text,      -- Используется для сортировки
        display = formatted,    -- Отображается в списке
        ordinal = searchable,   -- Используется для поиска
        note_id = note.id,      -- Кастомные поля
      }
    end,
  }),
  sorter = conf.generic_sorter(opts),
  previewer = custom_previewer,
  attach_mappings = function(prompt_bufnr, map)
    -- Регистрация привязок клавиш
    map("n", "d", delete_action)
    return true
  end,
}):find()
```

### Entry maker

Entry maker преобразует данные в формат Telescope:

```lua
entry_maker = function(note)
  return {
    value = note.text,                    -- Сырое значение
    display = "[" .. note.id .. "]: " ..  -- Отображение
              truncate_text(note.text),
    ordinal = note.text,                  -- Строка для поиска
    note_id = note.id,                    -- Доп. данные
    full_text = note.text,
  }
end
```

**Поля:**
- `value` - используется если не указан `ordinal`
- `display` - что показывается в списке
- `ordinal` - по этому полю идет fuzzy search
- Остальные поля - произвольные данные, доступные в actions

### Custom actions

```lua
attach_mappings = function(prompt_bufnr, map)
  local delete_note = function()
    local selection = action_state.get_selected_entry()
    -- selection содержит все поля из entry_maker
    local note_id = selection.note_id

    actions.close(prompt_bufnr)
    core.remove_note(note_id, space_id)
  end

  map("n", "d", delete_note)
  map("i", "<C-d>", delete_note)

  return true  -- Обязательно!
end
```

## Асинхронность

### vim.system

`vim.system()` - современный способ асинхронного выполнения команд в Neovim:

```lua
vim.system(cmd, opts, on_exit)
```

**Параметры:**
- `cmd` - массив: `{ "tm", "list" }`
- `opts`:
  - `text = true` - вывод в текстовом формате
  - `cwd = "..."` - рабочая директория
- `on_exit(obj)` - callback с результатом

**Результат:**
```lua
{
  code = 0,       -- Код возврата
  stdout = "...", -- Стандартный вывод
  stderr = "...", -- Вывод ошибок
  signal = 0,     -- Сигнал (если был)
}
```

### vim.schedule

`vim.schedule()` обеспечивает безопасное выполнение кода в главном потоке Neovim:

```lua
vim.system(cmd, opts, function(obj)
  vim.schedule(function()
    -- Безопасно изменять UI, буферы, вызывать vim API
    vim.notify("Готово!")
  end)
end)
```

**Зачем нужно:**
- Callback `vim.system` выполняется в фоновом потоке
- Большинство Neovim API требуют выполнения в главном потоке
- `vim.schedule` переносит выполнение в главный поток

## Расширение функциональности

### Добавление новой команды

1. Добавьте функцию в `lua/tm/core.lua`:

```lua
function M.new_command(args, callback)
  M.execute_tm_command({ "new", args }, function(obj)
    if obj.code == 0 then
      -- Обработка успеха
      callback({ success = true })
    else
      vim.notify("Ошибка", vim.log.levels.ERROR)
      callback({ success = false })
    end
  end)
end
```

2. Добавьте команду в `lua/tm/commands.lua`:

```lua
function M.new_cmd(opts)
  if not core.is_tm_installed() then
    return
  end

  local args = table.concat(opts.fargs, " ")
  core.new_command(args)
end

-- В setup():
vim.api.nvim_create_user_command("TmNew", M.new_cmd, {
  nargs = "*",
  desc = "Новая команда",
})
```

3. Добавьте keymap в `lua/tm/init.lua`:

```lua
-- В defaults конфига:
mappings = {
  new_cmd = "<leader>tn",
}

-- В setup_keymaps():
if mappings.new_cmd then
  vim.keymap.set("n", mappings.new_cmd, ":TmNew<CR>")
end
```

### Добавление Telescope picker

```lua
-- В lua/tm/telescope.lua:

function M.new_picker()
  core.get_data(function(result)
    if not result.success then
      return
    end

    local opts = require("telescope.themes")["get_" .. config.options.telescope.theme](
      config.options.telescope.layout_config
    )

    pickers.new(opts, {
      prompt_title = "Новый picker",
      finder = finders.new_table({
        results = result.data,
        entry_maker = function(item)
          return {
            value = item.value,
            display = item.display,
            ordinal = item.value,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
    }):find()
  end)
end
```

### Интеграция с другими плагинами

#### nvim-tree

Обновление дерева файлов после операций:

```lua
-- После add_note/remove_note:
local ok, nvim_tree = pcall(require, "nvim-tree.api")
if ok then
  nvim_tree.tree.reload()
end
```

#### which-key

Описания для ключевых привязок:

```lua
local ok, which_key = pcall(require, "which-key")
if ok then
  which_key.register({
    ["<leader>t"] = {
      name = "Task Manager",
      a = "Добавить заметку",
      l = "Список заметок",
      L = "Глобальный список",
      f = "Поиск",
      F = "Глобальный поиск",
    },
  })
end
```

## Отладка

### Логирование

Добавьте debug-логирование в `core.lua`:

```lua
local function debug_log(msg)
  if config.options.debug then
    print("[tm.nvim] " .. msg)
  end
end

function M.execute_tm_command(args, on_exit)
  debug_log("Executing: tm " .. table.concat(args, " "))
  -- ...
end
```

### Проверка состояния

```lua
:lua print(vim.inspect(require("tm.config").options))
:lua print(require("tm.statusline").cached_count)
:lua print(require("tm.core").workspace_exists())
```

### Ошибки

Используйте `pcall` для безопасного вызова:

```lua
local ok, result = pcall(function()
  return require("tm.core").some_function()
end)

if not ok then
  vim.notify("Ошибка: " .. result, vim.log.levels.ERROR)
end
```

## Лучшие практики

1. **Всегда используйте асинхронные вызовы** для tm команд
2. **Оборачивайте callbacks в vim.schedule()** для безопасности
3. **Проверяйте зависимости через pcall** перед использованием
4. **Используйте vim.notify** для информирования пользователя
5. **Парсите вывод через паттерны** вместо фиксированных позиций
6. **Кэшируйте данные** где возможно (statusline)
7. **Предоставляйте fallback** для опциональных зависимостей (lualine)

## Тестирование

Рекомендуется использовать [plenary.nvim test harness](https://github.com/nvim-lua/plenary.nvim#plenarytest_harness):

```lua
-- tests/core_spec.lua
local core = require("tm.core")

describe("core", function()
  it("should parse notes list", function()
    local output = "[1]: Test note\n[2]: Another note"
    local notes = core.parse_notes_list(output)

    assert.equals(2, #notes)
    assert.equals(1, notes[1].id)
    assert.equals("Test note", notes[1].text)
  end)
end)
```

Запуск тестов:

```vim
:PlenaryBustedDirectory tests/
```

## Заключение

tm.nvim построен на модульной архитектуре с четким разделением ответственности. Каждый модуль отвечает за свою область, что упрощает понимание кода и добавление новой функциональности.

Для вопросов и предложений создавайте issue в репозитории проекта.
