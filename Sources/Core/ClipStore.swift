import Foundation
import AppKit
import Combine

// 剪贴板捕获结果：监听器把读到的内容交给 store
struct ClipboardCapture
{

    var kind: ClipKind
    var text: String
    var filePaths: [String]
    var imageData: Data?

    static func text(_ value: String) -> ClipboardCapture
    {

        return ClipboardCapture(kind: .text, text: value, filePaths: [], imageData: nil)

    }

    static func files(_ paths: [String]) -> ClipboardCapture
    {

        return ClipboardCapture(kind: .file, text: paths.joined(separator: "\n"), filePaths: paths, imageData: nil)

    }

    static func image(_ data: Data) -> ClipboardCapture
    {

        return ClipboardCapture(kind: .image, text: "", filePaths: [], imageData: data)

    }

}

// 剪贴记录仓库：内存数据 + 防抖持久化 + 保留策略
@MainActor
final class ClipStore: ObservableObject
{

    static let shared = ClipStore()

    // 始终新 → 旧
    @Published private(set) var items: [ClipItem] = []

    @Published var settings: AppSettings
    {
        didSet
        {
            handleSettingsChange(from: oldValue)
        }
    }

    // 最近一次由本应用写回剪贴板时的 changeCount，监听器据此跳过自身写入
    private(set) var lastWrittenChangeCount: Int = -1

    let disk: CBDiskStore

    private var pendingSave: DispatchWorkItem?

    private static let saveDebounceInterval: TimeInterval = 0.3

    // 函数：构造仓库并载入磁盘数据
    // 参数：dataDirectory —— 数据根目录；nil 时按 CoreDataPaths 解析（支持环境变量覆盖）
    init(dataDirectory: URL? = nil)
    {

        let root = dataDirectory ?? CoreDataPaths.dataDirectory()
        self.disk = CBDiskStore(root: root)
        self.settings = AppSettings()

        do
        {
            try disk.ensureDirectories()
        }
        catch
        {
            print("[CutBoardar] 数据目录创建失败: \(error.localizedDescription)")
        }

        if let state = disk.load()
        {
            self.settings = state.settings
            self.items = ClipStore.sortedNewestFirst(state.items)
        }

        trimIfNeeded()

    }

    // MARK: - 只读信息

    var dataDirectory: URL
    {
        return disk.root
    }

    var storeFileURL: URL
    {
        return disk.stateFileURL
    }

    var imagesDirectory: URL
    {
        return disk.imagesDirectory
    }

    func item(with id: UUID) -> ClipItem?
    {

        return items.first { $0.id == id }

    }

    // 函数：按关键字过滤（纯函数，不改动数据）
    // 参数：keyword —— 关键字，空串返回全部
    // 返回值：命中关键字的条目，顺序与新 → 旧一致
    func filtered(keyword: String) -> [ClipItem]
    {

        let needle = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        if needle.isEmpty
        {
            return items
        }

        return items.filter { $0.matches(keyword: needle) }

    }

    // 函数：图片条目的落盘地址
    // 返回值：文件存在时返回 URL；非图片或文件缺失返回 nil
    func imageURL(for item: ClipItem) -> URL?
    {

        guard let name = item.imageFileName, !name.isEmpty else
        {
            return nil
        }

        let url = disk.imageURL(named: name)

        if FileManager.default.fileExists(atPath: url.path)
        {
            return url
        }

        return nil

    }

    // MARK: - 新增

    // 函数：新增一条记录（与最新一条内容相同则跳过）
    func add(_ item: ClipItem)
    {

        if let candidate = signature(of: item),
           let newest = items.first,
           signature(of: newest) == candidate
        {
            return
        }

        insertSorted(item)
        trimIfNeeded()
        scheduleSave()

    }

    // 函数：新增一条文本记录
    // 返回值：新建的条目；被去重或内容为空时返回 nil
    @discardableResult
    func addText(_ text: String) -> ClipItem?
    {

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return nil
        }

        let item = ClipItem(kind: .text, text: text, byteSize: text.utf8.count)
        add(item)

        return self.item(with: item.id)

    }

    // 函数：新增一条文件路径记录
    // 返回值：新建的条目；被去重或路径为空时返回 nil
    @discardableResult
    func addFile(_ path: String) -> ClipItem?
    {

        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty
        {
            return nil
        }

        let item = ClipItem(kind: .file, text: trimmed, byteSize: ClipStore.fileSize(atPath: trimmed))
        add(item)

        return self.item(with: item.id)

    }

    // 函数：新增一条图片记录，图片统一转成 png 落盘
    // 参数：data —— 原始图片数据（png / tiff 等）
    // 返回值：新建的条目；去重、写盘失败或数据无法解析时返回 nil
    @discardableResult
    func addImage(_ data: Data, note: String = "", createdAt: Date = Date()) -> ClipItem?
    {

        guard let png = CBImageCodec.pngData(from: data) else
        {
            print("[CutBoardar] 图片数据无法转换成 png，已忽略")
            return nil
        }

        let candidate = "image:" + CBHash.fingerprint(png)

        if let newest = items.first, signature(of: newest) == candidate
        {
            return newest
        }

        let fileName = "\(UUID().uuidString).png"

        do
        {
            try disk.writeImage(png, name: fileName)
        }
        catch
        {
            print("[CutBoardar] 图片写入失败: \(error.localizedDescription)")
            return nil
        }

        let item = ClipItem(kind: .image,
                            text: "",
                            note: note,
                            createdAt: createdAt,
                            imageFileName: fileName,
                            byteSize: png.count)

        insertSorted(item)
        trimIfNeeded()
        scheduleSave()

        return item

    }

    // 函数：接收监听器捕获的内容
    // 说明：store 负责写入；调用方的 onCapture 只应作为“已捕获”通知，不要再重复 add
    func accept(_ capture: ClipboardCapture)
    {

        switch capture.kind
        {
        case .text:
            addText(capture.text)

        case .file:
            for path in capture.filePaths
            {
                addFile(path)
            }

        case .image:
            if let data = capture.imageData
            {
                addImage(data)
            }
        }

    }

    // MARK: - 修改 / 删除

    // 函数：修改正文与备注，传 nil 表示该项不变
    func update(id: UUID, text: String? = nil, note: String? = nil)
    {

        guard let index = items.firstIndex(where: { $0.id == id }) else
        {
            return
        }

        var item = items[index]

        if let text
        {
            item.text = text
            if item.kind == .text
            {
                item.byteSize = text.utf8.count
            }
        }

        if let note
        {
            item.note = note
        }

        item.refreshDisplay()
        items[index] = item
        scheduleSave()

    }

    func delete(id: UUID)
    {

        guard let index = items.firstIndex(where: { $0.id == id }) else
        {
            return
        }

        let removed = items.remove(at: index)
        deleteImageFile(of: removed)
        scheduleSave()

    }

    func deleteAll()
    {

        items.removeAll()
        disk.deleteAllImages()
        saveNow()

    }

    func setRetention(id: UUID, days: Int?)
    {

        guard let index = items.firstIndex(where: { $0.id == id }) else
        {
            return
        }

        items[index].retentionDays = days
        scheduleSave()

    }

    func setPermanent(id: UUID, _ flag: Bool)
    {

        guard let index = items.firstIndex(where: { $0.id == id }) else
        {
            return
        }

        items[index].isPermanent = flag
        scheduleSave()

    }

    // MARK: - 保留策略

    // 函数：条目实际生效的保留天数
    // 返回值：永久条目或天数 <= 0 时返回 nil（不过期）；否则返回天数
    func effectiveRetentionDays(for item: ClipItem) -> Int?
    {

        if item.isPermanent
        {
            return nil
        }

        let days = item.retentionDays ?? settings.retentionDays

        if days <= 0
        {
            return nil
        }

        return days

    }

    // 函数：条目到期时刻
    // 返回值：永不过期时返回 nil
    func expiryDate(for item: ClipItem) -> Date?
    {

        guard let days = effectiveRetentionDays(for: item) else
        {
            return nil
        }

        return item.createdAt.addingTimeInterval(TimeInterval(days) * 86400.0)

    }

    // 未来 warnDaysBefore 天内到期、且还没过期的条目
    var expiringSoon: [ClipItem]
    {

        let now = Date()
        let horizon = now.addingTimeInterval(TimeInterval(max(0, settings.warnDaysBefore)) * 86400.0)

        return items.filter
        {
            guard let expiry = expiryDate(for: $0) else
            {
                return false
            }

            return expiry > now && expiry <= horizon
        }

    }

    // 函数：清理已过期条目（连同图片文件）
    // 返回值：删除的条数
    @discardableResult
    func runExpirySweep() -> Int
    {

        let now = Date()
        var kept: [ClipItem] = []
        var removed: [ClipItem] = []

        for item in items
        {
            if let expiry = expiryDate(for: item), expiry <= now
            {
                removed.append(item)
            }
            else
            {
                kept.append(item)
            }
        }

        if removed.isEmpty
        {
            return 0
        }

        items = kept

        for item in removed
        {
            deleteImageFile(of: item)
        }

        saveNow()

        return removed.count

    }

    // 函数：生成到期预警文案
    // 返回值：没有即将到期的条目时返回 nil
    func pendingWarningText() -> String?
    {

        let soon = expiringSoon

        if soon.isEmpty
        {
            return nil
        }

        let days = max(0, settings.warnDaysBefore)
        let nearest = soon.compactMap { expiryDate(for: $0) }.min()
        var text = "有 \(soon.count) 条剪贴记录将在 \(days) 天内过期"

        if let nearest
        {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日 HH:mm"
            text += "，最早 \(formatter.string(from: nearest)) 到期"
        }

        text += "。可把需要的记录设为永久保留。"

        return text

    }

    // 函数：尽力发一条到期预警的系统通知
    func notifyExpiringSoon()
    {

        guard settings.notificationsEnabled, let text = pendingWarningText() else
        {
            return
        }

        ClipNotifier.post(title: "剪贴记录即将过期", body: text)

    }

    // MARK: - 剪贴板写回

    // 函数：把一条记录写回系统剪贴板
    // 说明：写完记录 changeCount，监听器据此跳过，不会把这次写回又记一条
    func copyToPasteboard(_ item: ClipItem)
    {

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind
        {
        case .text, .file:
            pasteboard.setString(item.text, forType: .string)

        case .image:
            if let url = imageURL(for: item), let data = try? Data(contentsOf: url)
            {
                let boardItem = NSPasteboardItem()
                boardItem.setData(data, forType: .png)

                if let representation = NSBitmapImageRep(data: data),
                   let tiff = representation.tiffRepresentation
                {
                    boardItem.setData(tiff, forType: .tiff)
                }

                pasteboard.writeObjects([boardItem])
            }
        }

        lastWrittenChangeCount = pasteboard.changeCount

    }

    // MARK: - 持久化

    // 函数：立即写盘并取消待执行的防抖任务
    func saveNow()
    {

        pendingSave?.cancel()
        pendingSave = nil

        let state = CBPersistedState(settings: settings, items: items)

        do
        {
            try disk.save(state)
        }
        catch
        {
            print("[CutBoardar] 保存失败: \(error.localizedDescription)")
        }

    }

    // saveNow 的别名，便于调用方表达“把未落盘的改动刷掉”
    func flush()
    {

        saveNow()

    }

    // 函数：从磁盘重新载入（外部改过文件或需要放弃内存改动时用）
    func reloadFromDisk()
    {

        guard let state = disk.load() else
        {
            return
        }

        settings = state.settings
        items = ClipStore.sortedNewestFirst(state.items)

    }

    // MARK: - 内部实现

    private func handleSettingsChange(from oldValue: AppSettings)
    {

        if oldValue.maxItems != settings.maxItems
        {
            trimIfNeeded()
        }

        scheduleSave()

    }

    // 防抖保存：0.3 秒内的连续改动只落盘一次
    private func scheduleSave()
    {

        pendingSave?.cancel()

        let work = DispatchWorkItem
        {
            [weak self] in

            MainActor.assumeIsolated
            {
                self?.saveNow()
            }
        }

        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + ClipStore.saveDebounceInterval, execute: work)

    }

    // 函数：插入到正确位置，保持新 → 旧
    private func insertSorted(_ item: ClipItem)
    {

        let index = items.firstIndex { $0.createdAt <= item.createdAt } ?? items.count
        items.insert(item, at: index)

    }

    // 函数：压到 maxItems 上限，多出来的最旧条目连同图片一起删除
    private func trimIfNeeded()
    {

        let limit = max(1, settings.maxItems)

        if items.count <= limit
        {
            return
        }

        let overflow = items.count - limit
        let removed = items.suffix(overflow)

        for item in removed
        {
            deleteImageFile(of: item)
        }

        items.removeLast(overflow)

    }

    private func deleteImageFile(of item: ClipItem)
    {

        guard let name = item.imageFileName, !name.isEmpty else
        {
            return
        }

        disk.deleteImage(named: name)

    }

    // 函数：内容指纹
    // 说明：文本/文件看正文字节，图片看落盘后的 png 字节
    // 返回值：图片文件缺失时返回 nil，此时不做去重
    private func signature(of item: ClipItem) -> String?
    {

        switch item.kind
        {
        case .text, .file:
            return item.kind.rawValue + ":" + CBHash.fingerprint(item.text)

        case .image:
            guard let name = item.imageFileName, let data = disk.readImage(named: name) else
            {
                return nil
            }

            return "image:" + CBHash.fingerprint(data)
        }

    }

    private static func sortedNewestFirst(_ list: [ClipItem]) -> [ClipItem]
    {

        return list.sorted { $0.createdAt > $1.createdAt }

    }

    private static func fileSize(atPath path: String) -> Int
    {

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber
        else
        {
            return 0
        }

        return size.intValue

    }

}
