# Подробные шаги миграции

## Оглавление
1. [Подготовка к миграции](#подготовка-к-миграции)
2. [Получение URL репозиториев](#получение-url-репозиториев)
3. [Зеркальное клонирование](#зеркальное-клонирование)
4. [Зеркальная отправка](#зеркальная-отправка)
5. [Проверка миграции](#проверка-миграции)
6. [Начало работы с GitHub](#начало-работы-с-github)
7. [Дополнительные настройки](#дополнительные-настройки)

## Подготовка к миграции

### 1.1. Проверка системы
Перед началом убедитесь, что у вас установлены:

- **Git** версии 2.0 или выше:
  ```bash
  git --version
  ```

- **Доступ к интернету** для работы с SourceCraft и GitHub

- **Терминал** с поддержкой Bash (Linux/macOS) или Git Bash (Windows)

### 1.2. Создание токенов доступа

#### Для SourceCraft:
1. Перейдите в [настройки SourceCraft](https://sourcecraft.dev/settings/tokens)
2. Нажмите "Создать токен"
3. Укажите:
   - Название: `Git Migration`
   - Срок действия: 30 дней (рекомендуется)
   - Права: `read_repository`
4. Скопируйте токен и сохраните в безопасном месте

#### Для GitHub:
1. Перейдите в [GitHub Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens)
2. Нажмите "Generate new token"
3. Укажите:
   - Note: `SourceCraft Migration`
   - Expiration: 30 days
   - Scopes: `repo` (полный контроль репозиториев)
4. Скопируйте токен

### 1.3. Настройка Git
```bash
# Установите ваше имя и email
git config --global user.name "Ваше Имя"
git config --global user.email "ваш.email@example.com"

# Настройте кэширование учетных данных
git config --global credential.helper cache
git config --global credential.helper 'cache --timeout=3600'
```

## Получение URL репозиториев

### 2.1. URL репозитория на SourceCraft

1. **Откройте репозиторий** на SourceCraft:
   ```
   https://sourcecraft.dev/ВАША_ОРГАНИЗАЦИЯ/ВАШ_РЕПОЗИТОРИЙ
   ```

2. **Нажмите "Клонировать"** в правом верхнем углу

3. **Скопируйте HTTPS URL**:
   ```
   https://git@git.sourcecraft.dev/ОРГАНИЗАЦИЯ/РЕПОЗИТОРИЙ.git
   ```

4. **Альтернативно, используйте SSH** (если настроен):
   ```
   ssh://ssh.sourcecraft.dev/ОРГАНИЗАЦИЯ/РЕПОЗИТОРИЙ.git
   ```

### 2.2. URL репозитория на GitHub

1. **Создайте новый репозиторий** на GitHub:
   - Имя: такое же, как на SourceCraft
   - Описание: опционально
   - Видимость: public или private
   - **Не добавляйте** README, .gitignore, license

2. **Скопируйте HTTPS URL**:
   ```
   https://github.com/ВАШ_USERNAME/РЕПОЗИТОРИЙ.git
   ```

3. **Или SSH URL**:
   ```
   git@github.com:ВАШ_USERNAME/РЕПОЗИТОРИЙ.git
   ```

## Зеркальное клонирование

### 3.1. Что такое зеркальное клонирование?

**`git clone --mirror`** создает:
- Bare-репозиторий (только `.git` папка)
- Все refs (ветки, теги, удаленные ветки)
- Все объекты Git (коммиты, деревья, блобы)
- Все конфигурации и настройки

### 3.2. Команда для клонирования

```bash
# Базовый вариант
git clone --mirror "https://git@git.sourcecraft.dev/ОРГАНИЗАЦИЯ/РЕПОЗИТОРИЙ.git" временная-папка.git

# С аутентификацией через токен
git clone --mirror "https://anyname:ВАШ_ТОКЕН@git.sourcecraft.dev/ОРГАНИЗАЦИЯ/РЕПОЗИТОРИЙ.git" временная-папка.git

# С пользовательским именем папки
git clone --mirror ИСТОЧНИК ЦЕЛЕВАЯ_ПАПКА.git
```

### 3.3. Проверка успешного клонирования

```bash
# Перейдите в созданную папку
cd временная-папка.git

# Проверьте, что это bare-репозиторий
git rev-parse --is-bare-repository
# Должно вывести: true

# Посмотрите список веток
git branch -a

# Посмотрите список тегов
git tag -l

# Проверьте размер репозитория
du -sh .
```

### 3.4. Особые случаи

#### Большие репозитории
```bash
# Используйте shallow clone для экономии места
git clone --mirror --depth 1 ИСТОЧНИК временная-папка.git
# Но: скопирует только последние коммиты
```

#### Репозитории с подмодулями
```bash
# Клонируйте с подмодулями
git clone --mirror --recurse-submodules ИСТОЧНИК временная-папка.git
```

## Зеркальная отправка

### 4.1. Что делает `git push --mirror`?

**`git push --mirror`**:
- Отправляет все локальные refs на удаленный сервер
- Перезаписывает существующие refs с тем же именем
- Удаляет refs на удаленном сервере, которых нет локально
- Делает удаленный репозиторий точной копией локального

### 4.2. Команда для отправки

```bash
# Из папки mirror-репозитория
cd временная-папка.git

# Отправка на GitHub
git push --mirror "https://github.com/ВАШ_USERNAME/РЕПОЗИТОРИЙ.git"

# С аутентификацией
git push --mirror "https://ВАШ_USERNAME:ВАШ_ТОКЕН@github.com/ВАШ_USERNAME/РЕПОЗИТОРИЙ.git"
```

### 4.3. Мониторинг процесса

```bash
# Включите прогресс-бар
git config --global push.showProgress true

# Проверьте статус отправки
git push --mirror --progress ЦЕЛЬ 2>&1 | grep -E "(Writing|Compressing|Total)"
```

### 4.4. Обработка ошибок

#### Ошибка аутентификации
```
fatal: Authentication failed
```
**Решение:** Проверьте токен и права доступа.

#### Ошибка размера
```
error: RPC failed; HTTP 413 curl 22 The requested URL returned error: 413
```
**Решение:** Репозиторий слишком большой для одного push.
```bash
# Разбейте на несколько push
git push --mirror --verbose ЦЕЛЬ
# Или используйте SSH
```

#### Конфликт refs
```
! [rejected]        main -> main (non-fast-forward)
```
**Решение:** Используйте `--force`, но осторожно:
```bash
git push --mirror --force ЦЕЛЬ
```

## Проверка миграции

### 5.1. Базовые проверки

```bash
# 1. Проверьте количество коммитов
git log --oneline | wc -l

# 2. Проверьте ветки
git branch -a

# 3. Проверьте теги
git tag -l

# 4. Проверьте последние коммиты
git log --oneline -10
```

### 5.2. Сравнение репозиториев

```bash
#!/bin/bash
# scripts/compare-repos.sh

SOURCE="https://git@git.sourcecraft.dev/ОРГАНИЗАЦИЯ/РЕПОЗИТОРИЙ.git"
TARGET="https://github.com/ВАШ_USERNAME/РЕПОЗИТОРИЙ.git"

echo "Сравнение репозиториев..."
echo ""

# Хеш последнего коммита в main
echo "Последний коммит в main:"
echo "Source: $(git ls-remote $SOURCE refs/heads/main | cut -f1)"
echo "Target: $(git ls-remote $TARGET refs/heads/main | cut -f1)"
echo ""

# Количество веток
echo "Количество веток:"
echo "Source: $(git ls-remote --heads $SOURCE | wc -l)"
echo "Target: $(git ls-remote --heads $TARGET | wc -l)"
echo ""

# Количество тегов
echo "Количество тегов:"
echo "Source: $(git ls-remote --tags $SOURCE | wc -l)"
echo "Target: $(git ls-remote --tags $TARGET | wc -l)"
```

### 5.3. Проверка целостности

```bash
# Проверка целостности объектов Git
git fsck --full

# Проверка связности графа
git fsck --unreachable

# Проверка ссылок
git show-ref
```

## Начало работы с GitHub

### 6.1. Клонирование мигрированного репозитория

```bash
# Клонируйте обычным способом
git clone "https://github.com/ВАШ_USERNAME/РЕПОЗИТОРИЙ.git"

# Или через SSH
git clone "git@github.com:ВАШ_USERNAME/РЕПОЗИТОРИЙ.git"
```

### 6.2. Настройка удаленных репозиториев

```bash
# Перейдите в клонированный репозиторий
cd РЕПОЗИТОРИЙ

# Проверьте удаленные репозитории
git remote -v
# Должен быть только origin, указывающий на GitHub

# Если нужно добавить sourcecraft как backup
git remote add sourcecraft "https://git@git.sourcecraft.dev/ОРГАНИЗАЦИЯ/РЕПОЗИТОРИЙ.git"

# Получите обновления с обоих источников
git fetch --all
```

### 6.3. Первые действия после миграции

1. **Проверьте работоспособность:**
   ```bash
   # Запустите тесты (если есть)
   npm test  # или ./run_tests.sh
   
   # Соберите проект (если нужно)
   npm build  # или make build
   ```

2. **Обновите документацию:**
   - Обновите README.md
   - Обновите ссылки в документации
   - Обновите CI/CD конфигурации

3. **Настройте GitHub:**
   - Добавьте описание репозитория
   - Настройте темы (topics)
   - Добавьте README badges
   - Настройте защиту веток

## Дополнительные настройки

### 7.1. Настройка SSH

```bash
# Генерация SSH ключа
ssh-keygen -t ed25519 -C "ваш.email@example.com" -f ~/.ssh/id_ed25519_sourcecraft

# Добавьте ключ в SourceCraft
cat ~/.ssh/id_ed25519_sourcecraft.pub
# Скопируйте и добавьте в настройках SourceCraft

# Настройка ~/.ssh/config
cat >> ~/.ssh/config << EOF
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
EOF
```

### 7.2. Автоматизация с помощью скриптов

Создайте файл `migrate-all.sh` для миграции нескольких репозиториев:

```bash
#!/bin/bash
# migrate-all.sh

REPOS=(
    "репозиторий-1"
    "репозиторий-2"
    "репозиторий-3"
)

for REPO in "${REPOS[@]}"; do
    echo "Миграция $REPO..."
    ./scripts/migrate.sh \
        -s "https://git@git.sourcecraft.dev/ОРГАНИЗАЦИЯ/$REPO.git" \
        -t "https://github.com/ВАШ_USERNAME/$REPO.git" \
        -c -v
    echo ""
done
```

### 7.3. Резервное копирование

```bash
# Создайте резервную копию перед миграцией
git bundle create backup-$(date +%Y%m%d).bundle --all

# Восстановите из bundle
git clone backup-20231201.bundle восстановленный-репозиторий
```

---

## 📋 Чек-лист миграции

- [ ] Создан токен доступа для SourceCraft
- [ ] Создан токен доступа для GitHub
- [ ] Создан пустой репозиторий на GitHub
- [ ] Скопирован URL SourceCraft репозитория
- [ ] Скопирован URL GitHub репозитория
- [ ] Выполнено зеркальное клонирование
- [ ] Выполнена зеркальная отправка
- [ ] Проверено совпадение коммитов
- [ ] Проверено совпадение веток
- [ ] Проверено совпадение тегов
- [ ] Удалены временные файлы
- [ ] Клонирован репозиторий с GitHub
- [ ] Проверена работоспособность
- [ ] Обновлена документация

---

**🎯 Помните:** Хорошая миграция — это невидимая миграция. Пользователи не должны заметить разницы!