import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate
{
    private var statusBar: StatusBarController?
    private var hotKey: HotKeyCenter?
    private var observers: [NSObjectProtocol] = []
    private var maintenanceTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification)
    {
        Core.startMonitoring()
        Core.runExpirySweep()
        Core.notifyExpiringOncePerDay()

        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 1_800, repeats: true)
        { _ in
            Task { @MainActor in
                Core.runExpirySweep()
                Core.notifyExpiringOncePerDay()
            }
        }

        statusBar = StatusBarController()

        let hotKeyCenter = HotKeyCenter()
        if !hotKeyCenter.register()
        {
            NSLog("CutBoardar: 全局热键 ⇧⌘V 注册失败（可能被其它应用占用）")
        }
        hotKey = hotKeyCenter

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .cbHotKey, object: nil, queue: .main) { _ in
            Task { @MainActor in AppRouter.shared.showMainWindow(focusSearch: true) }
        })
        observers.append(center.addObserver(forName: .cbShowMainWindow, object: nil, queue: .main) { _ in
            Task { @MainActor in AppRouter.shared.showMainWindow(focusSearch: false) }
        })
    }

    func applicationWillTerminate(_ notification: Notification)
    {
        let center = NotificationCenter.default
        for observer in observers { center.removeObserver(observer) }
        observers.removeAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
    {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
    {
        if !flag { AppRouter.shared.showMainWindow(focusSearch: false) }
        return true
    }
}
