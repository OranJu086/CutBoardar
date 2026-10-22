import Foundation
import SwiftUI

// 入口分发：--selftest 走 Core 无头自检，其余场景交给 SwiftUI。
@main
enum AppMain
{
    static func main()
    {
        if CommandLine.arguments.contains("--selftest")
        {
            exit(SelfTest.run())
        }

        CutBoardarApp.main()
    }
}

struct CutBoardarApp: App
{
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene
    {
        Window("CutBoardar", id: "main")
        {
            RootView()
        }
        .defaultSize(width: 980, height: 640)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands
        {
            CommandGroup(replacing: .appSettings)
            {
                Button("设置…") { post(.cbOpenSettings) }
                    .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(replacing: .newItem)
            {
                Button("新增记录…") { post(.cbOpenAdd) }
                    .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .newItem)
            {
                Divider()
                Button("聚焦搜索") { post(.cbFocusSearch) }
                    .keyboardShortcut("f", modifiers: .command)
                Button("复制选中记录") { post(.cbCopySelection) }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Button("删除选中记录") { post(.cbDeleteSelection) }
                    .keyboardShortcut(.delete, modifiers: .command)
                Divider()
                Button("清理历史…") { post(.cbOpenCleanup) }
                    .keyboardShortcut(.delete, modifiers: [.command, .shift])
            }
        }
    }

    private func post(_ name: Notification.Name)
    {
        NotificationCenter.default.post(name: name, object: nil)
    }
}
