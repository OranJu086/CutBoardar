import SwiftUI

struct AddItemSheet: View
{
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var editorFocused: Bool

    private var canSave: Bool
    {
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: Space.s3)
        {
            VStack(alignment: .leading, spacing: Space.s1)
            {
                Text("新增记录").font(.cbDisplay).foregroundStyle(Theme.ink)
                Text("粘贴或输入要保存的文本").font(.cbCaption).foregroundStyle(Theme.inkSecondary)
            }

            TextEditor(text: $text)
                .font(.cbBody)
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .padding(Space.s2)
                .frame(height: 160)
                .background(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous).fill(Theme.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: Theme.hairWidth)
                )
                .focused($editorFocused)

            HStack(spacing: Space.s2)
            {
                Button("取消") { dismiss() }
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存")
                {
                    Core.addText(text)
                    dismiss()
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(!canSave)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.s6)
        .frame(width: 520)
        .background(Theme.canvas)
        .onAppear { editorFocused = true }
    }
}
