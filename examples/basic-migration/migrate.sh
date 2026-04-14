#!/bin/bash

# Базовый скрипт миграции для простых репозиториев
# Использование: ./migrate.sh [опции]

set -e  # Выход при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/migration-$(date +%Y%m%d-%H%M%S).log"
ERROR_FILE="$LOG_DIR/error.log"

# Функции для вывода
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            echo "[$timestamp] [INFO] $message" >> "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            echo "[$timestamp] [SUCCESS] $message" >> "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            echo "[$timestamp] [WARNING] $message" >> "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            echo "[$timestamp] [ERROR] $message" >> "$LOG_FILE"
            echo "[$timestamp] [ERROR] $message" >> "$ERROR_FILE"
            ;;
    esac
}

# Проверка и создание лог-директории
setup_logging() {
    mkdir -p "$LOG_DIR"
    log "INFO" "Логирование настроено: $LOG_FILE"
}

# Загрузка переменных окружения
load_env() {
    local env_file="$SCRIPT_DIR/.env"
    
    if [[ -f "$env_file" ]]; then
        log "INFO" "Загружаем переменные из $env_file"
        # Безопасная загрузка переменных
        while IFS='=' read -r key value; do
            # Пропускаем комментарии и пустые строки
            [[ $key =~ ^#.*$ ]] || [[ -z $key ]] && continue
            # Экспортируем переменную
            export "$key"="$value"
        done < "$env_file"
        
        log "SUCCESS" "Переменные окружения загружены"
    else
        log "WARNING" "Файл .env не найден, используем переменные окружения системы"
    fi
}

# Проверка предварительных условий
check_prerequisites() {
    log "INFO" "Проверяем предварительные условия..."
    
    # Проверка Git
    if ! command -v git &> /dev/null; then
        log "ERROR" "Git не установлен"
        return 1
    fi
    log "INFO" "Git версия: $(git --version | awk '{print $3}')"
    
    # Проверка переменных
    local required_vars=("SOURCE_CRAFT_ORG" "SOURCE_CRAFT_REPO" "GITHUB_USERNAME" "GITHUB_REPO")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            log "ERROR" "Переменная $var не установлена"
            return 1
        fi
    done
    
    # Формирование URL
    SOURCE_URL="https://git@git.sourcecraft.dev/$SOURCE_CRAFT_ORG/$SOURCE_CRAFT_REPO.git"
    TARGET_URL="https://github.com/$GITHUB_USERNAME/$GITHUB_REPO.git"
    TEMP_DIR="$SCRIPT_DIR/temp-mirror-$(date +%s)"
    
    log "INFO" "Source URL: $SOURCE_URL"
    log "INFO" "Target URL: $TARGET_URL"
    log "INFO" "Temp dir: $TEMP_DIR"
    
    return 0
}

# Проверка доступности репозиториев
check_repositories() {
    log "INFO" "Проверяем доступность репозиториев..."
    
    # Проверка SourceCraft
    if ! git ls-remote "$SOURCE_URL" &> /dev/null; then
        log "ERROR" "SourceCraft репозиторий недоступен: $SOURCE_URL"
        return 1
    fi
    log "SUCCESS" "SourceCraft репозиторий доступен"
    
    # Проверка GitHub (только что созданный может быть пустым)
    if git ls-remote "$TARGET_URL" &> /dev/null; then
        log "INFO" "GitHub репозиторий существует"
    else
        log "WARNING" "GitHub репозиторий не существует или пустой"
    fi
    
    return 0
}

# Зеркальное клонирование
mirror_clone() {
    log "INFO" "Начинаем зеркальное клонирование..."
    
    if git clone --mirror "$SOURCE_URL" "$TEMP_DIR" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Зеркальное клонирование завершено"
        
        # Проверка размера
        local repo_size=$(du -sh "$TEMP_DIR" | cut -f1)
        log "INFO" "Размер mirror-репозитория: $repo_size"
        
        # Проверка веток
        cd "$TEMP_DIR"
        local branch_count=$(git branch -a | wc -l)
        log "INFO" "Количество веток: $branch_count"
        cd "$SCRIPT_DIR"
        
        return 0
    else
        log "ERROR" "Ошибка при зеркальном клонировании"
        return 1
    fi
}

# Зеркальная отправка
mirror_push() {
    log "INFO" "Начинаем зеркальную отправку на GitHub..."
    
    cd "$TEMP_DIR"
    
    if git push --mirror "$TARGET_URL" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Зеркальная отправка завершена"
        cd "$SCRIPT_DIR"
        return 0
    else
        log "ERROR" "Ошибка при зеркальной отправке"
        cd "$SCRIPT_DIR"
        return 1
    fi
}

# Проверка миграции
verify_migration() {
    log "INFO" "Проверяем миграцию..."
    
    # Временные файлы для сравнения
    local source_refs="$LOG_DIR/source-refs.txt"
    local target_refs="$LOG_DIR/target-refs.txt"
    
    # Получаем refs из source
    git ls-remote "$SOURCE_URL" | sort > "$source_refs"
    local source_count=$(wc -l < "$source_refs")
    
    # Получаем refs из target
    git ls-remote "$TARGET_URL" | sort > "$target_refs"
    local target_count=$(wc -l < "$target_refs")
    
    # Сравниваем
    if diff "$source_refs" "$target_refs" > /dev/null; then
        log "SUCCESS" "✅ Миграция успешна! Все refs совпадают"
        log "INFO" "Количество refs: source=$source_count, target=$target_count"
    else
        log "WARNING" "⚠️  Ref-ы не полностью совпадают"
        log "INFO" "Различия сохранены в $LOG_DIR/diff.txt"
        diff "$source_refs" "$target_refs" > "$LOG_DIR/diff.txt"
        
        # Показываем первые 5 различий
        log "INFO" "Первые 5 различий:"
        head -5 "$LOG_DIR/diff.txt"
    fi
    
    # Очистка временных файлов
    rm -f "$source_refs" "$target_refs"
}

# Очистка
cleanup() {
    log "INFO" "Выполняем очистку..."
    
    if [[ -d "$TEMP_DIR" ]]; then
        if rm -rf "$TEMP_DIR"; then
            log "SUCCESS" "Временная директория удалена: $TEMP_DIR"
        else
            log "WARNING" "Не удалось удалить временную директорию: $TEMP_DIR"
        fi
    fi
    
    # Очистка старых логов (сохраняем только последние 5)
    local log_files=("$LOG_DIR"/*.log)
    if [[ ${#log_files[@]} -gt 5 ]]; then
        ls -t "$LOG_DIR"/*.log | tail -n +6 | xargs rm -f
        log "INFO" "Старые логи очищены"
    fi
}

# Основная функция
main() {
    log "INFO" "=== Начало базовой миграции ==="
    log "INFO" "Время начала: $(date)"
    
    # Настройка
    setup_logging
    load_env
    
    # Проверки
    if ! check_prerequisites; then
        log "ERROR" "Проверка предварительных условий не пройдена"
        exit 1
    fi
    
    if ! check_repositories; then
        log "ERROR" "Проверка репозиториев не пройдена"
        exit 1
    fi
    
    # Миграция
    if ! mirror_clone; then
        log "ERROR" "Зеркальное клонирование не удалось"
        exit 1
    fi
    
    if ! mirror_push; then
        log "ERROR" "Зеркальная отправка не удалась"
        exit 1
    fi
    
    # Проверка
    verify_migration
    
    # Очистка
    cleanup
    
    log "SUCCESS" "=== Базовая миграция завершена успешно! ==="
    log "INFO" "Время окончания: $(date)"
    log "INFO" "Логи сохранены в: $LOG_FILE"
    
    echo ""
    echo "🎉 Миграция завершена!"
    echo "📁 Логи: $LOG_FILE"
    echo "🚀 Для работы с репозиторием выполните:"
    echo "   git clone $TARGET_URL"
    echo "   cd $GITHUB_REPO"
}

# Обработка аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            echo "Режим dry-run: проверка без реальных действий"
            check_prerequisites
            check_repositories
            echo "✅ Проверки пройдены, можно выполнять миграцию"
            exit 0
            ;;
        --help|-h)
            echo "Использование: $0 [опции]"
            echo "Опции:"
            echo "  --dry-run    Проверка без реальных действий"
            echo "  --help, -h   Показать эту справку"
            exit 0
            ;;
        *)
            echo "Неизвестный аргумент: $1"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
done

# Запуск основной функции
main "$@"