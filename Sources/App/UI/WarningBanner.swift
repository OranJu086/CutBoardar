import SwiftUI

/// 即将到期预警横幅：文案克制，只有主按钮用强调色。
struct WarningBanner: View
{
    let count: Int
    let daysLeft: Int
    let onShow: () -> Void
    let onExtendAll: () -> Void

    private var message: String
    {
        if daysLeft <= 0 { return "\(count) 条记录已到期或今日到期" }
        return "\(count) 条记录将在 \(daysLeft) 天内到期"
    }

    var body: some View
    {
        HStack(spacing: Space.s2)
        {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Theme.inkSecondary)

            Text(message)
                .font(.cbBody)
                .foregroundStyle(Theme.ink)

            Spacer(minLength: Space.s2)

            Button("查看", action: onShow).buttonStyle(PlainTextButtonStyle())
            Button("全部延长", action: onExtendAll).buttonStyle(AccentButtonStyle())
        }
        .padding(.horizontal, Space.s4)
        .padding(.vertical, Space.s2)
        .background(Theme.surfaceAlt)
        .overlay(alignment: .bottom) { Hairline() }
    }
}
