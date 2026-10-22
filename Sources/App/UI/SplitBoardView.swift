import SwiftUI

struct SplitBoardView: View
{
    let items: [ClipItem]
    @Binding var selection: ClipItem.ID?
    let onCopy: (ClipItem) -> Void
    let onDelete: (ClipItem.ID) -> Void
    let onFlash: (String) -> Void

    private var current: ClipItem?
    {
        if let selected = items.first(where: { $0.id == selection }) { return selected }
        return items.first
    }

    var body: some View
    {
        HSplitView
        {
            leftList
            detail
        }
        .onAppear
        {
            if selection == nil { selection = items.first?.id }
        }
    }

    private var leftList: some View
    {
        ScrollView
        {
            LazyVStack(spacing: 0)
            {
                ForEach(items)
                { item in
                    ClipRowView(item: item, isSelected: item.id == current?.id, showNote: false)
                        .contentShape(Rectangle())
                        .onTapGesture { selection = item.id }
                        .onTapGesture(count: 2)
                        {
                            selection = item.id
                            onCopy(item)
                        }
                        .contextMenu
                        {
                            Button("复制") { onCopy(item) }
                            Button("删除", role: .destructive) { onDelete(item.id) }
                        }

                    if item.id != items.last?.id
                    {
                        Hairline().padding(.leading, Space.s4 + 16)
                    }
                }
            }
            .padding(.vertical, Space.s1)
        }
        .frame(minWidth: 240, idealWidth: 300, maxWidth: 420)
        .background(Theme.canvas)
    }

    @ViewBuilder private var detail: some View
    {
        if let item = current
        {
            DetailPanel(
                item: item,
                onCopy: { onCopy(item) },
                onDelete: { onDelete(item.id) },
                onFlash: onFlash
            )
            .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        }
        else
        {
            EmptyStateView()
        }
    }
}
