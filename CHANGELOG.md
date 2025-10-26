# Changelog

Все значимые изменения в проекте tm.nvim будут документированы в этом файле.

Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.0.0/),
и проект придерживается [Semantic Versioning](https://semver.org/lang/ru/).

## [Unreleased]

## [1.0.0] - 2024-10-26

### Добавлено

- Базовая функциональность плагина
- Команда `:TmAddNote` для добавления заметок
- Команда `:TmList` для просмотра списка заметок
- Команда `:TmGlobalList` для глобального списка заметок
- Команда `:TmFind` для поиска заметок
- Команда `:TmFindGlobal` для глобального поиска
- Команда `:TmInit` для ручной инициализации workspace
- Интеграция с Telescope.nvim для красивых пикеров
- Интеграция с lualine.nvim для статусной строки
- Автоматическая компактизация ID после архивирования
- Поддержка редактирования заметок в split-буфере
- Асинхронное выполнение команд tm через vim.system
- Конфигурируемые ключевые привязки
- Конфигурируемые настройки Telescope (темы, layout)
- Поддержка множественных рабочих пространств
- Действия в Telescope picker:
  - `<CR>` - редактирование заметки
  - `d` / `<C-d>` - удаление заметки
  - `a` / `<C-a>` - архивирование заметки
- Полная документация (README.md)
- Техническая документация (TECHNICAL.md)
- Примеры конфигурации (example_config.lua)
- MIT лицензия

### Требования

- Neovim >= 0.8.0
- tm CLI инструмент
- telescope.nvim
- plenary.nvim
- lualine.nvim (опционально)

[Unreleased]: https://github.com/yourusername/tm.nvim/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourusername/tm.nvim/releases/tag/v1.0.0
