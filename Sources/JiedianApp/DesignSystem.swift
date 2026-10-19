import SwiftUI
import JiedianCore

enum Palette {
    static let paper = Color(red: 0.965, green: 0.952, blue: 0.925)
    static let paperRaised = Color(red: 0.988, green: 0.982, blue: 0.963)
    static let paperDeep = Color(red: 0.936, green: 0.918, blue: 0.878)
    static let ink = Color(red: 0.105, green: 0.098, blue: 0.085)
    static let inkMuted = Color(red: 0.39, green: 0.36, blue: 0.31)
    static let inkFaint = Color(red: 0.53, green: 0.49, blue: 0.42)
    static let vermilion = Color(red: 0.72, green: 0.17, blue: 0.09)
    static let vermilionWash = Color(red: 0.89, green: 0.76, blue: 0.69)
    static let rule = Color(red: 0.72, green: 0.69, blue: 0.62)
    static let ruleLight = Color(red: 0.83, green: 0.80, blue: 0.74)
    static let olive = Color(red: 0.31, green: 0.34, blue: 0.22)
    static let dangerWash = Color(red: 0.91, green: 0.84, blue: 0.79)
}

enum TypeScale {
    static let display = Font.system(size: 34, weight: .medium, design: .serif)
    static let title = Font.system(size: 22, weight: .semibold, design: .serif)
    static let section = Font.system(size: 15, weight: .semibold, design: .default)
    static let body = Font.system(size: 14, weight: .regular, design: .default)
    static let small = Font.system(size: 12, weight: .regular, design: .default)
    static let label = Font.system(size: 11, weight: .medium, design: .default)
    static let mono = Font.system(size: 11, weight: .medium, design: .monospaced)
}

struct Rule: View {
    var color: Color = Palette.ruleLight
    var height: CGFloat = 1

    var body: some View {
        Rectangle().fill(color).frame(height: height)
    }
}

struct CornerMark: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Palette.rule).frame(width: 11, height: 1)
            Rectangle().fill(Palette.rule).frame(width: 1, height: 11)
        }
        .frame(width: 11, height: 11)
        .accessibilityHidden(true)
    }
}

struct ShortcutKey: View {
    let label: String

    var body: some View {
        Text(label)
            .font(TypeScale.mono)
            .foregroundStyle(Palette.inkMuted)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Palette.paperDeep)
            .overlay(Rectangle().stroke(Palette.ruleLight, lineWidth: 1))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.paperRaised)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(isEnabled ? (configuration.isPressed ? Palette.vermilion.opacity(0.82) : Palette.vermilion) : Palette.rule)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 13)
            .frame(height: 32)
            .background(configuration.isPressed ? Palette.paperDeep : Palette.paperRaised)
            .overlay(Rectangle().stroke(Palette.rule, lineWidth: 1))
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypeScale.small)
            .foregroundStyle(configuration.isPressed ? Palette.ink : Palette.inkMuted)
            .padding(.horizontal, 7)
            .frame(height: 27)
            .background(configuration.isPressed ? Palette.paperDeep : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct FieldBox<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(Palette.paperRaised)
            .overlay(Rectangle().stroke(Palette.ruleLight, lineWidth: 1))
    }
}

struct DeadlineBadge: View {
    let item: CaptureItem
    let now: Date

    var body: some View {
        let overdue = item.isOverdue(at: now)
        VStack(alignment: .leading, spacing: 3) {
            Text(DeadlineText.full(item.deadline))
                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                .foregroundStyle(overdue ? Palette.vermilion : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
            Text(DeadlineText.relative(to: item.deadline, from: now))
                .font(TypeScale.small)
                .foregroundStyle(overdue ? Palette.vermilion : Palette.inkMuted)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct EmptyStateMark: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Palette.inkFaint)
            Text(title)
                .font(TypeScale.title)
                .foregroundStyle(Palette.ink)
            Text(detail)
                .font(TypeScale.body)
                .foregroundStyle(Palette.inkMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}
