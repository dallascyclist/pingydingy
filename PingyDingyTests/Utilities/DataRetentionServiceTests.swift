import Testing
import Foundation
@testable import PingyDingy

@Test func shouldShowReminderWhenOlderThan90Days() {
    let oldDate = Calendar.current.date(byAdding: .day, value: -91, to: Date())!
    #expect(DataRetentionService.shouldShowReminder(oldestDataDate: oldDate) == true)
}

@Test func shouldNotShowReminderWhenNewerThan90Days() {
    let recentDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    #expect(DataRetentionService.shouldShowReminder(oldestDataDate: recentDate) == false)
}

@Test func shouldNotShowReminderWhenNoData() {
    #expect(DataRetentionService.shouldShowReminder(oldestDataDate: nil) == false)
}

@Test func dataAgeDescriptionDays() {
    let date = Calendar.current.date(byAdding: .day, value: -15, to: Date())!
    #expect(DataRetentionService.dataAgeDescription(oldestDate: date) == "15 days")
}

@Test func dataAgeDescriptionMonths() {
    let date = Calendar.current.date(byAdding: .day, value: -95, to: Date())!
    #expect(DataRetentionService.dataAgeDescription(oldestDate: date) == "about 3 months")
}
