#!/bin/bash
# ============================================================
#  remove_cron.sh — Remove health_monitor cron job
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR="$SCRIPT_DIR/health_monitor.sh"

if crontab -l 2>/dev/null | grep -qF "$MONITOR"; then
  crontab -l | grep -vF "$MONITOR" | crontab -
  echo "[OK] Cron job removed."
else
  echo "[INFO] No cron job found for health_monitor.sh."
fi
