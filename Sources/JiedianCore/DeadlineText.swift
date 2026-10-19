import Foundation

public enum DeadlineText {
    public static let chineseLocale = Locale(identifier: "zh_CN")

    public static func date(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = chineseLocale
        formatter.calendar = calendar
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    public static func weekday(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = chineseLocale
        formatter.calendar = calendar
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    public static func time(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = chineseLocale
        formatter.calendar = calendar
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    public static func full(_ date: Date, calendar: Calendar = .current) -> String {
        "\(self.date(date, calendar: calendar)) \(weekday(date, calendar: calendar)) \(time(date, calendar: calendar))"
    }

    public static func relative(to deadline: Date, from now: Date = Date()) -> String {
        let interval = deadline.timeIntervalSince(now)
        let isFuture = interval >= 0
        let seconds = abs(interval)

        let phrase: String
        if seconds < 60 {
            phrase = "不到 1 分钟"
        } else if seconds < 3_600 {
            phrase = "\(Int(seconds / 60)) 分钟"
        } else if seconds < 86_400 {
            let hours = Int(seconds / 3_600)
            let minutes = Int(seconds.truncatingRemainder(dividingBy: 3_600) / 60)
            phrase = minutes == 0 ? "\(hours) 小时" : "\(hours) 小时 \(minutes) 分"
        } else {
            let days = Int(seconds / 86_400)
            let hours = Int(seconds.truncatingRemainder(dividingBy: 86_400) / 3_600)
            phrase = hours == 0 ? "\(days) 天" : "\(days) 天 \(hours) 小时"
        }

        return isFuture ? "还剩 \(phrase)" : "已逾期 \(phrase)"
    }

    public static func relativeShort(to deadline: Date, from now: Date = Date()) -> String {
        let interval = deadline.timeIntervalSince(now)
        let isFuture = interval >= 0
        let seconds = abs(interval)

        let phrase: String
        if seconds < 60 {
            phrase = "<1 分钟"
        } else if seconds < 3_600 {
            phrase = "\(Int(seconds / 60)) 分钟"
        } else if seconds < 86_400 {
            phrase = "\(Int(seconds / 3_600)) 小时"
        } else {
            phrase = "\(Int(seconds / 86_400)) 天"
        }

        return isFuture ? "剩 \(phrase)" : "逾期 \(phrase)"
    }
}
