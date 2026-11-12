import EventKit
import JiedianCore
import SwiftUI

struct CalendarSyncSettingsView: View {
    @EnvironmentObject private var calendarSync: CalendarSyncService
    @State private var showUnlinkConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("Apple 日历同步")
                    .font(TypeScale.section)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(statusLabel)
                    .font(TypeScale.small)
                    .foregroundStyle(statusColor)
            }

            Text(detailText)
                .font(TypeScale.small)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            if calendarSync.accessStatus == .fullAccess {
                calendarPicker
                Text("只有 iCloud 日历会在 Mac、iPhone、iPad 间同步；本地日历只适合测试。")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button("同步现有事项") {
                        calendarSync.syncExistingItems()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!calendarSync.isEnabled || calendarSync.selectedCalendarIdentifier == nil)

                    Button("重试同步") {
                        calendarSync.retrySync()
                    }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(calendarSync.isSyncing)
                }

                Toggle(
                    CalendarSyncSettingsCopy.allowSyncToAppleCalendar,
                    isOn: Binding(
                        get: { calendarSync.isEnabled },
                        set: { calendarSync.setEnabled($0) }
                    )
                )
                .toggleStyle(.switch)
                .font(TypeScale.small)
                .foregroundStyle(Palette.ink)
                .disabled(!calendarSync.isEnabled && calendarSync.selectedCalendarIdentifier == nil)

                Button("解除所有关联…") {
                    showUnlinkConfirmation = true
                }
                .buttonStyle(QuietButtonStyle())

                if calendarSync.pendingCount > 0 {
                    Text(CalendarSyncStatus.pendingSummary(calendarSync.pendingCount))
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.vermilion)
                }
            } else if calendarSync.accessStatus == .notDetermined {
                Button("允许访问日历") {
                    Task { await calendarSync.requestAccess() }
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Button("打开系统设置") {
                    calendarSync.openCalendarSettings()
                }
                .buttonStyle(SecondaryButtonStyle())
                if calendarSync.settingsOpenFailed {
                    Text("无法自动打开系统设置。请手动进入：隐私与安全性 → 日历。")
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.vermilion)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let lastError = calendarSync.lastError {
                Text(lastError)
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.vermilion)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let lastSyncAt = calendarSync.lastSyncAt {
                HStack(spacing: 0) {
                    Text("最近同步：")
                    Text(lastSyncAt.formatted(date: .abbreviated, time: .shortened))
                }
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkFaint)
            }
        }
        .alert("解除日历关联？", isPresented: $showUnlinkConfirmation) {
            Button("解除并保留日历事件") {
                calendarSync.unlinkAll(deleteEvents: false)
            }
            Button("解除并删除日历事件", role: .destructive) {
                calendarSync.unlinkAll(deleteEvents: true)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("截点事项会继续保留。删除日历事件只影响带有截点标记的事件。")
        }
    }

    private var calendarPicker: some View {
        HStack(spacing: 10) {
            Text("同步日历")
                .font(TypeScale.small)
                .foregroundStyle(Palette.inkMuted)
            Menu {
                ForEach(calendarSync.availableCalendars) { calendar in
                    Button {
                        calendarSync.selectCalendar(identifier: calendar.id)
                    } label: {
                        HStack {
                            Text(calendar.displayName)
                            if calendar.isCloudBacked {
                                Text("iCloud")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedCalendarName)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            Spacer(minLength: 0)
        }
    }

    private var selectedCalendarName: String {
        guard let identifier = calendarSync.selectedCalendarIdentifier,
              let calendar = calendarSync.availableCalendars.first(where: { $0.id == identifier }) else {
            return "选择一个日历"
        }
        return calendar.displayName
    }

    private var statusLabel: String {
        if calendarSync.accessStatus == .fullAccess {
            return calendarSync.syncStateText
        }
        switch calendarSync.accessStatus {
        case .notDetermined: return "未授权"
        case .denied: return "已拒绝"
        case .restricted: return "受限制"
        default: return "未开启"
        }
    }

    private var statusColor: Color {
        if calendarSync.accessStatus == .fullAccess,
           calendarSync.lastError == nil,
           calendarSync.pendingCount == 0 {
            return Palette.olive
        }
        return Palette.vermilion
    }

    private var detailText: String {
        switch calendarSync.accessStatus {
        case .fullAccess:
            return calendarSync.isEnabled
                ? "带有截点标记的事件会和事项双向更新。普通日历事件不会被导入。"
                : "选择一个日历后，打开“允许同步到 Apple Calendar”；首次同步现有事项需要单独点击。"
        case .notDetermined:
            return "允许后，截点可以读取和更新关联的 Apple 日历事件。"
        case .denied:
            return "日历权限已被拒绝。请在系统设置中允许“截点”访问日历。"
        default:
            return "当前系统限制了日历访问。"
        }
    }
}
