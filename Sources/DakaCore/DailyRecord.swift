import Foundation

public struct DailyRecord: Codable, Equatable, Sendable {
    public var date: String
    public var firstMatchedAt: Date?
    public var lastMatchedAt: Date?
    public var excludedFromStats: Bool

    private enum CodingKeys: String, CodingKey {
        case date
        case firstMatchedAt
        case lastMatchedAt
        case excludedFromStats
    }

    public init(
        date: String,
        firstMatchedAt: Date? = nil,
        lastMatchedAt: Date? = nil,
        excludedFromStats: Bool = false
    ) {
        self.date = date
        self.firstMatchedAt = firstMatchedAt
        self.lastMatchedAt = lastMatchedAt
        self.excludedFromStats = excludedFromStats
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.date = try container.decode(String.self, forKey: .date)
        self.firstMatchedAt = try container.decodeIfPresent(Date.self, forKey: .firstMatchedAt)
        self.lastMatchedAt = try container.decodeIfPresent(Date.self, forKey: .lastMatchedAt)
        self.excludedFromStats = try container.decodeIfPresent(Bool.self, forKey: .excludedFromStats) ?? false
    }

    public var spanSeconds: TimeInterval? {
        guard let firstMatchedAt, let lastMatchedAt else {
            return nil
        }

        return max(0, lastMatchedAt.timeIntervalSince(firstMatchedAt))
    }
}

public final class DailyRecorder {
    private let calendar: Calendar
    private let dateFormatter: DateFormatter

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.dateFormatter = DateFormatter()
        self.dateFormatter.calendar = calendar
        self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.dateFormatter.timeZone = calendar.timeZone
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
    }

    public func dateKey(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    public func update(record: DailyRecord?, matched: Bool, at date: Date) -> DailyRecord {
        let key = dateKey(for: date)
        var current = record?.date == key ? record! : DailyRecord(date: key)

        guard matched else {
            return current
        }

        if current.firstMatchedAt == nil {
            current.firstMatchedAt = date
        }

        current.lastMatchedAt = date
        return current
    }
}
