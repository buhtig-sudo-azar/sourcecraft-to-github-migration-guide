#!/bin/bash

# Скрипт проверки готовности к миграции
# Проверяет все предварительные условия перед началом миграции

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация
CHECKLIST_FILE="pre-migration-checklist.txt"
REPORT_FILE="pre-migration-report-$(date +%Y%m%d).md"
TEMP_DIR="/tmp/migration-check-$(date +%s)"

# Счетчики
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Функции для вывода
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   ПРОВЕРКА ГОТОВНОСТИ К МИГРАЦИИ   ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_check() {
    local status=$1
    local message=$2
    
    case $status in
        "PASS")
            echo -e "${GREEN}✓ PASS${NC}: $message"
            ((PASSED_CHECKS++))
            ;;
        "FAIL")
            echo -e "${RED}✗ FAIL${NC}: $message"
            ((FAILED_CHECKS++))
            ;;
        "WARN")
            echo -e "${YELLOW}⚠ WARN${NC}: $message"
            ((WARNING_CHECKS++))
            ;;
    esac
    ((TOTAL_CHECKS++))
}

print_summary() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}           ИТОГ ПРОВЕРКИ             ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "Всего проверок: $TOTAL_CHECKS"
    echo -e "${GREEN}Пройдено: $PASSED_CHECKS${NC}"
    echo -e "${RED}Не пройдено: $FAILED_CHECKS${NC}"
    echo -e "${YELLOW}Предупреждений: $WARNING_CHECKS${NC}"
    echo ""
    
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        echo -e "${GREEN}✅ Все проверки пройдены! Можно начинать миграцию.${NC}"
    else
        echo -e "${RED}❌ Есть проблемы, которые нужно решить перед миграцией.${NC}"
    fi
}

# Проверка системы
check_system() {
    echo -e "${BLUE}[1] ПРОВЕРКА СИСТЕМЫ${NC}"
    
    # Git
    if command -v git &> /dev/null; then
        local git_version=$(git --version | awk '{print $3}')
        print_check "PASS" "Git установлен (версия: $git_version)"
        
        # Проверка минимальной версии
        local major=$(echo $git_version | cut -d. -f1)
        if [[ $major -ge 2 ]]; then
            print_check "PASS" "Git версия >= 2.0"
        else
            print_check "FAIL" "Git версия < 2.0 (требуется обновление)"
        fi
    else
        print_check "FAIL" "Git не установлен"
    fi
    
    # Дисковое пространство
    local free_space=$(df -h . | awk 'NR==2 {print $4}')
    print_check "INFO" "Свободное место: $free_space"
    
    # Память
    local free_mem=$(free -h | awk 'NR==2 {print $7}')
    print_check "INFO" "Свободная память: $free_mem"
    
    echo ""
}

# Проверка сети
check_network() {
    echo -e "${BLUE}[2] ПРОВЕРКА СЕТИ${NC}"
    
    # SourceCraft доступность
    if ping -c 1 -W 2 git.sourcecraft.dev &> /dev/null; then
        print_check "PASS" "SourceCraft доступен"
    else
        print_check "FAIL" "SourceCraft недоступен"
    fi
    
    # GitHub доступность
    if ping -c 1 -W 2 github.com &> /dev/null; then
        print_check "PASS" "GitHub доступен"
    else
        print_check "FAIL" "GitHub недоступен"
    fi
    
    # Скорость сети (примерная)
    print_check "INFO" "Проверка скорости сети..."
    
    echo ""
}

# Проверка репозитория
check_repository() {
    echo -e "${BLUE}[3] ПРОВЕРКА РЕПОЗИТОРИЯ${NC}"
    
    read -p "URL репозитория на SourceCraft: " source_url
    
    if [[ -z "$source_url" ]]; then
        print_check "FAIL" "URL репозитория не указан"
        return
    fi
    
    # Проверка доступности
    if git ls-remote "$source_url" &> /dev/null; then
        print_check "PASS" "Репозиторий доступен"
        
        # Получение информации
        mkdir -p "$TEMP_DIR"
        cd "$TEMP_DIR"
        
        # Количество коммитов
        local commit_count=$(git ls-remote "$source_url" | grep -c 'refs/heads')
        print_check "INFO" "Количество коммитов: $commit_count"
        
        # Количество веток
        local branch_count=$(git ls-remote --heads "$source_url" | wc -l)
        print_check "INFO" "Количество веток: $branch_count"
        
        # Количество тегов
        local tag_count=$(git ls-remote --tags "$source_url" | wc -l)
        print_check "INFO" "Количество тегов: $tag_count"
        
        # Размер репозитория (примерно)
        if [[ $commit_count -gt 10000 ]]; then
            print_check "WARN" "Большое количество коммитов (>10k)"
        fi
        
        if [[ $branch_count -gt 50 ]]; then
            print_check "WARN" "Много веток (>50)"
        fi
        
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
    else
        print_check "FAIL" "Репозиторий недоступен или не существует"
    fi
    
    echo ""
}

# Проверка учетных данных
check_credentials() {
    echo -e "${BLUE}[4] ПРОВЕРКА УЧЕТНЫХ ДАННЫХ${NC}"
    
    # SourceCraft токен
    if [[ -n "$SOURCE_CRAFT_TOKEN" ]]; then
        print_check "PASS" "SourceCraft токен установлен"
    else
        print_check "WARN" "SourceCraft токен не установлен (будет запрошен)"
    fi
    
    # GitHub токен
    if [[ -n "$GITHUB_TOKEN" ]]; then
        print_check "PASS" "GitHub токен установлен"
    else
        print_check "WARN" "GitHub токен не установлен (будет запрошен)"
    fi
    
    # GitHub репозиторий
    read -p "Имя репозитория на GitHub: " github_repo
    if [[ -n "$github_repo" ]]; then
        print_check "INFO" "Целевой репозиторий: $github_repo"
    else
        print_check "WARN" "Имя репозитория на GitHub не указано"
    fi
    
    echo ""
}

# Проверка зависимостей
check_dependencies() {
    echo -e "${BLUE}[5] ПРОВЕРКА ЗАВИСИМОСТЕЙ${NC}"
    
    # Проверка наличия curl
    if command -v curl &> /dev/null; then
        print_check "PASS" "curl установлен"
    else
        print_check "WARN" "curl не установлен (может потребоваться)"
    fi
    
    # Проверка наличия jq (для работы с JSON)
    if command -v jq &> /dev/null; then
        print_check "PASS" "jq установлен"
    else
        print_check "INFO" "jq не установлен (необязательно)"
    fi
    
    # Проверка SSH
    if [[ -f ~/.ssh/id_ed25519.pub ]] || [[ -f ~/.ssh/id_rsa.pub ]]; then
        print_check "PASS" "SSH ключи найдены"
    else
        print_check "INFO" "SSH ключи не найдены (будет использоваться HTTPS)"
    fi
    
    echo ""
}

# Проверка времени
check_timing() {
    echo -e "${BLUE}[6] ПРОВЕРКА ВРЕМЕНИ${NC}"
    
    local current_hour=$(date +%H)
    local current_day=$(date +%u)  # 1-7 (понедельник-воскресенье)
    
    # Проверка времени суток
    if [[ $current_hour -ge 9 && $current_hour -le 18 ]]; then
        print_check "WARN" "Рабочее время (9:00-18:00) - возможны помехи"
    else
        print_check "PASS" "Вне рабочего времени - хорошее время для миграции"
    fi
    
    # Проверка дня недели
    if [[ $current_day -ge 6 ]]; then
        print_check "PASS" "Выходной день - отличное время для миграции"
    else
        print_check "INFO" "Будний день"
    fi
    
    # Оценка времени миграции
    print_check "INFO" "Текущее время: $(date)"
    
    echo ""
}

# Создание отчета
create_report() {
    echo -e "${BLUE}[7] СОЗДАНИЕ ОТЧЕТА${NC}"
    
    cat > "$REPORT_FILE" << EOF
# Отчет проверки готовности к миграции
**Дата:** $(date)
**Всего проверок:** $TOTAL_CHECKS
**Пройдено:** $PASSED_CHECKS
**Не пройдено:** $FAILED_CHECKS
**Предупреждения:** $WARNING_CHECKS

## Рекомендации
EOF
    
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        echo "✅ Все проверки пройдены. Можно начинать миграцию." >> "$REPORT_FILE"
    else
        echo "❌ Есть проблемы, которые нужно решить перед миграцией." >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
    echo "## Следующие шаги" >> "$REPORT_FILE"
    
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        echo "1. Решите проблемы, отмеченные как FAIL" >> "$REPORT_FILE"
        echo "2. Повторите проверку" >> "$REPORT_FILE"
        echo "3. Начните миграцию только после устранения всех проблем" >> "$REPORT_FILE"
    else
        echo "1. Создайте backup репозитория" >> "$REPORT_FILE"
        echo "2. Запустите миграцию: \`./scripts/migrate.sh\`" >> "$REPORT_FILE"
        echo "3. Проверьте миграцию: \`./scripts/verify.sh\`" >> "$REPORT_FILE"
    fi
    
    print_check "PASS" "Отчет создан: $REPORT_FILE"
    echo ""
}

# Создание чек-листа
create_checklist() {
    cat > "$CHECKLIST_FILE" << 'EOF'
# Чек-лист подготовки к миграции

## Перед миграцией
- [ ] Создан backup репозитория
- [ ] Команда уведомлена о времени миграции
- [ ] Выбрано время вне рабочих часов
- [ ] Проведена проверка готовности (pre-migration-check.sh)

## Токены доступа
- [ ] SourceCraft PAT создан (права: read_repository)
- [ ] GitHub PAT создан (права: repo)
- [ ] Токены сохранены в безопасном месте
- [ ] Срок действия токенов проверен

## Репозитории
- [ ] SourceCraft репозиторий доступен
- [ ] GitHub репозиторий создан (пустой)
- [ ] Имена репозиториев совпадают
- [ ] Проверена видимость (public/private)

## Система
- [ ] Git версии 2.0+ установлен
- [ ] Достаточно дискового пространства
- [ ] Стабильное интернет-соединение
- [ ] SSH ключи настроены (опционально)

## После миграции
- [ ] Проверена целостность миграции
- [ ] Обновлены CI/CD конфигурации
- [ ] Обновлена документация
- [ ] Команда проинформирована
- [ ] Старый репозиторий архивирован

## Экстренные ситуации
- [ ] Есть план отката
- [ ] Есть контакты для экстренной связи
- [ ] Backup доступен для восстановления
EOF
    
    print_check "PASS" "Чек-лист создан: $CHECKLIST_FILE"
}

# Основная функция
main() {
    print_header
    
    check_system
    check_network
    check_repository
    check_credentials
    check_dependencies
    check_timing
    
    create_report
    create_checklist
    
    print_summary
    
    # Рекомендации
    echo ""
    echo -e "${BLUE}РЕКОМЕНДАЦИИ:${NC}"
    
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        echo "1. Решите проблемы, отмеченные как FAIL"
        echo "2. Повторите проверку: $0"
        echo "3. Только после этого начинайте миграцию"
    else
        echo "1. Ознакомьтесь с чек-листом: $CHECKLIST_FILE"
        echo "2. Создайте backup репозитория"
        echo "3. Запустите миграцию: ./scripts/migrate.sh"
    fi
    
    echo ""
    echo "Отчет: $REPORT_FILE"
    echo "Чек-лист: $CHECKLIST_FILE"
}

# Обработка аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            echo "Использование: $0 [опции]"
            echo "Опции:"
            echo "  --help, -h    Показать эту справку"
            echo "  --quick       Быстрая проверка (без деталей)"
            exit 0
            ;;
        --quick)
            # Упрощенная проверка
            check_system | grep -E "(FAIL|WARN|PASS:.*error)"
            check_network | grep -E "(FAIL|WARN)"
            exit 0
            ;;
        *)
            echo "Неизвестный аргумент: $1"
            exit 1
            ;;
    esac
    shift
done

# Запуск
main