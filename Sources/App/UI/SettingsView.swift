import SwiftUI

@MainActor
struct SettingsView: View
{
    @ObservedObject private var store = ClipStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled
    @State private var launchMessage: String?

    private var retentionBinding: Binding<Int>
    {
        Binding(get: { store.settings.retentionDays }, set: { Core.setRetentionDays($0) })
    }

    private var warnBinding: Binding<Int>
    {
        Binding(get: { store.settings.warnDaysBefore }, set: { Core.setWarnDays($0) })
    }

    private var maxItemsBinding: Binding<Int>
    {
        Binding(get: { store.settings.maxItems }, set: { Core.setMaxItems($0) })
    }

    private var notificationsBinding: Binding<Bool>
    {
        Binding(get: { store.settings.notificationsEnabled }, set: { Core.setNotifications($0) })
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: Space.s4)
        {
            Text("设置").font(.cbDisplay).foregroundStyle(Theme.ink)

            row(title: "全局保留天数", detail: "默认 30 天，到期后自动清理")
            {
                Stepper(value: retentionBinding, in: 1...365)
                {
                    Text("\(store.settings.retentionDays) 天").font(.cbBody)
                }
            }

            row(title: "提前预警天数", detail: "到期前多少天开始提醒")
            {
                Stepper(value: warnBinding, in: 0...30)
                {
                    Text("\(store.settings.warnDaysBefore) 天").font(.cbBody)
                }
            }

            row(title: "最大条数", detail: "超出后自动丢弃最旧的记录")
            {
                Stepper(value: maxItemsBinding, in: 100...10_000, step: 100)
                {
                    Text("\(store.settings.maxItems) 条").font(.cbBody)
                }
            }

            Toggle("到期前发送系统通知", isOn: notificationsBinding)
                .toggleStyle(.switch)
                .font(.cbBody)

            Toggle("开机自启", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .font(.cbBody)
                .onChange(of: launchAtLogin) { value, _ in applyLaunchAtLogin(value) }

            if let launchMessage
            {
                Text(launchMessage).font(.cbCaption).foregroundStyle(Theme.inkSecondary)
            }

            Hairline()

            HStack
            {
                Text("数据目录：~/Library/Application Support/CutBoardar")
                    .font(.cbCaption)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(AccentButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.s6)
        .frame(width: 480)
        .background(Theme.canvas)
    }

    private func row<Content: View>(title: String, detail: String, @ViewBuilder content: () -> Content) -> some View
    {
        HStack(alignment: .firstTextBaseline)
        {
            VStack(alignment: .leading, spacing: 2)
            {
                Text(title).font(.cbBody).foregroundStyle(Theme.ink)
                Text(detail).font(.cbCaption).foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: Space.s3)
            content()
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool)
    {
        if let message = LaunchAtLogin.setEnabled(enabled)
        {
            launchMessage = message
            launchAtLogin = LaunchAtLogin.isEnabled
        }
        else
        {
            launchMessage = enabled ? "已开启开机自启" : "已关闭开机自启"
        }
    }
}
