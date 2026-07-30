import DakaCore
import Foundation

enum DakaPreviewFixtures {
    static func make() -> (records: [DailyRecord], config: AppConfig) {
        (
            records: makeRecords(),
            config: AppConfig(
                rule: TimerRule(
                    name: "Office",
                    matchMode: .all,
                    conditions: [
                        .screenUnlocked,
                        .powerConnected,
                        .wifiConnected(ssid: "Demo Office")
                    ]
                ),
                evaluationIntervalSeconds: 60,
                targetDurationSeconds: 10.5 * 60 * 60,
                monthlyAverageTargetSeconds: 10.5 * 60 * 60,
                restDayReminderEnabled: true,
                weeklyTargetSeconds: 52.5 * 60 * 60,
                restDayReminderTime: "09:30",
                dayBeforeRestReminderTime: "18:00",
                restDayReminderMessage:
                    "明天就是休息日，本周时长还没达到目标，今天别跑太早。",
                dayBeforeRestReminderMessage:
                    "明天是最后一个工作日，注意本周时长，可以提前攒一点。"
            )
        )
    }

    private static func makeRecords() -> [DailyRecord] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .current

        let today = calendar.startOfDay(for: Date())
        let durationMinutes = [
            569, 647, 622, 680, 604,
            635, 653, 590, 666, 617
        ]
        var records: [DailyRecord] = []

        for offset in 0..<75 {
            guard
                let date = calendar.date(
                    byAdding: .day,
                    value: -offset,
                    to: today
                )
            else {
                continue
            }

            let weekday = calendar.component(.weekday, from: date)
            guard (2...6).contains(weekday) else {
                continue
            }

            let startHour = offset == 0 ? 9 : 8 + (offset % 2)
            let startMinute = offset == 0 ? 18 : 18 + ((offset * 7) % 35)
            guard
                let first = calendar.date(
                    bySettingHour: startHour,
                    minute: startMinute,
                    second: 0,
                    of: date
                ),
                let last = calendar.date(
                    byAdding: .minute,
                    value: durationMinutes[offset % durationMinutes.count],
                    to: first
                )
            else {
                continue
            }

            records.append(
                DailyRecord(
                    date: ChinaWorkdayCalendar.dateFormatter.string(from: date),
                    firstMatchedAt: first,
                    lastMatchedAt: last,
                    excludedFromStats: offset == 17 || offset == 43
                )
            )
        }

        return records
    }
}
