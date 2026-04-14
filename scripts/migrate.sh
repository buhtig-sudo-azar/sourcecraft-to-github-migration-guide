#!/bin/bash

# Скрипт для автоматической миграции репозитория с SourceCraft на GitHub
# Использование: ./migrate.sh [опции]

set -e  # Выход при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка наличия Git
check_git() {
    if ! command -v git &> /dev/null; then
        print_error "Git не установлен. Установите Git и повторите попытку."
        exit 1
    fi
    print_info "Git версия: $(git --version)"
}

# Показать справку
show_help() {
    cat << EOF
Скрипт миграции репозитория с SourceCraft на GitHub

Использование: $0 [опции]

Опции:
  -s, --source URL      URL репозитория на SourceCraft
  -t, --target URL      URL репозитория на GitHub
  -d, --directory DIR   Временная директория (по умолчанию: temp-mirror-\$(date +%s))
  -c, --cleanup         Удалить временные файлы после миграции
  -v, --verify          Проверить миграцию после завершения
  -h, --help            Показать эту справку

Примеры:
  $0 -s https://git@git.sourcecraft.dev/org/repo.git -t https://github.com/user/repo.git
  $0 --source sc:org/repo.git --target gh:user/repo.git --verify --cleanup

Примечание:
  Для использования сокращений sc: и gh: настройте git config как в configs/git-config-example.txt
EOF
}

# Парсинг аргументов
SOURCE_URL=""
TARGET_URL=""
TEMP_DIR="temp-mirror-$(date +%s)"
CLEANUP=false
VERIFY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--source)
            SOURCE_URL="$2"
            shift 2
            ;;
        -t|--target)
            TARGET_URL="$2"
            shift 2
            ;;
        -d|--directory)
            TEMP_DIR="$2"
            shift 2
            ;;
        -c|--cleanup)
            CLEANUP=true
            shift
            ;;
        -v|--verify)
            VERIFY=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Неизвестный аргумент: $1"
            show_help
            exit 1
            ;;
    esac
done

# Проверка обязательных аргументов
if [[ -z "$SOURCE_URL" || -z "$TARGET_URL" ]]; then
    print_error "Необходимо указать source и target URL"
    show_help
    exit 1
fi

# Основная функция миграции
migrate_repository() {
    print_info "🚀 Начинаем миграцию..."
    print_info "Source: $SOURCE_URL"
    print_info "Target: $TARGET_URL"
    print_info "Temp dir: $TEMP_DIR"
    
    # Шаг 1: Зеркальное клонирование
    print_info "Шаг 1: Зеркальное клонирование с SourceCraft..."
    if git clone --mirror "$SOURCE_URL" "$TEMP_DIR"; then
        print_success "Клонирование завершено"
    else
        print_error "Ошибка при клонировании"
        exit 1
    fi
    
    # Шаг 2: Переход во временную директорию
    cd "$TEMP_DIR"
    
    # Шаг 3: Зеркальная отправка на GitHub
    print_info "Шаг 2: Отправка на GitHub..."
    if git push --mirror "$TARGET_URL"; then
        print_success "Отправка завершена"
    else
        print_error "Ошибка при отправке"
        cd ..
        exit 1
    fi
    
    # Шаг 4: Возврат в исходную директорию
    cd ..
    
    print_success "✅ Основная миграция завершена!"
}

# Функция проверки миграции
verify_migration() {
    print_info "🔍 Проверяем миграцию..."
    
    # Создаем временные файлы для сравнения
    SOURCE_LIST="source_refs.txt"
    TARGET_LIST="target_refs.txt"
    
    # Получаем refs из source
    print_info "Получаем refs из source..."
    git ls-remote "$SOURCE_URL" | sort > "$SOURCE_LIST"
    
    # Получаем refs из target
    print_info "Получаем refs из target..."
    git ls-remote "$TARGET_URL" | sort > "$TARGET_LIST"
    
    # Сравниваем
    if diff "$SOURCE_LIST" "$TARGET_LIST" > /dev/null; then
        print_success "✅ Ref-ы совпадают!"
        
        # Подсчет
        SOURCE_COUNT=$(wc -l < "$SOURCE_LIST")
        TARGET_COUNT=$(wc -l < "$TARGET_LIST")
        
        print_info "Количество ref-ов в source: $SOURCE_COUNT"
        print_info "Количество ref-ов в target: $TARGET_COUNT"
        
        # Показываем ветки
        print_info "Ветки в source:"
        git ls-remote --heads "$SOURCE_URL" | head -10
        
        print_info "Ветки в target:"
        git ls-remote --heads "$TARGET_URL" | head -10
        
    else
        print_warning "⚠️  Ref-ы не совпадают полностью"
        print_info "Различия:"
        diff "$SOURCE_LIST" "$TARGET_LIST" | head -20
    fi
    
    # Очистка временных файлов
    rm -f "$SOURCE_LIST" "$TARGET_LIST"
}

# Функция очистки
cleanup() {
    print_info "🧹 Очищаем временные файлы..."
    
    if [[ -d "$TEMP_DIR" ]]; then
        if rm -rf "$TEMP_DIR"; then
            print_success "Временная директория удалена: $TEMP_DIR"
        else
            print_warning "Не удалось удалить временную директорию: $TEMP_DIR"
        fi
    fi
}

# Основной скрипт
main() {
    print_info "=== Начало миграции ==="
    print_info "Время: $(date)"
    
    # Проверка Git
    check_git
    
    # Миграция
    migrate_repository
    
    # Проверка (если нужно)
    if $VERIFY; then
        verify_migration
    fi
    
    # Очистка (если нужно)
    if $CLEANUP; then
        cleanup
    else
        print_warning "Временная директория сохранена: $TEMP_DIR"
        print_info "Для очистки выполните: rm -rf $TEMP_DIR"
    fi
    
    print_success "🎉 Миграция успешно завершена!"
    print_info "Для работы с репозиторием выполните:"
    print_info "  git clone $TARGET_URL"
    print_info "  cd $(basename "$TARGET_URL" .git)"
}

# Запуск основного скрипта
main "$@"