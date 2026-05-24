# Bash System Health Monitor

A lightweight Linux system health monitoring tool built with bash, inspired by enterprise APM tools like AppDynamics.

## What it does

- Monitors CPU, memory, disk usage with visual progress bars
- Tracks network traffic (RX/TX)
- Watches critical services (sshd, cron, nginx, etc.)
- Logs all metrics daily to local files
- Fires alerts when thresholds are breached
- Saves plain-text reports on demand
- Schedules automatic reporting via cron

## Why I built this

In my current role I use AppDynamics for application performance monitoring. I built this project to understand infrastructure-level monitoring from first principles — what's happening at the OS layer beneath the application.

## Project Structure
## How to run

```bash
git clone https://github.com/Shweta-DevOps11/bash-health-monitor.git
cd bash-health-monitor
chmod +x health_monitor.sh
./health_monitor.sh
```

## Modes

| Command | Description |
|---|---|
| `./health_monitor.sh` | Live dashboard (refreshes every 5s) |
| `./health_monitor.sh once` | Single snapshot |
| `./health_monitor.sh report` | Save report to logs/ |

## Tech used

- Bash scripting
- Linux system tools: `top`, `free`, `df`, `ps`, `systemctl`
- Cron for scheduling
- Git & GitHub for version control
