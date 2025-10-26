# tm.nvim

Плагин для Neovim, интегрирующий CLI-инструмент [Task Manager (tm)](https://github.com/Chupik13/tm) для управления заметками в рабочих пространствах прямо из редактора.

## Возможности

- Добавление, просмотр, поиск, удаление и архивирование заметок без выхода из Neovim
- Интеграция с Telescope для удобного просмотра и фильтрации заметок
- Поддержка множественных рабочих пространств
- Глобальный поиск по всем пространствам
- Автоматическая компактизация ID после архивирования
- Интеграция со статусной строкой (lualine) для отображения количества активных заметок
- Редактирование заметок в split-буфере
- Асинхронное выполнение команд для плавной работы

## Требования

- Neovim >= 0.8.0
- [tm](https://github.com/Chupik13/tm) - CLI-инструмент Task Manager
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - обязательная зависимость
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - обязательная зависимость (требуется для Telescope)
- [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) - опциональная зависимость для статусной строки

## Установка

### Установка tm CLI

Сначала установите tm CLI-инструмент:

```bash
cd TaskManager
dotnet pack
dotnet tool install --global --add-source ./bin/Debug TaskManager
```

Проверьте установку:

```bash
tm --version
```

### Установка плагина

#### lazy.nvim (рекомендуется)

```lua
{
  "Chupik13/tm.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  opts = {
    -- Конфигурация (см. раздел Конфигурация)
  },
  keys = {
    { "<leader>ta", "<cmd>TmAddNote<cr>", desc = "Добавить заметку" },
    { "<leader>tl", "<cmd>TmList<cr>", desc = "Список заметок" },
    { "<leader>tL", "<cmd>TmGlobalList<cr>", desc = "Глобальный список" },
    { "<leader>tf", desc = "Найти заметку" },
    { "<leader>tF", desc = "Глобальный поиск" },
  },
}
```

#### packer.nvim

```lua
use {
  "Chupik13/tm.nvim",
  requires = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("tm").setup({
      -- Конфигурация
    })
  end,
}
```

#### vim-plug

```vim
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'Chupik13/tm.nvim'

lua << EOF
require("tm").setup({
  -- Конфигурация
})
EOF
```

## Конфигурация

### Минимальная конфигурация

```lua
require("tm").setup()
```

### Полная конфигурация (с дефолтными значениями)

```lua
require("tm").setup({
  -- Автоматический compact после архивирования
  auto_compact = true,

  -- Лимит символов для truncate в списках
  truncate_limit = 50,

  -- Интеграция со статусной строкой
  statusline = {
    enabled = true,
    format = "TM: %d", -- %d заменяется на количество заметок
  },

  -- Ключевые привязки
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
})
```

### Интеграция с lualine

Добавьте компонент tm в вашу конфигурацию lualine:

```lua
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
```

## Команды

### `:TmAddNote [-p SPACE_ID]`

Открывает prompt для ввода текста новой заметки. Если рабочее пространство не инициализировано, автоматически выполняется `tm init`.

**Примеры:**
```vim
:TmAddNote
:TmAddNote -p 1
```

### `:TmList [-p SPACE_ID]`

Открывает Telescope picker со списком заметок текущего (или указанного) пространства.

**Действия в picker:**
- `<CR>` - открыть заметку в split для редактирования
- `d` (normal) / `<C-d>` (insert) - удалить заметку
- `a` (normal) / `<C-a>` (insert) - архивировать заметку

**Примеры:**
```vim
:TmList
:TmList -p 1
```

### `:TmGlobalList`

Показывает все заметки из всех рабочих пространств в Telescope picker.

**Примеры:**
```vim
:TmGlobalList
```

### `:TmInit`

Вручную инициализировать рабочее пространство в текущей директории.

**Примеры:**
```vim
:TmInit
```

## Ключевые привязки

По умолчанию настроены следующие привязки (можно изменить в конфигурации):

| Клавиша | Команда | Описание |
|---------|---------|----------|
| `<leader>ta` | `:TmAddNote` | Добавить заметку |
| `<leader>tl` | `:TmList` | Список заметок |
| `<leader>tL` | `:TmGlobalList` | Глобальный список |

## Использование

### Быстрый старт

1. Откройте Neovim в директории проекта
2. Нажмите `<leader>ta` для добавления первой заметки
3. Введите текст заметки и нажмите Enter
4. Нажмите `<leader>tl` для просмотра списка заметок
5. Используйте Telescope для поиска по тексту заметок

### Работа с множественными пространствами

```vim
" В первом проекте
cd ~/projects/project1
:TmAddNote
" Введите: Реализовать авторизацию

" Во втором проекте
cd ~/projects/project2
:TmAddNote
" Введите: Написать тесты

" Просмотр всех заметок
:TmGlobalList
```

### Редактирование заметок

1. Откройте список заметок: `:TmList`
2. Выберите заметку и нажмите `<CR>`
3. Редактируйте текст в открывшемся split-буфере
4. Сохраните изменения: `:w`
5. Буфер автоматически закроется, а заметка обновится

### Архивирование и компактизация

```vim
" Открыть список
:TmList

" В picker нажать 'a' на нужной заметке
" Заметка архивируется, и автоматически выполняется compact
```

## Troubleshooting

### tm не найден

Если плагин сообщает, что tm не установлен:

1. Проверьте установку: `tm --version`
2. Убедитесь, что tm в PATH
3. Перезапустите Neovim

### Telescope не работает

Убедитесь, что telescope.nvim и plenary.nvim установлены:

```lua
:checkhealth telescope
```

### Статусная строка не показывает заметки

1. Убедитесь, что lualine установлен
2. Добавьте компонент в конфигурацию lualine (см. раздел Конфигурация)
3. Проверьте, что `statusline.enabled = true` в конфигурации tm.nvim

## Техническая документация

Подробная техническая документация доступна в [TECHNICAL.md](./TECHNICAL.md).

## Лицензия

MIT

## Автор

Grigorii

## Благодарности

- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)
