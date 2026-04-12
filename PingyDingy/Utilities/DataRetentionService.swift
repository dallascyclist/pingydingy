import Foundation

struct DataRetentionService {
    static let reminderThresholdDays: Int = 90

    static func shouldShowReminder(oldestDataDate: Date?) -> Bool {
        guard let oldest = oldestDataDate else { return false }
        let thresholdDate = Calendar.current.date(
            byAdding: .day, value: -reminderThresholdDays, to: Date()
        )!
        return oldest < thresholdDate
    }

    static func dataAgeDescription(oldestDate: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: oldestDate, to: Date()).day ?? 0
        if days < 1 { return "less than a day" }
        if days == 1 { return "1 day" }
        if days < 30 { return "\(days) days" }
        let months = days / 30
        return months == 1 ? "about 1 month" : "about \(months) months"
    }
}
