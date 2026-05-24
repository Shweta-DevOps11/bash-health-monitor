#!/bin/bash
# ============================================================
#  setup_cron.sh — Schedule health_monitor.sh via cron
#  Run this once to register automatic reporting
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR="$SCRIPT_DIR/health_monitor.sh"

if [[ ! -f "$MONITOR" ]]; then
  echo "[ERROR] health_monitor.sh not found at $MONITOR"
  exit 1
fi

# Make sure the script is executable
chmod +x "$MONITOR"

# Define cron job: run a report every hour
CRON_JOB="0 * * * * $MONITOR report >> $SCRIPT_DIR/logs/cron.log 2>&1"

# Check if already registered
if crontab -l 2>/dev/null | grep -qF "$MONITOR"; then
  echo "[INFO] Cron job already exists. No changes made."
  crontab -l | grep "$MONITOR"
else
  # Append to existing crontab
  (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
  echo "[OK] Cron job added:"
  echo "     $CRON_JOB"
  echo ""
  echo "The monitor will save a report every hour to: $SCRIPT_DIR/logs/"
  echo ""
  echo "To view your crontab:  crontab -l"
  echo "To remove this job:    run remove_cron.sh"
fi
