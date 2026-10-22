import Foundation

// 剪贴记录的类型：文本 / 图片 / 文件路径
enum ClipKind: String, Codable, CaseIterable
{

    case text
    case image
    case file

    // 中文名，供界面与通知文案直接使用
    var displayName: String
    {
        switch self
        {
        case .text:
            return "文本"
        case .image:
            return "图片"
        case .file:
            return "文件"
        }
    }

    // SF Symbols 名称，供界面层取图标
    var symbolName: String
    {
        switch self
        {
        case .text:
            return "doc.text"
        case .image:
            return "photo"
        case .file:
            return "folder"
        }
    }

}

// 一条剪贴记录
struct ClipItem: Identifiable, Codable, Equatable
{

    var id: UUID
    var kind: ClipKind
    var text: String            // 文本内容；file 类型时是路径
    var note: String            // 用户备注
    var createdAt: Date
    var imageFileName: String?  // 相对 images/ 目录的文件名
    var byteSize: Int
    var isPermanent: Bool
    var retentionDays: Int?     // nil 表示沿用全局设置
    var displayTitle: String    // 列表/卡片上的单行摘要
    var displaySubtitle: String // 列表/卡片上的副标题

    // 函数：构造一条记录
    // 参数：displayTitle / displaySubtitle —— 省略时按 kind 与 text 自动生成
    // 返回值：ClipItem 实例
    init(id: UUID = UUID(),
         kind: ClipKind,
         text: String = "",
         note: String = "",
         createdAt: Date = Date(),
         imageFileName: String? = nil,
         byteSize: Int = 0,
         isPermanent: Bool = false,
         retentionDays: Int? = nil,
         displayTitle: String? = nil,
         displaySubtitle: String? = nil)
    {

        self.id = id
        self.kind = kind
        self.text = text
        self.note = note
        self.createdAt = createdAt
        self.imageFileName = imageFileName
        self.byteSize = byteSize
        self.isPermanent = isPermanent
        self.retentionDays = retentionDays
        self.displayTitle = displayTitle ?? ClipItem.makeTitle(kind: kind, text: text, byteSize: byteSize)
        self.displaySubtitle = displaySubtitle ?? ClipItem.makeSubtitle(kind: kind, text: text, byteSize: byteSize)

    }

    // 正文改动后同步刷新两个摘要字段
    mutating func refreshDisplay()
    {

        displayTitle = ClipItem.makeTitle(kind: kind, text: text, byteSize: byteSize)
        displaySubtitle = ClipItem.makeSubtitle(kind: kind, text: text, byteSize: byteSize)

    }

    // 关键字匹配：正文、备注、两个摘要字段任一命中即可（忽略大小写）
    func matches(keyword: String) -> Bool
    {

        let needle = keyword.lowercased()

        if needle.isEmpty
        {
            return true
        }

        if text.lowercased().contains(needle)
        {
            return true
        }

        if note.lowercased().contains(needle)
        {
            return true
        }

        if displayTitle.lowercased().contains(needle)
        {
            return true
        }

        return displaySubtitle.lowercased().contains(needle)

    }

    // 文件类型的路径名，其它类型返回空串
    var fileName: String
    {

        if kind != .file
        {
            return ""
        }

        return (text as NSString).lastPathComponent

    }

    // 函数：生成列表摘要（单行）
    static func makeTitle(kind: ClipKind, text: String, byteSize: Int) -> String
    {

        switch kind
        {
        case .text:
            let firstLine = text.split(whereSeparator: { $0.isNewline }).first.map(String.init) ?? ""
            let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty
            {
                return "（空白文本）"
            }
            return truncated(trimmed, limit: 80)

        case .image:
            return "图片 \(formatBytes(byteSize))"

        case .file:
            let name = (text as NSString).lastPathComponent
            if name.isEmpty
            {
                return "文件"
            }
            return name
        }

    }

    // 函数：生成副标题（类型 + 体量/位置）
    static func makeSubtitle(kind: ClipKind, text: String, byteSize: Int) -> String
    {

        switch kind
        {
        case .text:
            let lineCount = text.split(whereSeparator: { $0.isNewline }).count
            if lineCount > 1
            {
                return "文本 · \(text.count) 字 · \(lineCount) 行"
            }
            return "文本 · \(text.count) 字"

        case .image:
            return "图片 · \(formatBytes(byteSize))"

        case .file:
            let parent = (text as NSString).deletingLastPathComponent
            if parent.isEmpty
            {
                return "文件"
            }
            return "文件 · \(parent)"
        }

    }

    // 函数：把字节数格式化成人看的单位
    static func formatBytes(_ bytes: Int) -> String
    {

        if bytes < 1024
        {
            return "\(bytes) B"
        }

        let kiloBytes = Double(bytes) / 1024.0
        if kiloBytes < 1024.0
        {
            return String(format: "%.1f KB", kiloBytes)
        }

        let megaBytes = kiloBytes / 1024.0
        if megaBytes < 1024.0
        {
            return String(format: "%.1f MB", megaBytes)
        }

        return String(format: "%.2f GB", megaBytes / 1024.0)

    }

    // 函数：按字符数截断并加省略号
    static func truncated(_ value: String, limit: Int) -> String
    {

        if value.count <= limit
        {
            return value
        }

        return String(value.prefix(limit)) + "…"

    }

    // 便捷构造：文本
    static func makeText(_ text: String, at date: Date = Date()) -> ClipItem
    {

        return ClipItem(kind: .text, text: text, createdAt: date, byteSize: text.utf8.count)

    }

    // 便捷构造：文件路径
    static func makeFile(_ path: String, at date: Date = Date()) -> ClipItem
    {

        return ClipItem(kind: .file, text: path, createdAt: date)

    }

    // 便捷构造：图片（只登记文件名，落盘由 ClipStore 负责）
    static func makeImage(fileName: String, byteSize: Int, at date: Date = Date()) -> ClipItem
    {

        return ClipItem(kind: .image, text: "", createdAt: date, imageFileName: fileName, byteSize: byteSize)

    }

}

// 列表展示方式
enum ViewMode: String, Codable, CaseIterable
{

    case grid
    case list
    case split

    var displayName: String
    {
        switch self
        {
        case .grid:
            return "网格"
        case .list:
            return "列表"
        case .split:
            return "分栏"
        }
    }

}

// 全局设置
struct AppSettings: Codable, Equatable
{

    var retentionDays: Int      // 全局默认保留天数
    var warnDaysBefore: Int     // 到期前几天开始预警
    var viewMode: ViewMode
    var pollInterval: Double    // 剪贴板轮询间隔（秒）
    var maxItems: Int           // 最多保留条数
    var notificationsEnabled: Bool

    // 函数：构造设置，顺带把越界值夹到合法范围
    init(retentionDays: Int = 30,
         warnDaysBefore: Int = 3,
         viewMode: ViewMode = .grid,
         pollInterval: Double = 0.4,
         maxItems: Int = 2000,
         notificationsEnabled: Bool = true)
    {

        self.retentionDays = max(1, retentionDays)
        self.warnDaysBefore = max(0, warnDaysBefore)
        self.viewMode = viewMode
        self.pollInterval = min(max(pollInterval, 0.05), 5.0)
        self.maxItems = max(1, maxItems)
        self.notificationsEnabled = notificationsEnabled

    }

    // 解码容错：字段缺失或越界都回落到默认值，避免一份坏配置让应用起不来
    init(from decoder: Decoder) throws
    {

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings()

        self.init(retentionDays: try container.decodeIfPresent(Int.self, forKey: .retentionDays) ?? fallback.retentionDays,
                  warnDaysBefore: try container.decodeIfPresent(Int.self, forKey: .warnDaysBefore) ?? fallback.warnDaysBefore,
                  viewMode: try container.decodeIfPresent(ViewMode.self, forKey: .viewMode) ?? fallback.viewMode,
                  pollInterval: try container.decodeIfPresent(Double.self, forKey: .pollInterval) ?? fallback.pollInterval,
                  maxItems: try container.decodeIfPresent(Int.self, forKey: .maxItems) ?? fallback.maxItems,
                  notificationsEnabled: try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? fallback.notificationsEnabled)

    }

    private enum CodingKeys: String, CodingKey
    {
        case retentionDays
        case warnDaysBefore
        case viewMode
        case pollInterval
        case maxItems
        case notificationsEnabled
    }

}
