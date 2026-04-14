# Лучшие практики миграции

## Оглавление
1. [Планирование миграции](#планирование-миграции)
2. [Подготовка репозитория](#подготовка-репозитория)
3. [Безопасность](#безопасность)
4. [Производительность](#производительность)
5. [Верификация](#верификация)
6. [Пост-миграционные задачи](#пост-миграционные-задачи)
7. [Работа с командой](#работа-с-командой)

## Планирование миграции

### 1.1. Оценка репозитория

Перед миграцией оцените:

```bash
# Размер репозитория
git count-objects -vH

# Количество коммитов
git rev-list --all --count

# Количество веток
git branch -a | wc -l

# Количество тегов
git tag -l | wc -l

# Самые большие файлы в истории
git rev-list --objects --all | \
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
  grep '^blob' | \
  sort --numeric-sort --key=3 | \
  tail -10 | \
  cut -f 2- | \
  while read hash size file; do
    echo "$size $file"
  done
```

### 1.2. Выбор времени миграции

**Лучшее время:**
- Вне рабочих часов
- В выходные дни
- Во время технического окна

**Что учесть:**
- Активность команды
- Запланированные релизы
- CI/CD пайплайны

### 1.3. Коммуникация с командой

**Обязательно сообщите:**
- Дата и время миграции
- Ожидаемая длительность простоя
- Что делать во время миграции
- Как проверить успешность миграции
- Контакты для экстренных случаев

## Подготовка репозитория

### 2.1. Очистка истории

**Перед миграцией рекомендуется:**

```bash
# 1. Удалить мертвые ветки
git fetch --prune
git branch -r | awk '{print $1}' | \
  grep -E -v -f /dev/fd/0 <(git branch -vv | grep origin) | \
  awk '{print $1}' | xargs -r git branch -d

# 2. Удалить старые теги
# Создайте backup тегов
git tag -l > tags-backup.txt

# Удалите теги старше 2 лет
git for-each-ref --format='%(refname:short) %(taggerdate:short)' refs/tags | \
  while read tag date; do
    if [[ $(date -d "$date" +%s) -lt $(date -d "2 years ago" +%s) ]]; then
      echo "Удаляю тег: $tag"
      git tag -d "$tag"
      git push origin :refs/tags/"$tag"
    fi
  done

# 3. Сжать репозиторий
git gc --aggressive --prune=now
```

### 2.2. Проверка целостности

```bash
# Проверка всех объектов
git fsck --full --strict

# Проверка связности
git fsck --unreachable

# Проверка перезаписанных коммитов
git log --oneline --graph --all
```

### 2.3. Обновление конфигураций

**Проверьте и обновите:**
- `.gitignore` - актуальные правила
- `.gitattributes` - настройки diff/merge
- `.github/` - workflows (если есть)
- CI/CD конфигурации

## Безопасность

### 3.1. Защита токенов

**Никогда не делайте:**
- Не коммитьте токены в репозиторий
- Не оставляйте токены в истории команд
- Не используйте один токен для всех репозиториев

**Рекомендуется:**
```bash
# Используйте переменные окружения
export SOURCE_CRAFT_TOKEN="ваш_токен"
export GITHUB_TOKEN="ваш_токен"

# Или используйте git credential helper
git config --global credential.helper 'store --file ~/.git-credentials'
```

### 3.2. Шифрование данных

**Для чувствительных данных:**
```bash
# Используйте git-crypt
git-crypt init
git-crypt add-gpg-user USER_ID

# Или git-secret
git secret init
git secret tell user@email.com
git secret add config/secrets.env
```

### 3.3. Аудит доступа

**Перед миграцией:**
1. Проверьте, кто имеет доступ к репозиторию
2. Удалите неактивных пользователей
3. Обновите права доступа
4. Ведите лог всех операций миграции

## Производительность

### 4.1. Оптимизация больших репозиториев

**Для репозиториев > 1GB:**

```bash
# 1. Используйте shallow clone
git clone --mirror --depth 1 ИСТОЧНИК временная-папка.git

# 2. Разбейте push на части
# Отправьте сначала основные ветки
git push origin main develop --mirror

# Затем остальные ветки
for branch in $(git branch -r | grep -v HEAD | cut -d'/' -f2-); do
    if [[ "$branch" != "main" && "$branch" != "develop" ]]; then
        git push origin "$branch"
    fi
done

# 3. Используйте SSH вместо HTTPS
# SSH обычно быстрее для больших файлов
```

### 4.2. Кэширование

```bash
# Настройте кэш для Git
git config --global core.preloadindex true
git config --global core.fscache true
git config --global gc.auto 256

# Для Windows
git config --global core.longpaths true
```

### 4.3. Параллельная обработка

```bash
# Используйте параллельные операции
git fetch --multiple --jobs=4

# Для больших репозиториев
GIT_TRACE_PERFORMANCE=1 git clone --mirror ИСТОЧНИК
```

## Верификация

### 5.1. Автоматизированные проверки

**Создайте скрипт проверки:**

```bash
#!/bin/bash
# verify-migration.sh

verify_repository() {
    local url=$1
    local name=$2
    
    echo "=== Проверка $name ==="
    
    # Проверка доступности
    if ! git ls-remote "$url" > /dev/null 2>&1; then
        echo "❌ $name недоступен"
        return 1
    fi
    
    # Основные метрики
    echo "Коммиты: $(git ls-remote "$url" | grep -c 'refs/heads')"
    echo "Ветки: $(git ls-remote --heads "$url" | wc -l)"
    echo "Теги: $(git ls-remote --tags "$url" | wc -l)"
    
    # Проверка main ветки
    local main_hash=$(git ls-remote "$url" refs/heads/main | cut -f1)
    if [[ -n "$main_hash" ]]; then
        echo "Main branch hash: $main_hash"
    else
        echo "⚠️  Main branch не найден"
    fi
    
    echo ""
}

# Проверка обоих репозиториев
verify_repository "$SOURCE_URL" "SourceCraft"
verify_repository "$TARGET_URL" "GitHub"
```

### 5.2. Сравнение хешей

```bash
# Сравнение хешей коммитов
compare_commits() {
    local source=$1
    local target=$2
    
    echo "Сравнение коммитов..."
    
    # Получите список коммитов из source
    git ls-remote "$source" | grep 'refs/heads' | sort > source-refs.txt
    
    # Получите список коммитов из target
    git ls-remote "$target" | grep 'refs/heads' | sort > target-refs.txt
    
    # Сравните
    if diff source-refs.txt target-refs.txt > /dev/null; then
        echo "✅ Коммиты совпадают"
    else
        echo "❌ Коммиты не совпадают"
        echo "Различия:"
        diff source-refs.txt target-refs.txt
    fi
    
    # Очистка
    rm -f source-refs.txt target-refs.txt
}
```

### 5.3. Проверка работоспособности

**После миграции проверьте:**

```bash
# 1. Клонирование работает
git clone "$TARGET_URL" test-clone
cd test-clone

# 2. История доступна
git log --oneline -5

# 3. Ветки доступны
git branch -a

# 4. Теги доступны
git tag -l

# 5. Файлы на месте
ls -la

# 6. Сборка работает (если применимо)
# npm install
# npm test
# npm build

# 7. Очистка
cd ..
rm -rf test-clone
```

## Пост-миграционные задачи

### 6.1. Обновление ссылок

**Что нужно обновить:**
- Документация (README, wiki)
- CI/CD конфигурации
- Зависимости в package.json/pom.xml
- Ссылки в issues и pull requests
- Внешние интеграции

### 6.2. Настройка GitHub

**Рекомендуемые настройки:**

1. **Branch protection rules:**
   - Require pull request reviews
   - Require status checks
   - Include administrators

2. **Repository settings:**
   - Add topics
   - Set up description
   - Configure visibility

3. **Security:**
   - Enable vulnerability alerts
   - Set up code scanning
   - Configure secret scanning

4. **Integrations:**
   - Set up webhooks
   - Configure deploy keys
   - Add team members

### 6.3. Мониторинг

**Настройте мониторинг:**

```bash
# Скрипт для проверки синхронизации
#!/bin/bash
# check-sync.sh

SOURCE_HASH=$(git ls-remote "$SOURCE_URL" refs/heads/main | cut -f1)
TARGET_HASH=$(git ls-remote "$TARGET_URL" refs/heads/main | cut -f1)

if [[ "$SOURCE_HASH" != "$TARGET_HASH" ]]; then
    echo "ALERT: Репозитории не синхронизированы!"
    echo "Source: $SOURCE_HASH"
    echo "Target: $TARGET_HASH"
    # Отправьте уведомление
    # curl -X POST https://api.slack.com/...
fi
```

## Работа с командой

### 7.1. Обучение команды

**Проведите обучение:**

1. **До миграции:**
   - Объясните процесс миграции
   - Расскажите о преимуществах
   - Ответьте на вопросы

2. **Во время миграции:**
   - Предоставьте статус
   - Решайте проблемы оперативно
   - Коммуницируйте изменения

3. **После миграции:**
   - Проведите демонстрацию
   - Предоставьте документацию
   - Соберите обратную связь

### 7.2. Документация процесса

**Создайте документацию:**

1. **Для разработчиков:**
   - Как клонировать новый репозиторий
   - Как работать с ветками
   - Как создавать pull requests

2. **Для DevOps:**
   - Настройка CI/CD
   - Мониторинг
   - Резервное копирование

3. **Для менеджеров:**
   - Статус миграции
   - Метрики
   - Отчеты

### 7.3. Обратная связь

**Соберите обратную связь:**

1. **Опрос команды:**
   - Удобство использования
   - Производительность
   - Проблемы

2. **Метрики:**
   - Время сборки
   - Количество ошибок
   - Удовлетворенность

3. **Улучшения:**
   - На основе обратной связи
   - Регулярные обновления
   - Непрерывное улучшение

---

## 🏆 Золотые правила миграции

1. **Всегда делайте backup** перед миграцией
2. **Тестируйте на копии** репозитория
3. **Коммуницируйте** с командой
4. **Документируйте** каждый шаг
5. **Проверяйте** после миграции
6. **Готовьтесь к откату** на каждом этапе
7. **Учитесь на ошибках** и улучшайте процесс

---

**🎯 Помните:** Успешная миграция — это не просто технический процесс, это изменение рабочего процесса команды. Будьте внимательны к людям, а не только к коду.