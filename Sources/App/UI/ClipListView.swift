import SwiftUI

struct ClipListView: View
{
    let items: [ClipItem]
    @Binding var selection: ClipItem.ID?
    let onCopy: (ClipItem) -> Void
    let onDelete: (ClipItem.ID) -> Void
    let onEdit: (ClipItem) -> Void

    var body: some View
    {
        ScrollView
        {
            LazyVStack(spacing: 0)
            {
                ForEach(items)
                { item in
                    ClipRowView(item: item, isSelected: selection == item.id)
                        .contentShape(Rectangle())
                        .onTapGesture
                        {
                            selection = item.id
                            onCopy(item)
                        }
                        .contextMenu
                        {
                            Button("复制") { onCopy(item) }
                            Button("编辑与备注") { onEdit(item) }
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
        .background(Theme.canvas)
    }
}
