-- Файл автозагрузки плагина tm.nvim
-- Этот файл загружается автоматически при старте Neovim

-- Защита от повторной загрузки
if vim.g.loaded_tm_nvim then
  return
end
vim.g.loaded_tm_nvim = true

-- Проверка версии Neovim
if vim.fn.has("nvim-0.8.0") ~= 1 then
  vim.notify("tm.nvim требует Neovim >= 0.8.0", vim.log.levels.ERROR)
  return
end

-- Плагин будет инициализирован через setup() в конфигурации пользователя
-- Команды будут доступны только после вызова require("tm").setup()
