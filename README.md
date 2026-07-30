# Daka

macOS menu bar tracker for recording the first and last time a configurable rule matches each day.

## Install

```bash
./scripts/install-autostart.sh
```

This builds `Daka.app` once, installs it at `~/Applications/Daka.app`, registers
`local.daka.menu` as a LaunchAgent, and starts it immediately. Login startup
launches the installed app directly; it does not rebuild the project.

Existing config and clock records are kept in:

```text
~/Library/Application Support/Daka/
```

To remove only the login startup item, without deleting the app or its data:

```bash
./scripts/uninstall-autostart.sh
```

## Install with Homebrew

```bash
brew install iBreaker/daka/daka
brew services start daka
```

To stop it:

```bash
brew services stop daka
```

The Homebrew formula also builds and runs a real app bundle so macOS can attach
Wi-Fi location permission to a stable bundle identifier.

To build a release app without installing it:

```bash
./scripts/build-app.sh
```

The default build uses an ad-hoc signature and never asks for a signing-key
password. Release maintainers can provide a Developer ID identity explicitly:

```bash
DAKA_SIGN_IDENTITY="Developer ID Application: ..." ./scripts/build-app.sh
```

## Permission

Daka requests location permission only when a Wi-Fi condition is configured.
macOS requires this permission to expose the current SSID. The menu shows the
permission state and links to System Settings when user action is required.

## Behavior

Daka does not calculate active-only time. It records:

```text
firstMatchedAt = today's first time the rule matched
lastMatchedAt  = today's latest time the rule matched
duration       = lastMatchedAt - firstMatchedAt
```

If the rule is unmatched in the middle of the day, that gap is not subtracted.

When the rule matches for the first time each day, Daka asks you to confirm that you have clocked in. The first time is written only after you click `已打卡`. Choosing `稍后提醒` delays the next reminder.

Daka compares today's duration with a configurable daily target. The default target is `10.5` hours.

Configuration and statistics are edited through the menu bar UI. SQLite is the storage layer, not the user-facing interface.

## UI

Daka opens into a unified dashboard with five sections:

```text
今日      Live workday progress and recent records
每日记录  Review, edit, or exclude individual days
趋势      Duration trend and workday heatmap
月度      Monthly averages, totals, and target status
设置      Targets, match rules, reminders, permissions, and runtime controls
```

Menu bar actions:

```text
打开 Daka     Open the dashboard
设置…         Open the rule editor
添加请假日…   Mark a date as excluded from statistics
暂停统计      Pause automatic record updates
退出          Quit the menu bar app
```

The config UI supports:

```text
Match mode: all / any
Evaluation interval
Daily target hours
Monthly average target hours
Weekly target hours
Rest-day reminder on/off
Rest-day reminder times
Rest-day reminder messages
Add/remove conditions
Condition parameters
Wi-Fi SSID selection from nearby/current networks
```

SSID matching is exact, including letter case and spaces. Time values are
validated before saving instead of being silently replaced with defaults.

The menu shows today's progress with a progress bar and a colored status marker:

```text
red     under 40%
orange  40% - 74%
blue    75% - 99%
green   complete
```

## Storage

Config is stored in `app_config`; daily records are stored in `daily_records`. The default config is:

The SQLite database is:

```text
~/Library/Application Support/Daka/daka.sqlite
```

Older `config.json` and `records.json` files are imported automatically. Normal
recording updates only the affected date rather than rewriting every historical
row.

```json
{
  "evaluationIntervalSeconds": 60,
  "targetDurationSeconds": 37800,
  "rule": {
    "name": "Default",
    "matchMode": "all",
    "conditions": [
      {
        "type": "screenUnlocked"
      }
    ]
  }
}
```

Supported condition types:

```json
{ "type": "screenUnlocked" }
{ "type": "wifiConnected", "ssid": "Company WiFi" }
{ "type": "powerConnected" }
{ "type": "networkReachable", "host": "intranet.company.local", "port": 443 }
{ "type": "timeRange", "start": "08:00", "end": "20:00" }
```

Example:

```json
{
  "evaluationIntervalSeconds": 60,
  "rule": {
    "name": "Office",
    "matchMode": "all",
    "conditions": [
      {
        "type": "screenUnlocked"
      },
      {
        "type": "wifiConnected",
        "ssid": "Company WiFi"
      },
      {
        "type": "powerConnected"
      }
    ]
  }
}
```

Use `配置...` from the menu bar to edit and save the rule.

## Monthly Workday Statistics

The statistics window includes a `月度` tab. It calculates each natural month's average duration across China workdays.

China workdays are loaded from the public `holiday-calendar` CN JSON data and cached locally:

```text
~/Library/Application Support/Daka/ChinaCalendar/
```

If a year cannot be loaded yet, Daka temporarily falls back to Monday-Friday
for that year and labels the result `估算`. Requests use HTTP cache validation
and bounded timeouts. Missing workday records count as `0m`, and the current
month is calculated only through yesterday so an unfinished day does not lower
the monthly average.

## Rest-Day Reminder

Daka can warn when the current China workweek has not reached the configured weekly target and a rest day is near:

```text
Last workday before a rest day: shows the rest-day reminder after its configured time
Day before the last workday: shows the day-before reminder after its configured time
```

Both reminder times and messages are editable in the dashboard's `设置 → 提醒`
section. Each reminder is shown only once per day. The reminder includes total
weekly duration, average duration per elapsed China workday, weekly target, and
remaining duration.

## Test

```bash
swift test
./scripts/check-release.sh
```
