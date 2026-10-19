import AppKit
import SwiftUI
import JiedianCore

@main
struct JiedianApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ItemStore()
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindowView()
                .environmentObject(store)
                .environmentObject(coordinator)
                .frame(minWidth: 860, minHeight: 620)
                .preferredColorScheme(.light)
                .onAppear {
                    coordinator.configure(store: store)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1120, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("截取选中文字") {
                    coordinator.beginCapture()
                }
            }
            CommandGroup(after: .appInfo) {
                Button("检查辅助功能权限…") {
                    coordinator.openAccessibilitySettings()
                }
            }
        }

        MenuBarExtra("截点", systemImage: "calendar.badge.clock") {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(coordinator)
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
}
