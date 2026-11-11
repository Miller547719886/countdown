import Foundation

public struct DeadlineDateChoice: Identifiable, Equatable, Sendable {
    public let label: String
    public let date: Date
    public let weekOffset: Int
    public let weekdayIndex: Int

    public var id: String { "\(weekOffset)-\(weekdayIndex)" }

    public init(label: String, date: Date, weekOffset: Int, weekdayIndex: Int) {
        self.label = label
        self.date = date
        self.weekOffset = weekOffset
        self.weekdayIndex = weekdayIndex
    }
}

public enum DeadlinePlanner {
    private static let weekdayNames = ["一", "二", "三", "四", "五", "六", "日"]

    public static func defaultDeadline(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        let todayAtEight = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) ?? today
        guard todayAtEight <= now else { return todayAtEight }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return calendar.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    public static func weekDateChoices(
        now: Date = Date(),
        calendar inputCalendar: Calendar = .current
    ) -> [DeadlineDateChoice] {
        let calendar = inputCalendar
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today

        return (0...1).flatMap { weekOffset in
            (0...6).compactMap { weekdayIndex in
                guard let date = calendar.date(
                    byAdding: .day,
                    value: weekOffset * 7 + weekdayIndex,
                    to: monday
                ) else { return nil }
                let prefix = weekOffset == 0 ? "本周" : "下周"
                return DeadlineDateChoice(
                    label: "\(prefix)\(weekdayNames[weekdayIndex])",
                    date: date,
                    weekOffset: weekOffset,
                    weekdayIndex: weekdayIndex
                )
            }
        }
    }

    public static func clampedSeconds(_ value: Int) -> Int {
        min(max(value, 0), 59)
    }

    public static func isBeforeToday(
        _ date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        calendar.startOfDay(for: date) < calendar.startOfDay(for: now)
    }

    public static func dateLabel(
        _ date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let label = DeadlineText.date(date, calendar: calendar)
        return calendar.isDate(date, inSameDayAs: now) ? "\(label) · 今天" : label
    }
}
