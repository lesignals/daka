import Foundation
import Testing

@testable import DakaCore

struct AppConfigTests {
    @Test func oldConfigWithoutTargetDurationUsesDefaultTenAndHalfHours() throws {
        let json = """
            {
              "evaluationIntervalSeconds": 60,
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
            """

        let config = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))

        #expect(config.targetDurationSeconds == 10.5 * 60 * 60)
    }

    @Test func bluetoothSignalConditionRoundTripsThroughJSON() throws {
        let condition = TimerCondition.bluetoothSignal(
            identifier: "D456C92A-20EF-4BD7-A4D6-6D21AC6B6448",
            name: "Office Beacon",
            minimumRSSI: -65
        )

        let data = try JSONEncoder().encode(condition)
        let decoded = try JSONDecoder().decode(TimerCondition.self, from: data)

        #expect(decoded == condition)
    }
}
