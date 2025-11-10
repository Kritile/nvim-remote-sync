# Документация для разработчиков

## Структура проекта

```
remote_hosts_sync/
├── lua/
│   ├── core/                # Базовая логика
│   │   ├── init.lua        # Инициализация плагина
│   │   ├── config.lua      # Управление конфигурацией и TOML
│   │   └── utils.lua       # Вспомогательные функции
│   ├── sync/                # Синхронизация файлов
│   │   ├── manager.lua     # Менеджер синхронизации
│   │   ├── sftp.lua        # SFTP провайдер
│   │   ├── ftp.lua         # FTP провайдер
│   │   └── rsync.lua       # Rsync провайдер
│   ├── tui/                 # Пользовательский интерфейс
│   │   ├── hosts.lua       # Управление хостами
│   │   └── tree.lua        # Дерево файлов
│   └── commands.lua         # Регистрация команд Neovim
├── plugin/
│   └── remote_hosts_sync.lua # Точка входа плагина
├── README.md
├── LICENSE
└── .remote_hosts_sync.toml.example
```

## Архитектура

### Core модули

- **init.lua** - Инициализирует плагин, настраивает autocommands
- **config.lua** - Парсинг и сохранение TOML конфигурации, управление хостами
- **utils.lua** - Логирование, работа с путями, выполнение команд

### Sync модули

- **manager.lua** - Координирует работу провайдеров синхронизации
- **sftp.lua** - Реализует операции через SFTP/SSH
- **ftp.lua** - Реализует операции через FTP/LFTP
- **rsync.lua** - Реализует операции через rsync

Каждый провайдер должен реализовать интерфейс:
- `connect(host)` - Проверка соединения
- `disconnect(host)` - Отключение
- `upload(host, local_path, remote_path)` - Загрузка файла
- `download(host, remote_path, local_path)` - Скачивание файла
- `list(host, remote_path)` - Список файлов в директории
- `sync(host, local_dir, remote_dir)` - Синхронизация директории

### TUI модули

- **hosts.lua** - Telescope picker для управления хостами
- **tree.lua** - Дерево файлов в стиле neo-tree с навигацией

### Commands

Регистрирует все команды Neovim:
- RemoteOpenTree, RemoteCloseTree
- RemoteUpload, RemoteDownload
- RemoteSync, RemoteFetch, RemotePush
- RemoteHosts, RemoteAddHost, RemoteDisconnect

## Добавление нового провайдера

1. Создайте файл `lua/sync/myprotocol.lua`
2. Реализуйте все методы интерфейса
3. Добавьте провайдер в `sync/manager.lua`:

```lua
local sync_providers = {
  sftp = require('sync.sftp'),
  ftp = require('sync.ftp'),
  rsync = require('sync.rsync'),
  myprotocol = require('sync.myprotocol'), -- добавить сюда
}
```

## Тестирование

### Ручное тестирование

1. Создайте тестовый конфигурационный файл
2. Запустите Neovim с плагином
3. Проверьте все команды

### Отладка

Включите логирование:

```lua
require('core').setup({
  log_file = '/tmp/remote_hosts_sync.log',
})
```

Смотрите логи:
```bash
tail -f /tmp/remote_hosts_sync.log
```

## Известные ограничения

1. TOML парсер - упрощённая реализация, поддерживает базовый синтаксис
2. Выполнение команд - асинхронное через `vim.fn.jobstart`, могут быть проблемы с очень длинными операциями
3. Telescope - обязательная зависимость для TUI, без неё работать не будет

## TODO / Будущие улучшения

- [ ] Добавить поддержку SCP протокола
- [ ] Реализовать прогресс-бар для больших файлов
- [ ] Добавить diff между локальной и удалённой версией
- [ ] Реализовать фоновую синхронизацию с мониторингом изменений
- [ ] Добавить шифрование паролей в конфиге
- [ ] Поддержка nui.nvim в качестве альтернативы telescope
- [ ] Улучшить парсер TOML (или использовать внешнюю библиотеку)
- [ ] Добавить тесты (busted)

## Участие в разработке

1. Fork проекта
2. Создайте feature branch (`git checkout -b feature/amazing-feature`)
3. Commit изменений (`git commit -m 'Add amazing feature'`)
4. Push в branch (`git push origin feature/amazing-feature`)
5. Создайте Pull Request

## Стиль кода

- Используйте 2 пробела для отступов
- Следуйте стандартам Lua
- Документируйте публичные функции
- Добавляйте комментарии для сложной логики
