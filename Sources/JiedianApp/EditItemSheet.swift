import SwiftUI
import JiedianCore

struct EditItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var deadline: Date
    let item: CaptureItem
    let onSave: (CaptureItem) -> Void

    init(item: CaptureItem, onSave: @escaping (CaptureItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _text = State(initialValue: item.text)
        _deadline = State(initialValue: item.deadline)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("修改这件事")
                        .font(TypeScale.title)
                        .foregroundStyle(Palette.ink)
                    Text("文字和期限都可以重新交代。")
                        .font(TypeScale.small)
                        .foregroundStyle(Palette.inkMuted)
                }
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

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("事项")
                        .font(TypeScale.label)
                        .foregroundStyle(Palette.inkFaint)
                    TextEditor(text: $text)
                        .font(.system(size: 15))
                        .scrollContentBackground(.hidden)
                        .padding(7)
                        .frame(height: 110)
                        .background(Palette.paper)
                        .overlay(Rectangle().stroke(Palette.ruleLight, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("截止时间")
                        .font(TypeScale.label)
                        .foregroundStyle(Palette.inkFaint)
                    HStack(spacing: 8) {
                        FieldBox {
                            DatePicker("", selection: $deadline, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                        }
                        FieldBox {
                            DatePicker("", selection: $deadline, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.field)
                        }
                        Spacer()
                    }
                }

                HStack {
                    Spacer()
                    Button("取消") { dismiss() }
                        .buttonStyle(QuietButtonStyle())
                        .keyboardShortcut(.cancelAction)
                    Button("保存修改") {
                        var updated = item
                        updated.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.deadline = deadline
                        onSave(updated)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24)
        }
        .frame(width: 500)
        .background(Palette.paperRaised)
    }
}
