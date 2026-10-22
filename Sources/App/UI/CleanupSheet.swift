import SwiftUI

struct CleanupSheet: View
{
    @ObservedObject private var store = ClipStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View
    {
        let total = store.items.count
        let expired = Core.expiredItems().count

        VStack(alignment: .leading, spacing: Space.s4)
        {
            VStack(alignment: .leading, spacing: Space.s1)
            {
                Text("清理历史").font(.cbDisplay).foregroundStyle(Theme.ink)
                Text("当前共 \(total) 条记录，其中 \(expired) 条已过期。")
                    .font(.cbBody)
                    .foregroundStyle(Theme.inkSecondary)
                Text("清理会同时删除图片文件，且无法撤销。")
                    .font(.cbCaption)
                    .foregroundStyle(Theme.inkSecondary)
            }

            HStack(spacing: Space.s2)
            {
                Button("取消") { dismiss() }
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Spacer(minLength: Space.s2)
                Button("仅清理已过期（\(expired)）")
                {
                    Core.deleteExpired()
                    dismiss()
                }
                .buttonStyle(QuietButtonStyle())
                .disabled(expired == 0)

                Button("全部清理（\(total)）")
                {
                    Core.deleteAll()
                    dismiss()
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(total == 0)
            }
        }
        .padding(Space.s6)
        .frame(width: 460)
        .background(Theme.canvas)
    }
}
