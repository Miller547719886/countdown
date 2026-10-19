import AppKit
import SwiftUI

struct AccessibilityPermissionGuideView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var didCheckAgain = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 18)

            Rule(color: Palette.ruleLight)

            if coordinator.accessibilityTrusted {
                authorizedContent
                    .padding(.top, 24)
            } else {
                instructions
                    .padding(.top, 20)
            }

            Spacer(minLength: 16)
            footer
        }
        .padding(24)
        .frame(width: 800, height: 660, alignment: .topLeading)
        .background(Palette.paperRaised)
        .preferredColorScheme(.light)
        .onExitCommand { coordinator.dismissAccessibilityGuide() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                Rectangle()
                    .fill(Palette.vermilion)
                    .frame(width: 30, height: 30)
                Text("截")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.paperRaised)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(coordinator.accessibilityTrusted ? "选区捕获已就绪" : "开启选区捕获")
                    .font(TypeScale.title)
                    .foregroundStyle(Palette.ink)
                Text(coordinator.accessibilityTrusted
                     ? "现在可以在其他应用选中文字，再按 ⌘ 1 创建事项。"
                     : "允许截点在你按下 ⌘ 1 时读取其他应用中选中的文字。")
                    .font(TypeScale.body)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 20) {
                GuideScreenshotStep(
                    number: "1",
                    title: "进入辅助功能",
                    detail: "在“隐私与安全性”中找到并进入“辅助功能”。",
                    image: AccessibilityGuideImages.privacySecurity,
                    imageDescription: "系统设置的隐私与安全性页面，其中列出辅助功能。"
                )

                Rectangle()
                    .fill(Palette.ruleLight)
                    .frame(width: 1)
                    .padding(.top, 8)

                GuideScreenshotStep(
                    number: "2",
                    title: "打开“截点”右侧的开关",
                    detail: "如果列表中没有“截点”，点击列表下方的 +，再选择“截点.app”。",
                    image: AccessibilityGuideImages.permissionToggle,
                    imageDescription: "系统设置辅助功能列表中的截点开关。"
                )
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(Palette.vermilion)
                    .frame(width: 7, height: 7)
                Text("尚未检测到授权")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkMuted)
            }

            if didCheckAgain && !coordinator.accessibilityTrusted {
                Text("仍未检测到授权。先退出并重新打开截点；若刚更新或重建过，请移除列表中的旧“截点”，再点“+”添加当前的“截点.app”并打开开关。")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if coordinator.accessibilitySettingsOpenFailed {
                Text("无法自动打开系统设置。请手动进入：系统设置 → 隐私与安全性 → 辅助功能。")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.vermilion)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var authorizedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Palette.olive)
                Text("辅助功能已开启")
                    .font(TypeScale.section)
                    .foregroundStyle(Palette.ink)
            }

            Text("选中一句话并按 ⌘ 1，截点就会把原文带进事项面板。")
                .font(TypeScale.body)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Rule(color: Palette.ruleLight)

            Text("此权限用于读取你主动触发时的当前选区；事项仍只保存在这台 Mac 上。")
                .font(TypeScale.small)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if coordinator.accessibilityTrusted {
                Button("完成") {
                    coordinator.dismissAccessibilityGuide()
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            } else {
                Button("稍后设置") {
                    coordinator.dismissAccessibilityGuide()
                }
                .buttonStyle(QuietButtonStyle())
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("重新检查") {
                    didCheckAgain = true
                    coordinator.refreshAccessibilityPermission()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("打开系统设置") {
                    coordinator.openAccessibilitySettings()
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

private struct GuideScreenshotStep: View {
    let number: String
    let title: String
    let detail: String
    let image: NSImage?
    let imageDescription: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(number)
                    .font(TypeScale.mono)
                    .foregroundStyle(Palette.vermilion)
                    .frame(width: 15, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(TypeScale.section)
                        .foregroundStyle(Palette.ink)
                    Text(detail)
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(minHeight: 56, alignment: .topLeading)

            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Rectangle()
                        .fill(Palette.paper)
                        .overlay {
                            Text("未能载入设置截图")
                                .font(TypeScale.small)
                                .foregroundStyle(Palette.inkMuted)
                        }
                }
            }
                .aspectRatio(1294.0 / 1096.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Palette.paper)
                .overlay(Rectangle().stroke(Palette.ruleLight, lineWidth: 1))
                .accessibilityLabel(imageDescription)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private enum AccessibilityGuideImages {
    static let privacySecurity = load("accessibility-privacy-security")
    static let permissionToggle = load("accessibility-permission-toggle")

    private static func load(_ resourceName: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
