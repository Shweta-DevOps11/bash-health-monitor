# Bash System Health Monitor — Setup & Usage Guide

A lightweight system health monitoring script inspired by enterprise APM tools like AppDynamics.
Monitors CPU, memory, disk, network, and key services — with logging, alerting, and cron scheduling.

---

## Project Structure

```
health_monitor/
├── health_monitor.sh   ← Main script (the monitor itself)
├── config.cfg          ← Your thresholds, services, settings
├── setup_cron.sh       ← Schedules the monitor to run hourly
├── remove_cron.sh      ← Removes the cron schedule
└── logs/               ← Auto-created on first run
    ├── health_YYYY-MM-DD.log   ← Daily metric logs
    ├── alerts.log              ← All threshold breaches
    ├── report_*.txt            ← Saved reports
    └── cron.log                ← Cron output
```

---

## Step 1 — Copy the files to your machine

If you're on Linux or macOS, create the project folder and move all files into it:

```bash
mkdir -p ~/health_monitor
cd ~/health_monitor
# Copy health_monitor.sh, config.cfg, setup_cron.sh, remove_cron.sh here
```

Or clone if you've put it in Git:
```bash
git clone <your-repo-url> ~/health_monitor
cd ~/health_monitor
```

---

## Step 2 — Make all scripts executable

```bash
chmod +x health_monitor.sh setup_cron.sh remove_cron.sh
```

---

## Step 3 — Configure for your machine

Open `config.cfg` in any text editor:

```bash
nano config.cfg
```

Key things to check:

### Find your network interface name
```bash
ip link show
# or
ifconfig
```
Look for something like `eth0`, `ens33`, `enp0s3`, or `wlan0`.
Update `NETWORK_INTERFACE=` in config.cfg with the correct name.

### Choose services to watch
```bash
# See which services are running
systemctl list-units --type=service --state=running
```
Add the ones you care about to `WATCHED_SERVICES` as a comma-separated list.
Example: `WATCHED_SERVICES="sshd, nginx, mysql"`

### Adjust thresholds
Default thresholds are sensible starting points:
- CPU warn at 70%, critical at 90%
- Memory warn at 75%, critical at 90%
- Disk warn at 80%, critical at 90%

Change these in config.cfg to suit your system.

---

## Step 4 — Run it

### Live dashboard (refreshes every 5 seconds)
```bash
./health_monitor.sh watch
# or simply (watch is the default)
./health_monitor.sh
```

Press `Ctrl+C` to exit.

### Single snapshot (print once and exit)
```bash
./health_monitor.sh once
```

### Save a plain-text report
```bash
./health_monitor.sh report
```
The report is saved to `logs/report_YYYY-MM-DD_HH-MM-SS.txt`.

---

## Step 5 — Schedule it with cron (optional)

To automatically save a health report every hour:

```bash
./setup_cron.sh
```

Verify it was added:
```bash
crontab -l
```

To remove the cron job later:
```bash
./remove_cron.sh
```

---

## Step 6 — View your logs

```bash
# Today's metrics log
cat logs/health_$(date +%Y-%m-%d).log

# All alerts
cat logs/alerts.log

# List all saved reports
ls logs/report_*.txt

# Tail the log live
tail -f logs/health_$(date +%Y-%m-%d).log
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `config.cfg not found` | Make sure all files are in the same directory |
| Network stats show 0 | Check `NETWORK_INTERFACE` in config — run `ip link` to find correct name |
| Disk mount not found | Change `DISK_MOUNT` to `/` or whichever mount exists on your system |
| Service shows NOT running | Some systems use different service names — check with `systemctl list-units` |
| `bc: command not found` | Install with `sudo apt install bc` (Ubuntu/Debian) or `sudo yum install bc` |
| `top` output format differs | Some distros format `top` differently — CPU may show 0% on first run, then normalise |

---

## How it relates to AppDynamics (interview talking points)

| AppDynamics | This Script |
|---|---|
| Agent-based, application layer | OS/infrastructure layer via bash |
| SaaS, commercial, managed | Self-built, open, fully transparent |
| GUI dashboards | Terminal dashboard with ASCII bars |
| Automatic alerting | Threshold-based log alerts (extensible to email) |
| Historical data in their cloud | Local log files you own |
| JVM/code-level tracing | Process-level CPU/memory monitoring |

**The key insight to share in interviews:** AppDynamics tells you *what* is wrong at the app level. This script tells you *why* — is the server itself under pressure? You built it to understand infrastructure monitoring from first principles.

---

## What to say in interviews

> "I use AppDynamics daily for application performance monitoring — tracking response times, error rates, and JVM metrics. To go deeper, I built a bash script that monitors the underlying infrastructure: CPU, memory, disk, and critical services. It logs every metric, fires alerts when thresholds are breached, and can save reports automatically via cron. Building it taught me how APM tools work at the OS level, not just the application layer."
