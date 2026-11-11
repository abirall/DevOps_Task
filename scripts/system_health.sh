
#!/usr/bin/env bash

set -uo pipefail

# ==================================================
# SYSTEM HEALTH MONITOR
# Project: Python DevOps Assessment
# ==================================================

# Configuration
APP_URL="${APP_URL:-http://localhost:5000/}"
LOG_DIR="${LOG_DIR:-/var/log/python-app}"
LOG_FILE="${LOG_DIR}/system_health.log"

CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=85

# ==================================================
# LOGGING
# ==================================================

log() {
    local level="$1"
    shift

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    printf '[%s] [%s] %s\n' \
        "$timestamp" "$level" "$*" | tee -a "$LOG_FILE"
}

# ==================================================
# INITIALIZATION
# ==================================================

initialize() {

    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            LOG_DIR="${HOME}/.local/var/log/python-app"
            LOG_FILE="${LOG_DIR}/system_health.log"
            mkdir -p "$LOG_DIR"
        }
    fi

    log INFO "Starting system health check"
}

# ==================================================
# CPU MONITORING
# ==================================================

check_cpu() {

    local cpu_usage

    cpu_usage=$(LC_ALL=C top -bn1 | awk '/Cpu\(s\)/ {
        for (i=1; i<=NF; i++) {
            if ($i ~ /id,?$/) {
                idle=$(i-1)
                gsub(/,/, "", idle)
                print 100-idle
                exit
            }
        }
    }')

    if [[ -z "$cpu_usage" ]]; then
        cpu_usage=$(LC_ALL=C top -bn1 | awk -F'[, ]+' \
            '/Cpu\(s\)/ { for(i=1;i<=NF;i++) if($i=="id") {print 100-$(i-1); exit} }')
    fi

    if [[ -z "$cpu_usage" ]]; then
        log WARNING "Unable to determine CPU usage"
        return
    fi

    cpu_usage=${cpu_usage%.*}

    log INFO "CPU usage: ${cpu_usage}%"

    if [[ "$cpu_usage" =~ ^[0-9]+$ ]] && (( cpu_usage >= CPU_THRESHOLD )); then
        log WARNING "CPU usage exceeds ${CPU_THRESHOLD}%"
    fi
}

# ==================================================
# MEMORY MONITORING
# ==================================================

check_memory() {

    local memory_usage

    memory_usage=$(free | awk '/Mem:/ {
        if ($2 > 0) {
            printf "%.0f", ($3 / $2) * 100
        }
    }')

    if [[ -z "$memory_usage" ]]; then
        log WARNING "Unable to determine memory usage"
        return
    fi

    log INFO "Memory usage: ${memory_usage}%"

    if [[ "$memory_usage" =~ ^[0-9]+$ ]] && (( memory_usage >= MEMORY_THRESHOLD )); then
        log WARNING "Memory usage exceeds ${MEMORY_THRESHOLD}%"
    fi
}

# ==================================================
# DISK MONITORING
# ==================================================

check_disk() {

    local disk_usage

    disk_usage=$(df -P / | awk 'NR==2 {
        gsub(/%/, "", $5)
        print $5
    }')

    log INFO "Root disk usage: ${disk_usage}%"

    if [[ "$disk_usage" =~ ^[0-9]+$ ]] && (( disk_usage >= DISK_THRESHOLD )); then
        log WARNING "Disk usage exceeds ${DISK_THRESHOLD}%"
    fi
}

# ==================================================
# SYSTEM LOAD
# ==================================================

check_load() {

    local load_average

    load_average=$(awk '{print $1, $2, $3}' /proc/loadavg)

    log INFO "System load averages (1, 5, 15 min): ${load_average}"
}

# ==================================================
# SYSTEM UPTIME
# ==================================================

check_uptime() {

    local uptime_info

    uptime_info=$(uptime -p)

    log INFO "System uptime: ${uptime_info}"
}

# ==================================================
# PROCESS MONITORING
# ==================================================

check_processes() {

    local process_count

    process_count=$(ps -e --no-headers | wc -l)

    log INFO "Running processes: ${process_count}"
}

# ==================================================
# DOCKER MONITORING
# ==================================================

check_docker() {

    if ! command -v docker >/dev/null 2>&1; then
        log WARNING "Docker is not installed"
        return
    fi

    if ! docker info >/dev/null 2>&1; then
        log WARNING "Docker daemon is unavailable or permission denied"
        return
    fi

    log INFO "Docker daemon is running"

    local container_count

    container_count=$(docker ps -q | wc -l)

    log INFO "Running Docker containers: ${container_count}"

    docker ps --format '{{.Names}}: {{.Status}}' | while IFS= read -r container; do
        log INFO "Container status: ${container}"
    done
}

# ==================================================
# APPLICATION HEALTH
# ==================================================

check_application() {

    if ! command -v curl >/dev/null 2>&1; then
        log WARNING "curl is not installed; application health check skipped"
        return
    fi

    local http_status

    http_status=$(curl \
        --silent \
        --output /dev/null \
        --write-out '%{http_code}' \
        --max-time 5 \
        "$APP_URL" || true)

    if [[ "$http_status" == "200" ]]; then
        log INFO "Application is healthy: ${APP_URL}"
    else
        log ERROR "Application health check failed. HTTP status: ${http_status:-000}"
    fi
}

# ==================================================
# MAIN
# ==================================================

main() {

    initialize

    check_cpu
    check_memory
    check_disk
    check_load
    check_uptime
    check_processes
    check_docker
    check_application

    log INFO "System health check completed"
    log INFO "----------------------------------------"
}

main "$@"
