import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("设置")
                    .font(TypeScale.title)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(QuietButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 17)

            Rule(color: Palette.ruleLight)

            VStack(alignment: .leading, spacing: 22) {
                settingRow(
                    title: "读取其他应用中的选中文字",
                    detail: coordinator.accessibilityTrusted
                        ? "已允许。按 ⌘ 1 时会直接读取当前选区。"
                        : "在系统设置中允许“截点”使用辅助功能。未授权时仍可手动记一项。",
                    status: coordinator.accessibilityTrusted ? "已开启" : "未开启",
                    statusColor: coordinator.accessibilityTrusted ? Palette.olive : Palette.vermilion,
                    actionLabel: coordinator.accessibilityTrusted ? nil : "打开系统设置",
                    action: coordinator.accessibilityTrusted ? nil : { coordinator.openAccessibilitySettings() }
                )

                Rule(color: Palette.ruleLight)

                settingRow(
                    title: "期限提醒",
                    detail: notificationDetail,
                    status: notificationStatusLabel,
                    statusColor: coordinator.notificationStatus == .authorized ? Palette.olive : Palette.vermilion,
                    actionLabel: coordinator.notificationStatus == .denied ? nil : "允许通知",
                    action: coordinator.notificationStatus == .denied ? nil : { coordinator.requestNotificationPermission() }
                )

                Rule(color: Palette.ruleLight)

                settingRow(
                    title: "全局快捷键",
                    detail: coordinator.hotKeyRegistered
                        ? "在任意应用选中文字后按 ⌘ 1，即可打开捕获面板。"
                        : "快捷键尚未就绪。可以重试注册，并查看错误码。",
                    status: coordinator.hotKeyStatus,
                    statusColor: coordinator.hotKeyRegistered ? Palette.olive : Palette.vermilion,
                    actionLabel: coordinator.hotKeyRegistered ? nil : "重试注册",
                    action: coordinator.hotKeyRegistered ? nil : { coordinator.retryGlobalHotKeyRegistration() }
                )

                Rule(color: Palette.ruleLight)

                VStack(alignment: .leading, spacing: 7) {
                    Text("数据")
                        .font(TypeScale.section)
                        .foregroundStyle(Palette.ink)
                    Text("事项只保存在这台 Mac 的本地文件中，不会上传或同步。")
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.inkMuted)
                }
            }
            .padding(24)
        }
        .frame(width: 540)
        .background(Palette.paperRaised)
        .task {
            await coordinator.refreshNotificationStatus()
        }
    }

    private func settingRow(
        title: String,
        detail: String,
        status: String,
        statusColor: Color,
        actionLabel: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(TypeScale.section)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(status)
                    .font(TypeScale.small)
                    .foregroundStyle(statusColor)
            }
            Text(detail)
                .font(TypeScale.small)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var notificationStatusLabel: String {
        switch coordinator.notificationStatus {
        case .authorized, .provisional, .ephemeral: "已开启"
        case .denied: "已拒绝"
        case .notDetermined: "未请求"
        @unknown default: "未知"
        }
    }

    private var notificationDetail: String {
        switch coordinator.notificationStatus {
        case .authorized, .provisional, .ephemeral:
            "到达截止时间时，系统会显示一条本地通知。"
        case .denied:
            "通知权限已被拒绝。请在系统设置中允许“截点”发送通知。"
        case .notDetermined:
            "允许后，到达截止时间时会收到一条本地通知。"
        @unknown default:
            "无法读取通知权限状态。"
        }
    }
}
