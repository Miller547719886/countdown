import Foundation
import Tyme4Swift

public enum ChineseCalendarHolidayKind: String, Equatable, Sendable {
    case offDay
    case makeUpWorkday

    public var badge: String {
        switch self {
        case .offDay: "休"
        case .makeUpWorkday: "班"
        }
    }

    public var accessibilityLabel: String {
        switch self {
        case .offDay: "休息日"
        case .makeUpWorkday: "调休上班日"
        }
    }
}

public struct ChineseCalendarHoliday: Equatable, Sendable {
    public let name: String
    public let kind: ChineseCalendarHolidayKind

    public init(name: String, kind: ChineseCalendarHolidayKind) {
        self.name = name
        self.kind = kind
    }
}

public struct ChineseCalendarDayInfo: Equatable, Sendable {
    public let holiday: ChineseCalendarHoliday?
    public let solarTerm: String?

    public init(
        holiday: ChineseCalendarHoliday? = nil,
        solarTerm: String? = nil
    ) {
        self.holiday = holiday
        self.solarTerm = solarTerm
    }
}

public enum ChineseCalendarData {
    private static let supportedSolarTermYears = 1900...2100
    private static let holidayIndex = loadHolidayIndex()

    public static func info(
        for date: Date,
        calendar inputCalendar: Calendar = .current
    ) -> ChineseCalendarDayInfo {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = inputCalendar.timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return ChineseCalendarDayInfo()
        }

        let dateKey = String(format: "%04d-%02d-%02d", year, month, day)
        let solarTerm = solarTerm(year: year, month: month, day: day)
        return ChineseCalendarDayInfo(
            holiday: holidayIndex[dateKey],
            solarTerm: solarTerm
        )
    }

    private static func solarTerm(year: Int, month: Int, day: Int) -> String? {
        guard supportedSolarTermYears.contains(year),
              let solarDay = try? SolarDay.fromYmd(year, month, day) else {
            return nil
        }

        let termDay = solarDay.termDay
        return termDay.dayIndex == 0 ? termDay.solarTerm.getName() : nil
    }

    private static func loadHolidayIndex() -> [String: ChineseCalendarHoliday] {
        let urls = Bundle.module.urls(
            forResourcesWithExtension: "json",
            subdirectory: "Holidays"
        ) ?? []
        let documents = urls.compactMap { url -> HolidayDocument? in
            guard let data = try? Data(contentsOf: url),
                  let document = try? JSONDecoder().decode(HolidayDocument.self, from: data),
                  !document.days.isEmpty else {
                return nil
            }
            return document
        }
        .sorted { $0.year < $1.year }

        var index: [String: ChineseCalendarHoliday] = [:]
        for document in documents {
            for day in document.days where isValidDateKey(day.date) {
                let kind: ChineseCalendarHolidayKind = day.isOffDay ? .offDay : .makeUpWorkday
                index[day.date] = ChineseCalendarHoliday(
                    name: displayName(from: day.name),
                    kind: kind
                )
            }
        }
        return index
    }

    private static func displayName(from source: String) -> String {
        let parts = source.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return source }
        let localizedName = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        return localizedName.isEmpty ? source : localizedName
    }

    private static func isValidDateKey(_ value: String) -> Bool {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty }),
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1900...2101).contains(year),
              (1...12).contains(month),
              (1...31).contains(day) else {
            return false
        }
        return value.utf8.count == 10
    }
}

private struct HolidayDocument: Decodable {
    let year: Int
    let days: [HolidayDay]
}

private struct HolidayDay: Decodable {
    let name: String
    let date: String
    let isOffDay: Bool
}
