import Foundation
import AppKit

// 自检计数与输出
final class SelfTestReport
{

    private(set) var passed = 0
    private(set) var failed = 0

    func check(_ condition: Bool, _ title: String, detail: String? = nil)
    {

        if condition
        {
            passed += 1
            print("PASS  \(title)")
            return
        }

        failed += 1

        if let detail
        {
            print("FAIL  \(title)  →  \(detail)")
        }
        else
        {
            print("FAIL  \(title)")
        }

    }

    func finish() -> Int32
    {

        print("")
        print("---- 汇总 ----")
        print("PASS: \(passed)    FAIL: \(failed)")

        if failed == 0
        {
            print("自检全部通过")
            return 0
        }

        print("自检存在失败项")
        return 1

    }

}

// 无头自检：在临时数据目录里跑一遍核心能力，不碰界面
enum SelfTest
{

    // 函数：自检入口
    // 返回值：0 全部通过；1 有失败项；2 环境不满足（非主线程）
    static func run() -> Int32
    {

        if !Thread.isMainThread
        {
            print("FAIL  自检必须在主线程运行")
            return 2
        }

        return MainActor.assumeIsolated
        {
            runOnMain()
        }

    }

    // 函数：找出两组条目第一处不一致，失败时给出可定位的证据
    private static func firstMismatch(_ left: [ClipItem], _ right: [ClipItem]) -> String
    {

        if left.count != right.count
        {
            return "数量不同: \(left.count) vs \(right.count)"
        }

        for (index, pair) in zip(left, right).enumerated()
        {
            let before = pair.0
            let after = pair.1

            if before == after
            {
                continue
            }

            if before.createdAt != after.createdAt
            {
                return "#\(index) createdAt \(before.createdAt.timeIntervalSinceReferenceDate) vs \(after.createdAt.timeIntervalSinceReferenceDate)"
            }

            if before.displayTitle != after.displayTitle
            {
                return "#\(index) displayTitle \(before.displayTitle) vs \(after.displayTitle)"
            }

            if before.displaySubtitle != after.displaySubtitle
            {
                return "#\(index) displaySubtitle \(before.displaySubtitle) vs \(after.displaySubtitle)"
            }

            return "#\(index) 条目内容不一致"
        }

        return "无差异"
    }

    @MainActor
    private static func runOnMain() -> Int32
    {

        let report = SelfTestReport()
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CutBoardarSelfTest-\(UUID().uuidString)", isDirectory: true)

        defer
        {
            try? fileManager.removeItem(at: root)
        }

        print("== CutBoardar Core 自检 ==")
        print("临时数据目录: \(root.path)")
        print("")

        // 1. 数据目录解析
        setenv(CoreDataPaths.environmentKey, root.path, 1)
        let resolved = CoreDataPaths.dataDirectory().standardizedFileURL.path
        unsetenv(CoreDataPaths.environmentKey)

        report.check(resolved == root.standardizedFileURL.path,
                     "环境变量 CUTBOARDAR_DATA_DIR 能覆盖数据目录",
                     detail: resolved)

        let defaultDirectory = CoreDataPaths.dataDirectory().path
        report.check(defaultDirectory.contains("Application Support/CutBoardar"),
                     "默认数据目录是 ~/Library/Application Support/CutBoardar",
                     detail: defaultDirectory)

        // 2. 契约默认值
        let defaults = AppSettings()
        report.check(defaults.retentionDays == 30
                     && defaults.warnDaysBefore == 3
                     && defaults.maxItems == 2000
                     && abs(defaults.pollInterval - 0.4) < 0.0001
                     && defaults.notificationsEnabled,
                     "AppSettings 默认值符合契约（30 / 3 / 2000 / 0.4 / true）")
        report.check(defaults.viewMode == .grid, "默认视图模式为 grid")
        report.check(ClipKind.allCases.count == 3 && ViewMode.allCases.count == 3, "ClipKind / ViewMode 各 3 种")

        // 3. 空仓库
        let store = ClipStore(dataDirectory: root)
        report.check(store.items.isEmpty, "新仓库初始为空")
        report.check(store.runExpirySweep() == 0, "空仓库清理返回 0")
        report.check(store.pendingWarningText() == nil, "没有记录时不产生预警文案")

        // 3.1 单例同样走环境变量
        let sharedRoot = root.appendingPathComponent("shared", isDirectory: true)
        setenv(CoreDataPaths.environmentKey, sharedRoot.path, 1)
        let sharedStore = ClipStore.shared
        unsetenv(CoreDataPaths.environmentKey)
        report.check(sharedStore.dataDirectory.standardizedFileURL.path == sharedRoot.standardizedFileURL.path,
                     "ClipStore.shared 使用环境变量指定的目录",
                     detail: sharedStore.dataDirectory.path)

        // 4. 三种类型各加一条
        store.addText("你好，CutBoardar")
        report.check(store.items.count == 1 && store.items[0].kind == .text, "新增文本条目")

        guard let png = CBImageCodec.makeTestPNG(width: 32, height: 32) else
        {
            report.check(false, "用代码生成一张小 png")
            return report.finish()
        }
        report.check(true, "用代码生成一张小 png（\(png.count) 字节）")

        guard let imageItem = store.addImage(png) else
        {
            report.check(false, "新增图片条目")
            return report.finish()
        }
        report.check(store.items.count == 2 && imageItem.kind == .image, "新增图片条目")

        store.addFile("/tmp/cutboardar-selftest/季度报告.txt")
        report.check(store.items.count == 3, "新增文件条目，三种类型齐了", detail: "实际 \(store.items.count)")

        // 5. 顺序与去重
        let descending = zip(store.items, store.items.dropFirst()).allSatisfy { $0.createdAt >= $1.createdAt }
        report.check(descending, "items 顺序为新 → 旧")
        report.check(store.items.first?.kind == .file, "最新一条是最后添加的文件")

        let beforeTextDedupe = store.items.count
        store.addText("同一段内容")
        store.addText("同一段内容")
        report.check(store.items.count == beforeTextDedupe + 1,
                     "重复添加相同文本被去重",
                     detail: "\(beforeTextDedupe) → \(store.items.count)")

        let beforeImageDedupe = store.items.count
        _ = store.addImage(png)
        let afterFirstImage = store.items.count
        _ = store.addImage(png)
        report.check(afterFirstImage == beforeImageDedupe + 1 && store.items.count == afterFirstImage,
                     "重复添加相同图片被去重",
                     detail: "\(beforeImageDedupe) → \(afterFirstImage) → \(store.items.count)")

        // 6. 修改正文与备注
        guard let textTarget = store.items.first(where: { $0.text == "你好，CutBoardar" }) else
        {
            report.check(false, "找到待修改的文本条目")
            return report.finish()
        }

        store.update(id: textTarget.id, text: "你好，CutBoardar（已改）", note: "会议纪要")

        guard let editedItem = store.item(with: textTarget.id) else
        {
            report.check(false, "update 后能取回条目")
            return report.finish()
        }

        report.check(editedItem.text == "你好，CutBoardar（已改）", "update 能改正文")
        report.check(editedItem.note == "会议纪要", "update 能改备注")
        report.check(editedItem.displayTitle.contains("已改"), "update 后列表摘要同步刷新", detail: editedItem.displayTitle)

        // 7. 关键字过滤
        report.check(store.filtered(keyword: "会议纪要").count == 1, "关键字过滤命中备注")
        report.check(store.filtered(keyword: "").count == store.items.count, "空关键字返回全部")
        report.check(store.filtered(keyword: "绝对不存在的关键字").isEmpty, "无命中时返回空数组")

        // 8. 图片落盘
        if let url = store.imageURL(for: imageItem)
        {
            report.check(fileManager.fileExists(atPath: url.path), "图片已落盘", detail: url.path)
            report.check(url.path.contains("/images/"), "图片位于 images/ 目录下")
            report.check(url.pathExtension.lowercased() == "png", "图片以 png 保存")

            if let data = try? Data(contentsOf: url)
            {
                let magic: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
                report.check(data.count > magic.count && Array(data.prefix(4)) == magic, "落盘文件是真正的 png（校验文件头）")
            }
            else
            {
                report.check(false, "能读出落盘图片")
            }
        }
        else
        {
            report.check(false, "图片已落盘")
        }

        // 9. 持久化与重新加载
        store.flush()
        report.check(fileManager.fileExists(atPath: store.storeFileURL.path), "持久化文件已生成", detail: store.storeFileURL.path)

        let reloaded = ClipStore(dataDirectory: root)
        report.check(reloaded.items.count == store.items.count,
                     "重新构造 store 后条目数一致",
                     detail: "\(store.items.count) → \(reloaded.items.count)")
        report.check(reloaded.items == store.items,
                     "重新加载后内容与内存完全一致（Equatable）",
                     detail: firstMismatch(store.items, reloaded.items))
        report.check(reloaded.settings == store.settings, "重新加载后设置一致")

        // 10. 保留引擎
        let base = Date()
        let expiredItem = ClipItem(kind: .text, text: "31 天前的记录", createdAt: base.addingTimeInterval(-31 * 86400))
        let aliveItem = ClipItem(kind: .text, text: "29 天前的记录", createdAt: base.addingTimeInterval(-29 * 86400))

        store.add(expiredItem)
        store.add(aliveItem)
        report.check(store.items.contains(where: { $0.id == expiredItem.id })
                     && store.items.contains(where: { $0.id == aliveItem.id }),
                     "两条历史条目已写入")

        let removedCount = store.runExpirySweep()
        report.check(removedCount == 1, "runExpirySweep 只删除已过期条目", detail: "删除 \(removedCount) 条")
        report.check(!store.items.contains(where: { $0.id == expiredItem.id }), "31 天前的条目已被删除")
        report.check(store.items.contains(where: { $0.id == aliveItem.id }), "29 天前的条目仍然保留")

        // 11. 到期预警
        let soonItem = ClipItem(kind: .text, text: "2 天后过期", createdAt: base.addingTimeInterval(-28 * 86400))
        store.add(soonItem)
        report.check(store.expiringSoon.contains(where: { $0.id == soonItem.id }),
                     "expiringSoon 命中 2 天后到期的条目",
                     detail: "共命中 \(store.expiringSoon.count) 条")

        if let warning = store.pendingWarningText()
        {
            report.check(!warning.isEmpty, "pendingWarningText 非空", detail: warning)
        }
        else
        {
            report.check(false, "pendingWarningText 非空")
        }

        store.setPermanent(id: soonItem.id, true)
        report.check(!store.expiringSoon.contains(where: { $0.id == soonItem.id }), "永久保留的条目不参与预警")
        store.setPermanent(id: soonItem.id, false)

        store.setRetention(id: soonItem.id, days: 365)
        report.check(!store.expiringSoon.contains(where: { $0.id == soonItem.id }), "单条保留期能覆盖全局设置")
        store.setRetention(id: soonItem.id, days: nil)

        let permanentItem = ClipItem(kind: .text,
                                     text: "100 天前的永久记录",
                                     createdAt: base.addingTimeInterval(-100 * 86400),
                                     isPermanent: true)
        store.add(permanentItem)
        report.check(store.runExpirySweep() == 0 && store.items.contains(where: { $0.id == permanentItem.id }),
                     "永久保留条目不会被清理")

        // 12. 写回剪贴板（结束后还原用户原来的文本剪贴板）
        let pasteboard = NSPasteboard.general
        let savedClipboard = pasteboard.string(forType: .string)

        store.copyToPasteboard(editedItem)
        report.check(pasteboard.string(forType: .string) == "你好，CutBoardar（已改）",
                     "copyToPasteboard 写回文本",
                     detail: pasteboard.string(forType: .string) ?? "nil")
        report.check(store.lastWrittenChangeCount == pasteboard.changeCount, "写回后记录 lastWrittenChangeCount")

        store.copyToPasteboard(imageItem)
        report.check(pasteboard.data(forType: .png) != nil, "copyToPasteboard 写回图片 png 数据")

        // 13. 持久化文件是合法 JSON
        store.flush()

        if let data = try? Data(contentsOf: store.storeFileURL),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            report.check(true, "store.json 是合法 JSON 对象")
            report.check(object["settings"] != nil, "store.json 含 settings 字段")

            let jsonItems = object["items"] as? [[String: Any]]
            report.check(jsonItems?.count == store.items.count,
                         "store.json 中条目数与内存一致",
                         detail: "json=\(jsonItems?.count ?? -1) memory=\(store.items.count)")
        }
        else
        {
            report.check(false, "store.json 是合法 JSON 对象")
        }

        // 14. 单条删除连同图片
        let imageName = imageItem.imageFileName
        store.delete(id: imageItem.id)
        report.check(!store.items.contains(where: { $0.id == imageItem.id }), "delete(id:) 删除条目")

        if let imageName
        {
            let imagePath = store.imagesDirectory.appendingPathComponent(imageName).path
            report.check(!fileManager.fileExists(atPath: imagePath), "delete(id:) 同时删除图片文件")
        }

        // 15. maxItems 上限
        let countBeforeTrim = store.items.count
        store.settings.maxItems = 3
        report.check(store.items.count == min(countBeforeTrim, 3),
                     "settings.maxItems 调小后裁掉最旧条目",
                     detail: "\(countBeforeTrim) → \(store.items.count)")
        store.settings.maxItems = 2000

        // 16. 清空
        store.deleteAll()
        report.check(store.items.isEmpty, "deleteAll 清空内存条目")

        let remainingImages = (try? fileManager.contentsOfDirectory(atPath: store.imagesDirectory.path)) ?? []
        report.check(remainingImages.isEmpty, "deleteAll 清理 images/ 目录")

        let emptyReload = ClipStore(dataDirectory: root)
        report.check(emptyReload.items.isEmpty, "deleteAll 后重新加载仍是空仓库")

        // 17. 监听器（不启动 runloop，只验证生命周期）
        let monitor = ClipboardMonitor(store: store)
        report.check(!monitor.isRunning, "监听器初始为停止状态")
        monitor.start()
        report.check(monitor.isRunning, "监听器 start 后处于运行状态")
        monitor.stop()
        report.check(!monitor.isRunning, "监听器 stop 后回到停止状态")

        // 18. 监听器实际捕获（直接操作真实剪贴板，全部结束后还原）
        let monitorStore = ClipStore(dataDirectory: root.appendingPathComponent("monitor", isDirectory: true))
        let liveMonitor = ClipboardMonitor(store: monitorStore)
        liveMonitor.start()

        pasteboard.clearContents()
        pasteboard.setString("来自其他应用的复制", forType: .string)
        liveMonitor.pollOnce()
        report.check(monitorStore.items.first?.text == "来自其他应用的复制",
                     "监听器捕获外部写入的文本",
                     detail: monitorStore.items.first?.text ?? "nil")

        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
        liveMonitor.pollOnce()
        report.check(monitorStore.items.first?.kind == .image,
                     "监听器捕获图片",
                     detail: String(describing: monitorStore.items.first?.kind))

        pasteboard.clearContents()
        pasteboard.writeObjects([NSURL(fileURLWithPath: "/tmp/cutboardar-selftest/报告.txt")])
        liveMonitor.pollOnce()
        report.check(monitorStore.items.first?.kind == .file,
                     "监听器捕获文件路径",
                     detail: monitorStore.items.first?.text ?? "nil")

        let countBeforeSelfWrite = monitorStore.items.count
        monitorStore.copyToPasteboard(monitorStore.items[0])
        liveMonitor.pollOnce()
        report.check(monitorStore.items.count == countBeforeSelfWrite,
                     "本应用写回剪贴板不会被重复记录",
                     detail: "\(countBeforeSelfWrite) → \(monitorStore.items.count)")

        liveMonitor.stop()

        // 19. 通知封装在无 Bundle 环境下不崩
        report.check(ClipNotifier.isSupported == false, "命令行环境判定为不支持系统通知（避免 ObjC 异常）")
        ClipNotifier.post(title: "自检", body: "无 Bundle 时不应崩溃")
        ClipNotifier.requestAuthorization()
        report.check(true, "无 Bundle 时调用通知接口不崩溃")

        // 20. 还原用户原来的文本剪贴板
        pasteboard.clearContents()
        if let savedClipboard
        {
            pasteboard.setString(savedClipboard, forType: .string)
        }

        return report.finish()

    }

}
