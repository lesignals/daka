import Foundation

public enum DakaInputValidator {
    public static func normalizedTime(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
            (1...2).contains(parts[0].count),
            parts[1].count == 2,
            parts.allSatisfy({ $0.allSatisfy(\.isNumber) }),
            let hour = Int(parts[0]),
            let minute = Int(parts[1]),
            (0...23).contains(hour),
            (0...59).contains(minute)
        else {
            return nil
        }

        return String(format: "%02d:%02d", hour, minute)
    }

    public static func positiveNumber(
        _ value: String,
        range: ClosedRange<Double>
    ) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = Double(trimmed), number.isFinite, range.contains(number) else {
            return nil
        }
        return number
    }

    public static func evaluationInterval(_ value: String) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let seconds = Int(trimmed), (10...86_400).contains(seconds) else {
            return nil
        }
        return TimeInterval(seconds)
    }
}

public enum WiFiSSIDMatcher {
    public static func matches(current: String?, expected: String) -> Bool {
        guard let current else {
            return false
        }
        return current == expected
    }
}

public enum DailyRecordTimeEditor {
    public static func updating(
        _ record: DailyRecord,
        firstTime: Date,
        lastTime: Date,
        calendar: Calendar = .current
    ) -> DailyRecord? {
        guard let recordDate = ChinaWorkdayCalendar.dateFormatter.date(from: record.date),
            let first = combine(date: recordDate, time: firstTime, calendar: calendar),
            let last = combine(date: recordDate, time: lastTime, calendar: calendar),
            last >= first
        else {
            return nil
        }

        var updated = record
        updated.firstMatchedAt = first
        updated.lastMatchedAt = last
        return updated
    }

    private static func combine(date: Date, time: Date, calendar: Calendar) -> Date? {
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var combined = DateComponents()
        combined.calendar = calendar
        combined.timeZone = calendar.timeZone
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        return calendar.date(from: combined)
    }
}

public struct WiFiProfilerSnapshot: Equatable, Sendable {
    public var currentSSID: String?
    public var visibleSSIDs: [String]

    public init(currentSSID: String?, visibleSSIDs: [String]) {
        self.currentSSID = currentSSID
        self.visibleSSIDs = visibleSSIDs
    }
}

public enum WiFiProfilerParser {
    public static func parse(_ output: String) -> WiFiProfilerSnapshot {
        enum Section {
            case current
            case visible
        }

        var section: Section?
        var sectionIndent = 0
        var candidateIndent: Int?
        var currentSSID: String?
        var visible = Set<String>()

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indent = line.prefix { $0 == " " || $0 == "\t" }.count

            if trimmed == "Current Network Information:" {
                section = .current
                sectionIndent = indent
                candidateIndent = nil
                continue
            }
            if trimmed == "Other Local Wi-Fi Networks:" {
                section = .visible
                sectionIndent = indent
                candidateIndent = nil
                continue
            }

            guard let activeSection = section else {
                continue
            }
            if !trimmed.isEmpty, indent <= sectionIndent {
                section = nil
                candidateIndent = nil
                continue
            }
            guard trimmed.hasSuffix(":"), indent > sectionIndent else {
                continue
            }

            if candidateIndent == nil {
                candidateIndent = indent
            }
            guard indent == candidateIndent else {
                continue
            }

            let name = String(trimmed.dropLast())
            guard !name.isEmpty else {
                continue
            }
            switch activeSection {
            case .current:
                if currentSSID == nil {
                    currentSSID = name
                    visible.insert(name)
                }
            case .visible:
                visible.insert(name)
            }
        }

        return WiFiProfilerSnapshot(
            currentSSID: currentSSID,
            visibleSSIDs: visible.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        )
    }
}
