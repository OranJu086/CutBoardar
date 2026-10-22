import Foundation

/// 开机自启用 LaunchAgent 实现；任何一步失败都只返回提示，绝不崩。
enum LaunchAtLogin
{
    static let label = "com.zhangsong.CutBoardar.launcher"

    static var plistURL: URL
    {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    static var isEnabled: Bool
    {
        return FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// 返回 nil 表示成功，否则是人类可读的失败原因。
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> String?
    {
        return enabled ? enable() : disable()
    }

    private static func enable() -> String?
    {
        guard let executable = Bundle.main.executablePath else { return "找不到可执行文件路径" }

        let payload: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: payload, format: .xml, options: 0)
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: plistURL, options: .atomic)
        } catch {
            return "写入启动项失败：\(error.localizedDescription)"
        }

        _ = runLaunchctl(["load", "-w", plistURL.path])
        return nil
    }

    private static func disable() -> String?
    {
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return nil }
        _ = runLaunchctl(["unload", "-w", plistURL.path])
        do {
            try FileManager.default.removeItem(at: plistURL)
        } catch {
            return "移除启动项失败：\(error.localizedDescription)"
        }
        return nil
    }

    private static func runLaunchctl(_ arguments: [String]) -> Int32
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
