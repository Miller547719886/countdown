import Foundation

public enum DeadlineReminderMode: String, Codable, Hashable, Sendable {
    case relative
    case custom
}

public struct DeadlineReminder: Codable, Equatable, Sendable {
    public var mode: DeadlineReminderMode
    public var daysBeforeDeadline: Int
    public var hour: Int
    public var minute: Int
    public var customDate: Date?

    private enum CodingKeys: String, CodingKey {
        case mode
        case daysBeforeDeadline
        case hour
        case minute
        case customDate
    }

    public init(
        mode: DeadlineReminderMode = .relative,
        daysBeforeDeadline: Int = 1,
        hour: Int = 8,
        minute: Int = 0,
        customDate: Date? = nil
    ) {
        self.mode = mode
        self.daysBeforeDeadline = min(max(daysBeforeDeadline, 1), ReminderPlanner.maximumDaysBeforeDeadline)
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
        self.customDate = customDate
    }

    public static func relative(
        daysBeforeDeadline: Int,
        hour: Int = 8,
        minute: Int = 0
    ) -> Self {
        Self(
            mode: .relative,
            daysBeforeDeadline: daysBeforeDeadline,
            hour: hour,
            minute: minute
        )
    }

    public static func custom(date: Date) -> Self {
        let time = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Self(
            mode: .custom,
            daysBeforeDeadline: 1,
            hour: time.hour ?? 8,
            minute: time.minute ?? 0,
            customDate: date
        )
    }

    public func fireDate(
        relativeTo deadline: Date,
        calendar: Calendar = .current
    ) -> Date? {
        if mode == .custom {
            return customDate
        }

        guard let reminderDay = calendar.date(
            byAdding: .day,
            value: -daysBeforeDeadline,
            to: deadline
        ) else {
            return nil
        }
        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: reminderDay
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            mode: try container.decode(DeadlineReminderMode.self, forKey: .mode),
            daysBeforeDeadline: try container.decode(Int.self, forKey: .daysBeforeDeadline),
            hour: try container.decode(Int.self, forKey: .hour),
            minute: try container.decode(Int.self, forKey: .minute),
            customDate: try container.decodeIfPresent(Date.self, forKey: .customDate)
        )
    }
}

public enum ReminderPlanner {
    public static let maximumReminderCount = 30
    public static let maximumDaysBeforeDeadline = 365

    public static func defaultReminders(count: Int = 1) -> [DeadlineReminder] {
        let safeCount = min(max(count, 0), maximumReminderCount)
        return (0..<safeCount).map { index in
            .relative(daysBeforeDeadline: safeCount - index)
        }
    }

    public static func resize(
        _ reminders: [DeadlineReminder],
        to count: Int
    ) -> [DeadlineReminder] {
        let safeCount = min(max(count, 0), maximumReminderCount)
        return (0..<safeCount).map { index in
            let defaultDays = safeCount - index
            guard reminders.indices.contains(index) else {
                return .relative(daysBeforeDeadline: defaultDays)
            }

            var reminder = reminders[index]
            if reminder.mode == .relative {
                reminder.daysBeforeDeadline = defaultDays
            }
            return reminder
        }
    }
}
