import Foundation

public enum DeadlineReminderMode: String, Codable, Hashable, Sendable {
    case relative
    case custom
}

public enum DeadlineReminderUnit: String, Codable, Hashable, Sendable {
    case days
    case hours
}

public struct DeadlineReminder: Codable, Equatable, Sendable {
    public var mode: DeadlineReminderMode
    public var daysBeforeDeadline: Int
    public var hoursBeforeDeadline: Int?
    public var hour: Int
    public var minute: Int
    public var customDate: Date?

    private enum CodingKeys: String, CodingKey {
        case mode
        case daysBeforeDeadline
        case hoursBeforeDeadline
        case hour
        case minute
        case customDate
    }

    public init(
        mode: DeadlineReminderMode = .relative,
        daysBeforeDeadline: Int = 1,
        hour: Int = 8,
        minute: Int = 0,
        customDate: Date? = nil,
        hoursBeforeDeadline: Int? = nil
    ) {
        self.mode = mode
        self.daysBeforeDeadline = min(max(daysBeforeDeadline, 1), ReminderPlanner.maximumDaysBeforeDeadline)
        self.hoursBeforeDeadline = hoursBeforeDeadline.map {
            min(max($0, 1), ReminderPlanner.maximumHoursBeforeDeadline)
        }
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

    public static func relative(hoursBeforeDeadline: Int) -> Self {
        Self(
            mode: .relative,
            daysBeforeDeadline: 1,
            hoursBeforeDeadline: hoursBeforeDeadline
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

    public var relativeUnit: DeadlineReminderUnit {
        hoursBeforeDeadline == nil ? .days : .hours
    }

    public var relativeValue: Int {
        get { hoursBeforeDeadline ?? daysBeforeDeadline }
        set {
            switch relativeUnit {
            case .days:
                daysBeforeDeadline = min(
                    max(newValue, 1),
                    ReminderPlanner.maximumDaysBeforeDeadline
                )
            case .hours:
                hoursBeforeDeadline = min(
                    max(newValue, 1),
                    ReminderPlanner.maximumHoursBeforeDeadline
                )
            }
        }
    }

    public func fireDate(
        relativeTo deadline: Date,
        calendar: Calendar = .current
    ) -> Date? {
        if mode == .custom {
            return customDate
        }

        if let hoursBeforeDeadline {
            return calendar.date(byAdding: .hour, value: -hoursBeforeDeadline, to: deadline)
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
            customDate: try container.decodeIfPresent(Date.self, forKey: .customDate),
            hoursBeforeDeadline: try container.decodeIfPresent(Int.self, forKey: .hoursBeforeDeadline)
        )
    }
}

public enum ReminderPlanner {
    public static let maximumReminderCount = 30
    public static let maximumDaysBeforeDeadline = 365
    public static let maximumHoursBeforeDeadline = maximumDaysBeforeDeadline * 24

    public static func defaultReminders(
        count: Int = 1,
        unit: DeadlineReminderUnit = .days
    ) -> [DeadlineReminder] {
        let safeCount = min(max(count, 0), maximumReminderCount)
        return (0..<safeCount).map { index in
            let value = safeCount - index
            switch unit {
            case .days:
                return .relative(daysBeforeDeadline: value)
            case .hours:
                return .relative(hoursBeforeDeadline: value)
            }
        }
    }

    public static func defaultRelativeUnit(
        for deadline: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DeadlineReminderUnit {
        calendar.isDate(deadline, inSameDayAs: now) ? .hours : .days
    }

    public static func defaultReminders(
        for deadline: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DeadlineReminder] {
        defaultReminders(
            unit: defaultRelativeUnit(for: deadline, now: now, calendar: calendar)
        ).filter { reminder in
            guard let fireDate = reminder.fireDate(relativeTo: deadline, calendar: calendar) else {
                return false
            }
            return fireDate > now && fireDate < deadline
        }
    }

    public static func resize(
        _ reminders: [DeadlineReminder],
        to count: Int,
        unit: DeadlineReminderUnit = .days
    ) -> [DeadlineReminder] {
        let safeCount = min(max(count, 0), maximumReminderCount)
        return (0..<safeCount).map { index in
            let defaultValue = safeCount - index
            guard reminders.indices.contains(index) else {
                switch unit {
                case .days:
                    return .relative(daysBeforeDeadline: defaultValue)
                case .hours:
                    return .relative(hoursBeforeDeadline: defaultValue)
                }
            }

            var reminder = reminders[index]
            if reminder.mode == .relative {
                reminder.relativeValue = defaultValue
            }
            return reminder
        }
    }

    public static func hasCustomReminderAtOrAfterDeadline(
        _ reminders: [DeadlineReminder],
        deadline: Date
    ) -> Bool {
        reminders.contains { reminder in
            guard reminder.mode == .custom else { return false }
            guard let customDate = reminder.customDate else { return true }
            return customDate >= deadline
        }
    }
}
