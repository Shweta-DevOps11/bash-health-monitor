#!/bin/bash
# ============================================================
#  health_monitor.sh — System Health Monitor
#  Inspired by enterprise APM tools like AppDynamics
#  Author: You | Version: 1.0
# ============================================================

# ---------- Load config ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.cfg"

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  echo "[ERROR] config.cfg not found in $SCRIPT_DIR"
  exit 1
fi

# ---------- Derived paths ----------
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/health_$(date +%Y-%m-%d).log"
ALERT_LOG="$LOG_DIR/alerts.log"
mkdir -p "$LOG_DIR"

# ---------- Colors ----------
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ============================================================
#  UTILITY FUNCTIONS
# ============================================================

timestamp() { date "+%Y-%m-%d %H:%M:%S"; }

log() {
  local level="$1"; shift
  echo "[$(timestamp)] [$level] $*" >> "$LOG_FILE"
}

alert() {
  local metric="$1"
  local value="$2"
  local threshold="$3"
  local msg="ALERT: $metric is at ${value}% (threshold: ${threshold}%)"
  echo "[$(timestamp)] $msg" >> "$ALERT_LOG"
  log "ALERT" "$msg"

  if [[ "$ENABLE_EMAIL_ALERTS" == "true" && -n "$ALERT_EMAIL" ]]; then
    echo "$msg" | mail -s "[HealthMonitor] $metric Critical" "$ALERT_EMAIL" 2>/dev/null
  fi
}

print_header() {
  clear
  echo -e "${BOLD}${CYAN}"
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║           SYSTEM HEALTH MONITOR  v1.0                   ║"
  echo "║           $(hostname)  |  $(timestamp)          ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

status_color() {
  local value="$1"
  local warn="$2"
  local crit="$3"
  if (( $(echo "$value >= $crit" | bc -l) )); then
    echo -e "${RED}"
  elif (( $(echo "$value >= $warn" | bc -l) )); then
    echo -e "${YELLOW}"
  else
    echo -e "${GREEN}"
  fi
}

draw_bar() {
  local pct="$1"       # 0–100
  local width=30
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  printf '['
  printf '%0.s█' $(seq 1 $filled)
  printf '%0.s░' $(seq 1 $empty)
  printf '] %3d%%' "$pct"
}

# ============================================================
#  METRIC COLLECTORS
# ============================================================

get_cpu() {
  # Average CPU idle over 1 second, subtract from 100 for usage
  local idle
  idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%,')
  # Fallback for different top formats
  if [[ -z "$idle" ]]; then
    idle=$(top -bn1 | grep "%Cpu" | awk '{print $8}')
  fi
  if [[ -z "$idle" ]]; then
    echo "0"
  else
    echo "$idle" | awk '{printf "%.1f", 100 - $1}'
  fi
}

get_memory() {
  free | awk '/Mem:/ {printf "%.1f", ($3/$2)*100}'
}

get_memory_details() {
  free -h | awk '/Mem:/ {print "Total:"$2"  Used:"$3"  Free:"$4"  Cache:"$6}'
}

get_disk() {
  # Returns usage % for the mount point defined in config
  df "$DISK_MOUNT" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
}

get_disk_details() {
  df -h "$DISK_MOUNT" 2>/dev/null | awk 'NR==2 {print "Total:"$2"  Used:"$3"  Free:"$4}'
}

get_load_avg() {
  uptime | awk -F'load average:' '{print $2}' | xargs
}

get_uptime() {
  uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}'
}

get_top_processes() {
  ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=6 {printf "  %-25s CPU:%5s%%  MEM:%5s%%\n", $11, $3, $4}'
}

get_network_stats() {
  # Read TX/RX bytes for the configured interface
  local iface="$NETWORK_INTERFACE"
  local rx tx
  rx=$(cat /sys/class/net/"$iface"/statistics/rx_bytes 2>/dev/null || echo 0)
  tx=$(cat /sys/class/net/"$iface"/statistics/tx_bytes 2>/dev/null || echo 0)
  echo "RX: $(numfmt --to=iec $rx 2>/dev/null || echo ${rx}B)  TX: $(numfmt --to=iec $tx 2>/dev/null || echo ${tx}B)"
}

check_services() {
  echo ""
  echo -e "${BOLD}  Watched Services:${RESET}"
  IFS=',' read -ra SVCS <<< "$WATCHED_SERVICES"
  for svc in "${SVCS[@]}"; do
    svc=$(echo "$svc" | xargs)  # trim spaces
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      echo -e "    ${GREEN}●${RESET} $svc  [running]"
      log "INFO" "Service $svc is running"
    else
      # Try checking as a process name if systemctl fails
      if pgrep -x "$svc" > /dev/null 2>&1; then
        echo -e "    ${GREEN}●${RESET} $svc  [running as process]"
        log "INFO" "Service/process $svc is running"
      else
        echo -e "    ${RED}●${RESET} $svc  [NOT running]"
        log "ALERT" "Service $svc is NOT running"
        echo "[$(timestamp)] ALERT: Service $svc is NOT running" >> "$ALERT_LOG"
      fi
    fi
  done
}

# ============================================================
#  DISPLAY
# ============================================================

display_metrics() {
  local cpu mem disk load

  cpu=$(get_cpu)
  mem=$(get_memory)
  disk=$(get_disk)
  load=$(get_load_avg)

  # Trigger alerts if thresholds are breached
  (( $(echo "$cpu >= $CPU_CRITICAL" | bc -l) )) && alert "CPU" "$cpu" "$CPU_CRITICAL"
  (( $(echo "$mem >= $MEM_CRITICAL" | bc -l) )) && alert "Memory" "$mem" "$MEM_CRITICAL"
  [[ -n "$disk" ]] && (( $(echo "$disk >= $DISK_CRITICAL" | bc -l) )) && alert "Disk" "$disk" "$DISK_CRITICAL"

  # Log metrics
  log "INFO" "CPU=${cpu}% MEM=${mem}% DISK=${disk:-N/A}% LOAD=${load}"

  echo -e "${BOLD}  ── Core Metrics ──────────────────────────────────────${RESET}"
  echo ""

  # CPU
  local color
  color=$(status_color "$cpu" "$CPU_WARN" "$CPU_CRITICAL")
  echo -e "  ${BOLD}CPU Usage   ${RESET}${color}$(draw_bar ${cpu%.*})${RESET}"
  echo -e "  ${CYAN}  Load Avg: $load${RESET}"
  echo ""

  # Memory
  color=$(status_color "$mem" "$MEM_WARN" "$MEM_CRITICAL")
  echo -e "  ${BOLD}Memory      ${RESET}${color}$(draw_bar ${mem%.*})${RESET}"
  echo -e "  ${CYAN}  $(get_memory_details)${RESET}"
  echo ""

  # Disk
  if [[ -n "$disk" ]]; then
    color=$(status_color "$disk" "$DISK_WARN" "$DISK_CRITICAL")
    echo -e "  ${BOLD}Disk ($DISK_MOUNT)${RESET}${color}$(draw_bar $disk)${RESET}"
    echo -e "  ${CYAN}  $(get_disk_details)${RESET}"
  else
    echo -e "  ${BOLD}Disk        ${YELLOW}Mount '$DISK_MOUNT' not found${RESET}"
  fi
  echo ""

  echo -e "${BOLD}  ── Network ────────────────────────────────────────────${RESET}"
  echo -e "  ${CYAN}Interface: $NETWORK_INTERFACE  |  $(get_network_stats)${RESET}"
  echo ""

  echo -e "${BOLD}  ── System ─────────────────────────────────────────────${RESET}"
  echo -e "  ${CYAN}Uptime: $(get_uptime)${RESET}"
  echo ""

  echo -e "${BOLD}  ── Top Processes (by CPU) ─────────────────────────────${RESET}"
  echo -e "${CYAN}$(get_top_processes)${RESET}"

  check_services

  echo ""
  echo -e "  ${CYAN}Logs: $LOG_FILE${RESET}"
  echo -e "  ${CYAN}Alerts: $ALERT_LOG${RESET}"
  echo ""
  echo -e "  ${BOLD}Refresh every ${REFRESH_INTERVAL}s  |  Press Ctrl+C to exit${RESET}"
}

# ============================================================
#  MODES
# ============================================================

run_once() {
  print_header
  display_metrics
}

run_watch() {
  while true; do
    print_header
    display_metrics
    sleep "$REFRESH_INTERVAL"
  done
}

run_report() {
  local report_file="$LOG_DIR/report_$(date +%Y-%m-%d_%H-%M-%S).txt"
  {
    echo "=============================="
    echo " HEALTH REPORT — $(timestamp)"
    echo " Host: $(hostname)"
    echo "=============================="
    echo ""
    echo "CPU Usage   : $(get_cpu)%"
    echo "Memory Usage: $(get_memory)%"
    echo "Memory Detail: $(get_memory_details)"
    echo "Disk Usage  : $(get_disk)%  $(get_disk_details)"
    echo "Load Avg    : $(get_load_avg)"
    echo "Uptime      : $(get_uptime)"
    echo "Network     : $(get_network_stats)"
    echo ""
    echo "Top Processes:"
    get_top_processes
    echo ""
    echo "Services:"
    IFS=',' read -ra SVCS <<< "$WATCHED_SERVICES"
    for svc in "${SVCS[@]}"; do
      svc=$(echo "$svc" | xargs)
      if systemctl is-active --quiet "$svc" 2>/dev/null || pgrep -x "$svc" > /dev/null 2>&1; then
        echo "  ✔ $svc"
      else
        echo "  ✘ $svc  [NOT running]"
      fi
    done
  } | tee "$report_file"
  echo ""
  echo "Report saved to: $report_file"
}

# ============================================================
#  ENTRY POINT
# ============================================================

case "${1:-watch}" in
  once)   run_once ;;
  report) run_report ;;
  watch)  run_watch ;;
  *)
    echo "Usage: $0 [watch|once|report]"
    echo "  watch   — live dashboard, refreshes every N seconds (default)"
    echo "  once    — print metrics once and exit"
    echo "  report  — save a plain-text report to logs/"
    exit 1
    ;;
esac
