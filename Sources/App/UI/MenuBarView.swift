import SwiftUI

@MainActor
struct MenuBarView: View
{
    @ObservedObject private var store = ClipStore.shared
    @State private var confirmingClear = false

    private var recent: [ClipItem]
    {
        Array(store.items.prefix(8))
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 0)
        {
            Text("最近记录")
                .font(.cbCaption)
                .foregroundStyle(Theme.inkSecondary)
                .padding(.horizontal, Space.s3)
                .padding(.top, Space.s3)
                .padding(.bottom, Space.s1)

            if recent.isEmpty
            {
                VStack(spacing: Space.s1)
                {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 20, weight: .ultraLight))
                        .foregroundStyle(Theme.hairline)
                    Text("复制点什么，它会出现在这里")
                        .font(.cbCaption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.s6)
            }
            else
            {
                ForEach(recent)
                { item in
                    MenuBarRow(item: item) { pick(item) }
                }
            }

            Hairline().padding(.vertical, Space.s1)

            MenuBarAction(symbol: "macwindow", title: "打开主窗口", tint: Theme.ink) { openMain() }

            MenuBarAction(
                symbol: "trash",
                title: confirmingClear ? "再点一次清空历史" : "清空历史",
                tint: confirmingClear ? Theme.accent : Theme.ink
            )
            {
                if confirmingClear
                {
                    Core.deleteAll()
                    confirmingClear = false
                    close()
                }
                else
                {
                    confirmingClear = true
                }
            }
        }
        .frame(width: 320)
        .background(Theme.canvas)
    }

    private func pick(_ item: ClipItem)
    {
        Core.copy(item)
        close()
    }

    private func openMain()
    {
        close()
        AppRouter.shared.showMainWindow(focusSearch: true)
    }

    private func close()
    {
        NotificationCenter.default.post(name: .cbClosePopover, object: nil)
    }
}

struct MenuBarRow: View
{
    let item: ClipItem
    let action: () -> Void
    @State private var hovering = false

    var body: some View
    {
        Button(action: action)
        {
            HStack(spacing: Space.s2)
            {
                Image(systemName: KindStyle.symbol(item.cbKind))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(width: 14)

                Text(CBSummaries.oneLine(item))
                    .font(.cbBody)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: Space.s2)

                Text(CBTime.relative(item.cbCreatedAt))
                    .font(.cbCaption)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(.horizontal, Space.s3)
            .frame(height: 30)
            .background(hovering ? Theme.surfaceAlt : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct MenuBarAction: View
{
    let symbol: String
    let title: String
    let tint: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View
    {
        Button(action: action)
        {
            HStack(spacing: Space.s2)
            {
                Image(systemName: symbol).font(.system(size: 11)).frame(width: 14)
                Text(title).font(.cbBody)
                Spacer()
            }
            .foregroundStyle(tint)
            .padding(.horizontal, Space.s3)
            .frame(height: 30)
            .background(hovering ? Theme.surfaceAlt : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
