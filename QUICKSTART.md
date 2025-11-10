# Быстрый старт

## 1. Установка

Добавьте в конфигурацию Neovim (например, `~/.config/nvim/init.lua` или с lazy.nvim):

```lua
{
  'kritile/nvim-remote-sync',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    require('core').setup()
  end,
}
```

## 2. Создание конфигурации

Скопируйте пример конфигурации:

```bash
cp .remote_hosts_sync.toml.example .remote_hosts_sync.toml
```

Отредактируйте `.remote_hosts_sync.toml` и добавьте свои хосты:

```toml
[[hosts]]
name = "My Server"
type = "sftp"
host = "example.com"
port = 22
user = "username"
password = "/path/to/ssh/key"
path = "/var/www/project"
excludes_local = ["node_modules/", ".git/"]
excludes_remote = ["cache/", "logs/"]
```

## 3. Использование

### Открыть список хостов
```vim
:RemoteHosts
```

### Открыть дерево файлов
```vim
:RemoteOpenTree
```

### Синхронизировать текущий файл
```vim
:RemoteSync
```

### Загрузить всю директорию
```vim
:RemotePush
```

## Горячие клавиши

### В дереве файлов:
- `<Enter>` - Открыть файл
- `r` - Обновить
- `d` - Скачать
- `u` - Загрузить
- `q` - Закрыть

### В списке хостов:
- `<Enter>` - Подключиться
- `<C-e>` - Редактировать
- `<C-d>` - Удалить
- `<C-t>` - Тест соединения

## Требования

Убедитесь, что установлены необходимые утилиты:

```bash
# SFTP
sudo apt install openssh-client sshpass

# FTP
sudo apt install lftp

# Rsync
sudo apt install rsync
```

## Безопасность

⚠️ **Важно:** Добавьте `.remote_hosts_sync.toml` в `.gitignore`!

```bash
echo ".remote_hosts_sync.toml" >> .gitignore
```

Используйте SSH-ключи вместо паролей для повышения безопасности.
