import AppKit
import SwiftUI

extension Notification.Name
{
    static let cbFocusSearch = Notification.Name("cb.focusSearch")
    static let cbOpenSettings = Notification.Name("cb.openSettings")
    static let cbOpenCleanup = Notification.Name("cb.openCleanup")
    static let cbOpenAdd = Notification.Name("cb.openAdd")
    static let cbDeleteSelection = Notification.Name("cb.deleteSelection")
    static let cbCopySelection = Notification.Name("cb.copySelection")
    static let cbHotKey = Notification.Name("cb.hotKey")
    static let cbShowMainWindow = Notification.Name("cb.showMainWindow")
    static let cbClosePopover = Notification.Name("cb.closePopover")
}

@MainActor
final class AppRouter
{
    static let shared = AppRouter()
    var openWindowAction: OpenWindowAction?

    /// 菜单栏 / 热键 / Dock 统一入口：把主窗口拉到前面，可选聚焦搜索框。
    func showMainWindow(focusSearch: Bool)
    {
        NSApp.activate(ignoringOtherApps: true)
        openWindowAction?(id: "main")
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        }
        guard focusSearch else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: .cbFocusSearch, object: nil)
        }
    }
}
