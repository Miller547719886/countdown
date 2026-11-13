import SwiftUI
import JiedianCore

struct ReminderEditorView: View {
    @Binding var reminders: [DeadlineReminder]
    let deadline: Date
    let allowsUnchangedInvalidPlan: Bool

    init(
        reminders: Binding<[DeadlineReminder]>,
        deadline: Date,
        allowsUnchangedInvalidPlan: Bool = false
    ) {
        self._reminders = reminders
        self.deadline = deadline
        self.allowsUnchangedInvalidPlan = allowsUnchangedInvalidPlan
    }

    private let daysFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = NSNumber(value: ReminderPlanner.maximumDaysBeforeDeadline)
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("提前多久提醒我")
                        .font(TypeScale.label)
                        .foregroundStyle(Palette.inkFaint)
                    Text("默认依次提前 N 到 1 天，早上 08:00 提醒。")
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.inkMuted)
                }
                Spacer(minLength: 8)
                Stepper(value: reminderCountBinding, in: 0...ReminderPlanner.maximumReminderCount) {
                    Text(reminders.isEmpty ? "关闭" : "\(reminders.count) 次")
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.ink)
                }
                .accessibilityLabel("提醒次数")
            }

            if reminders.isEmpty {
                Text("这条事项不会提前提醒。")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.inkFaint)
            } else {
                ForEach(reminders.indices, id: \.self) { index in
                    reminderEditor(at: index)
                    if index < reminders.count - 1 {
                        Rule(color: Palette.ruleLight)
                    }
                }
            }

            if hasCustomReminderAtOrAfterDeadline {
                Text("自定义提醒时间必须早于截止时间。")
                    .font(TypeScale.small)
                    .foregroundStyle(Palette.vermilion)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 2)
    }

    private var reminderCountBinding: Binding<Int> {
        Binding(
            get: { reminders.count },
            set: { reminders = ReminderPlanner.resize(reminders, to: $0) }
        )
    }

    private var hasCustomReminderAtOrAfterDeadline: Bool {
        !allowsUnchangedInvalidPlan
            && ReminderPlanner.hasCustomReminderAtOrAfterDeadline(reminders, deadline: deadline)
    }

    private func reminderEditor(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("第 \(index + 1) 次提醒")
                    .font(TypeScale.label)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Picker(
                    "第 \(index + 1) 次提醒方式",
                    selection: reminderModeBinding(at: index)
                ) {
                    Text("提前天数").tag(DeadlineReminderMode.relative)
                    Text("自定义").tag(DeadlineReminderMode.custom)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            if reminders[index].mode == .relative {
                HStack(spacing: 8) {
                    Text("提前")
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.inkMuted)
                    FieldBox {
                        TextField("", value: reminderDaysBinding(at: index), formatter: daysFormatter)
                            .textFieldStyle(.plain)
                            .font(TypeScale.mono)
                            .multilineTextAlignment(.center)
                            .frame(width: 34)
                            .accessibilityLabel("第 \(index + 1) 次提前天数")
                    }
                    .frame(width: 54)
                    Text("天")
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.inkMuted)
                    DatePicker(
                        "",
                        selection: reminderTimeBinding(at: index),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .accessibilityLabel("第 \(index + 1) 次提醒时间")
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 8) {
                    DatePicker(
                        "日期",
                        selection: customReminderDateBinding(at: index),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.field)
                    .accessibilityLabel("第 \(index + 1) 次自定义提醒日期")

                    DatePicker(
                        "时间",
                        selection: customReminderTimeBinding(at: index),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.field)
                    .accessibilityLabel("第 \(index + 1) 次自定义提醒时间")

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, 7)
    }

    private func reminderModeBinding(at index: Int) -> Binding<DeadlineReminderMode> {
        Binding(
            get: { reminders[index].mode },
            set: { mode in
                var reminder = reminders[index]
                if mode == .custom, reminder.mode != .custom {
                    reminder.customDate = reminder.fireDate(relativeTo: deadline) ?? deadline
                }
                reminder.mode = mode
                reminders[index] = reminder
            }
        )
    }

    private func reminderDaysBinding(at index: Int) -> Binding<Int> {
        Binding(
            get: { reminders[index].daysBeforeDeadline },
            set: {
                reminders[index].daysBeforeDeadline = min(
                    max($0, 1),
                    ReminderPlanner.maximumDaysBeforeDeadline
                )
            }
        )
    }

    private func reminderTimeBinding(at index: Int) -> Binding<Date> {
        Binding(
            get: {
                timePickerValue(
                    hour: reminders[index].hour,
                    minute: reminders[index].minute
                )
            },
            set: { value in
                let components = Calendar.current.dateComponents([.hour, .minute], from: value)
                reminders[index].hour = components.hour ?? 8
                reminders[index].minute = components.minute ?? 0
            }
        )
    }

    private func customReminderDateBinding(at index: Int) -> Binding<Date> {
        Binding(
            get: {
                reminders[index].customDate
                    ?? reminders[index].fireDate(relativeTo: deadline)
                    ?? deadline
            },
            set: { value in
                let calendar = Calendar.current
                let current = reminders[index].customDate ?? value
                let time = calendar.dateComponents([.hour, .minute], from: current)
                var components = calendar.dateComponents([.era, .year, .month, .day], from: value)
                components.hour = time.hour ?? 8
                components.minute = time.minute ?? 0
                components.second = 0
                reminders[index].customDate = calendar.date(from: components) ?? value
            }
        )
    }

    private func customReminderTimeBinding(at index: Int) -> Binding<Date> {
        Binding(
            get: {
                let current = reminders[index].customDate
                    ?? reminders[index].fireDate(relativeTo: deadline)
                    ?? deadline
                let components = Calendar.current.dateComponents([.hour, .minute], from: current)
                return timePickerValue(hour: components.hour ?? 8, minute: components.minute ?? 0)
            },
            set: { value in
                let calendar = Calendar.current
                let current = reminders[index].customDate
                    ?? reminders[index].fireDate(relativeTo: deadline)
                    ?? deadline
                let time = calendar.dateComponents([.hour, .minute], from: value)
                var components = calendar.dateComponents([.era, .year, .month, .day], from: current)
                components.hour = time.hour ?? 8
                components.minute = time.minute ?? 0
                components.second = 0
                reminders[index].customDate = calendar.date(from: components) ?? current
            }
        )
    }

    private func timePickerValue(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        return Calendar(identifier: .gregorian).date(from: components) ?? .distantPast
    }
}
