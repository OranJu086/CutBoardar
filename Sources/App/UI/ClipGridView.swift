import SwiftUI

struct ClipCardView: View
{
    let item: ClipItem
    let isSelected: Bool
    let onOpen: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    @State private var hovering = false

    var body: some View
    {
        VStack(alignment: .leading, spacing: Space.s2)
        {
            HStack(spacing: Space.s2)
            {
                KindBadge(kind: item.cbKind)
                Spacer(minLength: Space.s1)
                Text(CBTime.relative(item.cbCreatedAt)).font(.cbCaption).foregroundStyle(Theme.inkSecondary)
            }

            ClipSummaryView(item: item, lineLimit: 4, imageHeight: 88)

            Spacer(minLength: 0)

            if !item.cbNote.isEmpty
            {
                Text(item.cbNote)
                    .font(.cbCaption)
                    .italic()
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Space.s3)
        .frame(height: 176, alignment: .topLeading)
        .paperSurface(radius: Theme.cardRadius, elevated: hovering || isSelected, highlighted: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { onOpen() }
        .onTapGesture { onOpen() }
        .contextMenu
        {
            Button("复制") { onOpen() }
            Button("编辑与备注") { onEdit() }
            Button("删除", role: .destructive) { onDelete() }
        }
    }
}

struct ClipGridView: View
{
    let items: [ClipItem]
    @Binding var selection: ClipItem.ID?
    let onCopy: (ClipItem) -> Void
    let onDelete: (ClipItem.ID) -> Void
    let onEdit: (ClipItem) -> Void

    private var columns: [GridItem]
    {
        [GridItem(.adaptive(minimum: 240, maximum: 360), spacing: Space.s3, alignment: .top)]
    }

    var body: some View
    {
        ScrollView
        {
            LazyVGrid(columns: columns, alignment: .leading, spacing: Space.s3)
            {
                ForEach(items)
                { item in
                    ClipCardView(
                        item: item,
                        isSelected: selection == item.id,
                        onOpen: {
                            selection = item.id
                            onCopy(item)
                        },
                        onDelete: { onDelete(item.id) },
                        onEdit: { onEdit(item) }
                    )
                }
            }
            .padding(Space.s4)
        }
        .background(Theme.canvas)
    }
}
