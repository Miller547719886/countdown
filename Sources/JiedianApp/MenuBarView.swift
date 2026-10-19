import SwiftUI
import JiedianCore

struct MenuBarView: View {
    @EnvironmentObject private var store: ItemStore
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        Button("截取选中文字  ⌘ 1") {
            coordinator.beginCapture()
        }
        Button("手动记一项") {
            coordinator.beginManualCapture()
        }
        Divider()
        if let nearest = store.nearestItem {
            Text("最近：\(DeadlineText.date(nearest.deadline)) \(DeadlineText.time(nearest.deadline))")
            Text(String(nearest.text.prefix(28)))
            Divider()
        }
        Text("期限簿 · \(store.activeItems.count) 项待处理")
        Button("打开截点") {
            coordinator.showMainWindow()
        }
        Divider()
        Button("退出截点") {
            NSApp.terminate(nil)
        }
    }
}
