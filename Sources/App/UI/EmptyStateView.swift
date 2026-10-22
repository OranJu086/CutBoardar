import SwiftUI

struct EmptyStateView: View
{
    var searching: Bool = false

    var body: some View
    {
        VStack(spacing: Space.s3)
        {
            Image(systemName: searching ? "magnifyingglass" : "doc.on.clipboard")
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundStyle(Theme.hairline)

            Text(searching ? "没有匹配的记录" : "复制点什么，它会出现在这里")
                .font(.cbSection)
                .foregroundStyle(Theme.inkSecondary)

            if !searching
            {
                Text("也可以按 ⌘N 手动新增一条")
                    .font(.cbCaption)
                    .foregroundStyle(Theme.inkSecondary.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.canvas)
    }
}
