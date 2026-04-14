# Руководство по миграции репозиториев с SourceCraft на GitHub

![Git Migration](https://img.shields.io/badge/Git-Migration-blue)
![SourceCraft](https://img.shields.io/badge/SourceCraft-Platform-green)
![GitHub](https://img.shields.io/badge/GitHub-Host-black)

Полное обучающее руководство по переносу репозиториев с платформы SourceCraft на GitHub с сохранением всей истории, веток и тегов.

## 📋 Содержание

- [Общая идея миграции](#общая-идея-миграции)
- [Предварительные требования](#предварительные-требования)
- [Пошаговое руководство](#пошаговое-руководство)
- [Структура проекта](#структура-проекта)
- [Конфигурационные файлы](#конфигурационные-файлы)
- [Примеры использования](#примеры-использования)
- [Частые вопросы](#частые-вопросы)
- [Лицензия](#лицензия)

## 🎯 Общая идея миграции

**Цель**: Создать точную копию репозитория на GitHub, идентичную репозиторию на SourceCraft, чтобы продолжить работу уже на GitHub.

**Принцип работы**: Используем Git команды `clone --mirror` и `push --mirror` для создания зеркальной копии со всеми refs (ветками, тегами, историей).

**Преимущества подхода**:
- Сохраняется вся история коммитов
- Сохраняются все ветки и теги
- Сохраняются заметки (notes) и другие refs
- Процесс обратим и безопасен

## 🔧 Предварительные требования

### 1. Установленное ПО
- [Git](https://git-scm.com/downloads) версии 2.0+
- Терминал (Bash, Zsh, PowerShell)

### 2. Аккаунты и доступы
- Аккаунт на [SourceCraft](https://sourcecraft.dev)
- Аккаунт на [GitHub](https://github.com)
- Права на чтение репозитория на SourceCraft
- Права на запись в репозиторий на GitHub

### 3. Токены доступа
- **SourceCraft**: [Персональный токен (PAT)](https://sourcecraft.dev/portal/docs/ru/sourcecraft/security/pat.html)
- **GitHub**: [Personal Access Token](https://github.com/settings/tokens) с правами `repo`

## 🚀 Пошаговое руководство

### Шаг 1: Создать репозиторий на GitHub

1. Войдите на [GitHub](https://github.com)
2. Нажмите **New repository**
3. В поле **Repository name** введите то же имя, что и на SourceCraft
4. Выберите visibility (public/private)
5. **Не ставьте** галочки:
   - ☐ Add a README file
   - ☐ Add .gitignore
   - ☐ Choose a license
6. Нажмите **Create repository**
7. Скопируйте URL репозитория:
   ```
   https://github.com/ВАШ_USERNAME/ИМЯ_РЕПОЗИТОРИЯ.git
   ```

### Шаг 2: Определить URL репозитория на SourceCraft

1. Откройте репозиторий на SourceCraft
2. Нажмите кнопку **Клонировать** в правом верхнем углу
3. Скопируйте HTTPS URL:
   ```
   https://git@git.sourcecraft.dev/ОРГАНИЗАЦИЯ/РЕПОЗИТОРИЙ.git
   ```

### Шаг 3: Зеркально клонировать репозиторий с SourceCraft

```bash
# Создаем зеркальный клон (bare-репозиторий)
git clone --mirror "https://git@git.sourcecraft.dev/ОРГАНИЗАЦИЯ/РЕПОЗИТОРИЙ.git" временная-папка.git

# Переходим в созданную папку
cd временная-папка.git
```

**Что делает `--mirror`**:
- Создает bare-репозиторий (только `.git`, без рабочих файлов)
- Копирует все refs: ветки, теги, удаленные ветки
- Сохраняет все настройки и конфигурации

### Шаг 4: Зеркально отправить всё на GitHub

```bash
# Отправляем всё в GitHub
git push --mirror "https://github.com/ВАШ_USERNAME/ИМЯ_РЕПОЗИТОРИЯ.git"
```

**Что делает `--mirror` при push**:
- Отправляет все локальные refs на удаленный сервер
- Перезаписывает существующие refs на GitHub
- Делает GitHub точной копией SourceCraft

### Шаг 5: Удалить временный mirror-репозиторий

```bash
# Выходим из папки
cd ..

# Удаляем временную папку
rm -rf временная-папка.git
```

### Шаг 6: Клонировать репозиторий с GitHub и начать работу

```bash
# Клонируем обычным способом
git clone "https://github.com/ВАШ_USERNAME/ИМЯ_РЕПОЗИТОРИЯ.git"

# Переходим в проект
cd ИМЯ_РЕПОЗИТОРИЯ

# Проверяем, что всё работает
git status
git log --oneline -5
```

## 📁 Структура проекта

```
sourcecraft-to-github-migration-guide/
├── docs/                    # Документация
│   ├── migration-steps.md   # Подробные шаги миграции
│   ├── troubleshooting.md   # Решение проблем
│   └── best-practices.md    # Лучшие практики
├── examples/                # Примеры
│   ├── basic-migration/     # Базовый пример
│   ├── complex-project/     # Сложный проект
│   └── scripts/             # Скрипты примеров
├── scripts/                 # Полезные скрипты
│   ├── migrate.sh          # Автоматизация миграции
│   ├── verify.sh           # Проверка миграции
│   └── cleanup.sh          # Очистка временных файлов
├── configs/                 # Конфигурационные файлы
│   ├── git-config/         # Конфигурации Git
│   ├── ssh-config/         # Конфигурации SSH
│   └── token-setup/        # Настройка токенов
├── .gitignore              # Игнорируемые файлы
└── README.md               # Это руководство
```

## ⚙️ Конфигурационные файлы

### 1. Настройка Git для миграции

Создайте файл `~/.gitconfig` или используйте локальные настройки:

```ini
[user]
    name = Ваше Имя
    email = ваш.email@example.com

[credential]
    helper = cache --timeout=3600

[pull]
    rebase = false

[push]
    default = simple
```

### 2. Настройка SSH для SourceCraft

Добавьте в `~/.ssh/config`:

```ssh
Host sourcecraft
    HostName ssh.sourcecraft.dev
    User git
    IdentityFile ~/.ssh/id_ed25519_sourcecraft
    IdentitiesOnly yes

Host github
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
```

### 3. Переменные окружения

Создайте файл `.env.example`:

```bash
# SourceCraft
SOURCE_CRAFT_USERNAME="ваш_username"
SOURCE_CRAFT_TOKEN="ваш_pat_токен"
SOURCE_CRAFT_ORG="организация"
SOURCE_CRAFT_REPO="репозиторий"

# GitHub
GITHUB_USERNAME="ваш_github_username"
GITHUB_TOKEN="ваш_github_token"
GITHUB_REPO="репозиторий"
```

## 🧪 Примеры использования

### Пример 1: Базовая миграция

```bash
#!/bin/bash
# scripts/migrate.sh

SOURCE_URL="https://git@git.sourcecraft.dev/org/project.git"
TARGET_URL="https://github.com/user/project.git"
TEMP_DIR="temp-mirror.git"

echo "🚀 Начинаем миграцию..."
git clone --mirror "$SOURCE_URL" "$TEMP_DIR"
cd "$TEMP_DIR"
git push --mirror "$TARGET_URL"
cd ..
rm -rf "$TEMP_DIR"
echo "✅ Миграция завершена!"
```

### Пример 2: Проверка миграции

```bash
#!/bin/bash
# scripts/verify.sh

echo "🔍 Проверяем миграцию..."

# Проверяем количество коммитов
echo "Количество коммитов в source:"
git ls-remote --heads "$SOURCE_URL" | wc -l

echo "Количество коммитов в target:"
git ls-remote --heads "$TARGET_URL" | wc -l

# Проверяем ветки
echo "Ветки в source:"
git ls-remote --heads "$SOURCE_URL"

echo "Ветки в target:"
git ls-remote --heads "$TARGET_URL"
```

## ❓ Частые вопросы

### Q1: Что делать, если репозиторий очень большой?
**A**: Используйте `--depth 1` для shallow clone, но учтите, что это скопирует только последний коммит каждой ветки.

### Q2: Как мигрировать только определенные ветки?
**A**: Используйте обычный `git clone`, затем `git push` для конкретных веток.

### Q3: Что делать с подмодулями (submodules)?
**A**: Подмодули нужно мигрировать отдельно для каждого подмодуля.

### Q4: Как проверить, что миграция прошла успешно?
**A**: Сравните хеши коммитов, количество веток и тегов на обоих хостах.

### Q5: Что делать с защищенными ветками (protected branches)?
**A**: На GitHub нужно настроить protection rules после миграции.

## 📝 Лицензия

Этот проект распространяется под лицензией MIT. См. файл [LICENSE](LICENSE) для подробностей.

## 🤝 Вклад в проект

Мы приветствуем вклад в развитие этого руководства! Пожалуйста:

1. Форкните репозиторий
2. Создайте ветку для ваших изменений
3. Сделайте коммит с описательными сообщениями
4. Отправьте pull request

## 📞 Поддержка

Если у вас возникли проблемы или вопросы:
1. Проверьте [документацию](docs/)
2. Создайте [issue](https://github.com/ваш-username/репозиторий/issues)
3. Обратитесь к сообществу

---

**🚀 Удачи с миграцией!** Помните: хорошая миграция — это та, которую никто не заметил.