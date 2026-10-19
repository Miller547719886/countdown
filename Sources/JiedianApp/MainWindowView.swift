import SwiftUI
import JiedianCore

enum AppSection: String, CaseIterable, Identifiable {
    case active = "期限簿"
    case completed = "已完成"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .active: "calendar"
        case .completed: "checkmark"
        }
    }
}

struct MainWindowView: View {
    @EnvironmentObject private var store: ItemStore
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var section: AppSection = .active
    @State private var now = Date()
    @State private var editingItem: CaptureItem?
    @State private var showSettings = false
    @State private var pendingDelete: CaptureItem?

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Rule(color: Palette.rule)
                HStack(spacing: 0) {
                    sidebar
                    Rectangle().fill(Palette.ruleLight).frame(width: 1)
                    content
                }
            }
        }
        .onReceive(clock) { now = $0 }
        .sheet(item: $editingItem) { item in
            EditItemSheet(item: item) { updated in
                store.update(updated)
                editingItem = nil
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(coordinator)
        }
        .alert("删除这项？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        ), presenting: pendingDelete) { item in
            Button("删除", role: .destructive) {
                store.delete(item.id)
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: { item in
            Text("“\(item.text)”将从期限簿中移除，无法撤销。")
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 9) {
                ZStack {
                    Rectangle().fill(Palette.vermilion).frame(width: 23, height: 23)
                    Text("截")
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundStyle(Palette.paperRaised)
                }
                Text("截点")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.ink)
                Text("把一句话，交给一个期限")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkFaint)
                    .padding(.leading, 3)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle()
                    .fill(coordinator.accessibilityTrusted ? Palette.olive : Palette.vermilion)
                    .frame(width: 6, height: 6)
                Text(coordinator.accessibilityTrusted ? "选区捕获已就绪" : "需要辅助功能权限")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkMuted)
            }
            .help(coordinator.accessibilityTrusted ? "可以从其他应用读取当前选中文字" : "授予辅助功能权限后可直接读取选中文字")

            Button {
                coordinator.beginCapture()
            } label: {
                HStack(spacing: 8) {
                    Text("截取选中文字")
                    ShortcutKey(label: "⌘ 1")
                }
            }
            .buttonStyle(SecondaryButtonStyle())

            Button {
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(QuietButtonStyle())
            .help("设置")
        }
        .padding(.horizontal, 22)
        .frame(height: 64)
        .background(Palette.paperRaised)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("今天")
                .font(TypeScale.label)
                .foregroundStyle(Palette.inkFaint)
                .padding(.horizontal, 18)
                .padding(.top, 24)
                .padding(.bottom, 6)
            Text(DeadlineText.date(now))
                .font(.system(size: 25, weight: .medium, design: .serif))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 18)
            Text(DeadlineText.weekday(now))
                .font(TypeScale.small)
                .foregroundStyle(Palette.inkMuted)
                .padding(.horizontal, 18)
                .padding(.top, 2)

            Rule(color: Palette.ruleLight).padding(.horizontal, 18).padding(.top, 20)

            VStack(spacing: 2) {
                ForEach(AppSection.allCases) { item in
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) { section = item }
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 17)
                            Text(item.rawValue)
                                .font(.system(size: 13, weight: section == item ? .semibold : .regular))
                            Spacer()
                            Text("\(item == .active ? store.activeItems.count : store.completedItems.count)")
                                .font(TypeScale.mono)
                                .foregroundStyle(section == item ? Palette.vermilion : Palette.inkFaint)
                        }
                        .foregroundStyle(section == item ? Palette.ink : Palette.inkMuted)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(section == item ? Palette.paperDeep : Color.clear)
                        .overlay(alignment: .leading) {
                            if section == item {
                                Rectangle().fill(Palette.vermilion).frame(width: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 12)

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Rule(color: Palette.ruleLight)
                HStack(spacing: 7) {
                    Text("⌘")
                        .font(TypeScale.mono)
                    Text("+")
                        .font(TypeScale.mono)
                        .foregroundStyle(Palette.inkFaint)
                    Text("1")
                        .font(TypeScale.mono)
                    Text("随时截取")
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.inkMuted)
                }
                Text("选中任意文字后按下，期限是唯一必填项。")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 22)
        }
        .frame(width: 198)
        .background(Palette.paper.opacity(0.6))
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .active:
            activeContent
        case .completed:
            completedContent
        }
    }

    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("期限簿")
                        .font(TypeScale.display)
                        .foregroundStyle(Palette.ink)
                    Text(store.overdueCount > 0
                         ? "\(store.activeItems.count) 项待处理 · \(store.overdueCount) 项已逾期"
                         : "\(store.activeItems.count) 项待处理 · 全部还在期限内")
                        .font(TypeScale.small)
                        .foregroundStyle(store.overdueCount > 0 ? Palette.vermilion : Palette.inkMuted)
                }
                Spacer()
                Button {
                    coordinator.beginManualCapture()
                } label: {
                    Text("手动记一项")
                }
                .buttonStyle(QuietButtonStyle())
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 18)

            if let nearest = store.nearestItem {
                NextDeadlineStrip(item: nearest, now: now)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 22)
            }

            if let error = store.loadError {
                Text(error)
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.vermilion)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)
            }

            if store.activeItems.isEmpty {
                EmptyStateMark(
                    symbol: "text.cursor",
                    title: "还没有截下任何事",
                    detail: "在 Safari、备忘录或任何可选中文字的地方选中一句话，按 ⌘ 1。它会带着原话来到这里，等你交给它一个期限。"
                )
                .padding(.horizontal, 32)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.activeItems) { item in
                            ItemRow(
                                item: item,
                                now: now,
                                onComplete: { store.complete(item.id) },
                                onEdit: { editingItem = item },
                                onDelete: { pendingDelete = item }
                            )
                            Rule(color: Palette.ruleLight)
                                .padding(.leading, 32)
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
    }

    private var completedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("已完成")
                    .font(TypeScale.display)
                    .foregroundStyle(Palette.ink)
                Text(store.completedItems.isEmpty ? "完成的事会留在这里" : "\(store.completedItems.count) 项已经交代清楚")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkMuted)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 18)

            if store.completedItems.isEmpty {
                EmptyStateMark(
                    symbol: "checkmark.seal",
                    title: "没有已完成的记录",
                    detail: "在期限簿中勾选完成，事情会被收进这里。"
                )
                .padding(.horizontal, 32)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.completedItems) { item in
                            CompletedRow(item: item, onRestore: { store.restore(item.id) })
                            Rule(color: Palette.ruleLight)
                                .padding(.leading, 32)
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
    }
}

struct NextDeadlineStrip: View {
    let item: CaptureItem
    let now: Date

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text("最近一个期限")
                    .font(TypeScale.label)
                    .foregroundStyle(Palette.paperRaised.opacity(0.68))
                Text(DeadlineText.date(item.deadline))
                    .font(.system(size: 25, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.paperRaised)
            }
            .frame(width: 128, alignment: .leading)

            Rectangle().fill(Palette.paperRaised.opacity(0.22)).frame(width: 1, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.paperRaised)
                    .lineLimit(1)
                Text("\(DeadlineText.time(item.deadline)) · \(DeadlineText.relative(to: item.deadline, from: now))")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.paperRaised.opacity(0.74))
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.paperRaised.opacity(0.6))
        }
        .padding(.horizontal, 18)
        .frame(height: 78)
        .background(Palette.ink)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

struct ItemRow: View {
    let item: CaptureItem
    let now: Date
    let onComplete: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Button(action: onComplete) {
                Image(systemName: "circle")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(item.isOverdue(at: now) ? Palette.vermilion : Palette.inkFaint)
                    .frame(width: 22, height: 24)
            }
            .buttonStyle(.plain)
            .help("标记完成")

            VStack(alignment: .leading, spacing: 8) {
                Text(item.text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(3)
                    .textSelection(.enabled)
                HStack(spacing: 9) {
                    if let source = item.sourceApp, !source.isEmpty {
                        Text("来自 \(source)")
                            .font(TypeScale.small)
                            .foregroundStyle(Palette.inkFaint)
                        Circle().fill(Palette.rule).frame(width: 3, height: 3)
                    }
                    Text("截于 \(DeadlineText.date(item.createdAt)) \(DeadlineText.time(item.createdAt))")
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.inkFaint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DeadlineBadge(item: item, now: now)
                .frame(width: 178, alignment: .leading)

            HStack(spacing: 2) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(QuietButtonStyle())
                .help("编辑")
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(QuietButtonStyle())
                .help("删除")
            }
            .opacity(hovering ? 1 : 0.28)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 15)
        .background(hovering ? Palette.paperRaised.opacity(0.62) : Color.clear)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

struct CompletedRow: View {
    let item: CaptureItem
    let onRestore: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.olive)
                .frame(width: 22, height: 24)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Palette.inkMuted)
                    .strikethrough(true, color: Palette.inkFaint)
                Text(completedLabel)
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkFaint)
            }
            Spacer()
            Button("恢复", action: onRestore)
                .buttonStyle(QuietButtonStyle())
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }

    private var completedLabel: String {
        guard let completedAt = item.completedAt else { return "已完成" }
        return "\(DeadlineText.date(completedAt)) \(DeadlineText.time(completedAt)) 完成"
    }
}
