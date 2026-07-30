import Foundation
import Testing
@testable import DakaCore

struct ValidationTests {
    @Test func normalizesValidTimesAndRejectsInvalidTimes() {
        #expect(DakaInputValidator.normalizedTime("9:05") == "09:05")
        #expect(DakaInputValidator.normalizedTime("23:59") == "23:59")
        #expect(DakaInputValidator.normalizedTime("24:00") == nil)
        #expect(DakaInputValidator.normalizedTime("09:60") == nil)
        #expect(DakaInputValidator.normalizedTime("9:5") == nil)
        #expect(DakaInputValidator.normalizedTime("9") == nil)
    }

    @Test func validatesNumericConfigurationInsteadOfSilentlyClamping() {
        #expect(DakaInputValidator.evaluationInterval("10") == 10)
        #expect(DakaInputValidator.evaluationInterval("9") == nil)
        #expect(DakaInputValidator.evaluationInterval("60.5") == nil)
        #expect(DakaInputValidator.positiveNumber("10.5", range: 0.25...24) == 10.5)
        #expect(DakaInputValidator.positiveNumber("0", range: 0.25...24) == nil)
        #expect(DakaInputValidator.positiveNumber("nan", range: 0.25...24) == nil)
    }

    @Test func ssidMatchingIsExact() {
        #expect(WiFiSSIDMatcher.matches(current: "Office WiFi", expected: "Office WiFi"))
        #expect(!WiFiSSIDMatcher.matches(current: "office wifi", expected: "Office WiFi"))
        #expect(!WiFiSSIDMatcher.matches(current: "Office WiFi ", expected: "Office WiFi"))
        #expect(!WiFiSSIDMatcher.matches(current: nil, expected: "Office WiFi"))
    }

    @Test func bluetoothSignalRequiresRecentRSSIAtOrAboveThreshold() {
        #expect(BluetoothSignalMatcher.matches(currentRSSI: -60, minimumRSSI: -65))
        #expect(BluetoothSignalMatcher.matches(currentRSSI: -65, minimumRSSI: -65))
        #expect(!BluetoothSignalMatcher.matches(currentRSSI: -66, minimumRSSI: -65))
        #expect(!BluetoothSignalMatcher.matches(currentRSSI: nil, minimumRSSI: -65))
    }

    @Test func bluetoothRSSIThresholdAcceptsPracticalRangeOnly() {
        #expect(DakaInputValidator.bluetoothRSSI("-65") == -65)
        #expect(DakaInputValidator.bluetoothRSSI("-100") == -100)
        #expect(DakaInputValidator.bluetoothRSSI("-20") == -20)
        #expect(DakaInputValidator.bluetoothRSSI("-101") == nil)
        #expect(DakaInputValidator.bluetoothRSSI("-19") == nil)
        #expect(DakaInputValidator.bluetoothRSSI("strong") == nil)
    }

    @Test func editedTimesStayOnRecordDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let firstInput = try #require(makeDate("2026-07-28 09:15", calendar: calendar))
        let lastInput = try #require(makeDate("2026-07-28 18:45", calendar: calendar))
        let record = DailyRecord(date: "2026-05-20")

        let updated = try #require(DailyRecordTimeEditor.updating(
            record,
            firstTime: firstInput,
            lastTime: lastInput,
            calendar: calendar
        ))

        #expect(dateTime(updated.firstMatchedAt, calendar: calendar) == "2026-05-20 09:15")
        #expect(dateTime(updated.lastMatchedAt, calendar: calendar) == "2026-05-20 18:45")
    }

    @Test func editedTimesRejectLastBeforeFirst() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let first = try #require(makeDate("2026-07-28 18:00", calendar: calendar))
        let last = try #require(makeDate("2026-07-28 09:00", calendar: calendar))

        #expect(DailyRecordTimeEditor.updating(
            DailyRecord(date: "2026-05-20"),
            firstTime: first,
            lastTime: last,
            calendar: calendar
        ) == nil)
    }

    @Test func systemProfilerParserPreservesSSIDCaseSpacesAndColons() {
        let output = """
              Current Network Information:
                Office:5G:
                  PHY Mode: 802.11ax
              Other Local Wi-Fi Networks:
                Guest WiFi:
                  Channel: 36
                Office WiFi :
                  Channel: 149
            """

        let snapshot = WiFiProfilerParser.parse(output)

        #expect(snapshot.currentSSID == "Office:5G")
        #expect(snapshot.visibleSSIDs == ["Guest WiFi", "Office WiFi ", "Office:5G"])
    }

    private func makeDate(_ value: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: value)
    }

    private func dateTime(_ date: Date?, calendar: Calendar) -> String? {
        guard let date else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
