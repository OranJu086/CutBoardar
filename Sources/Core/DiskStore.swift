import Foundation

// 单文件落盘结构：设置 + 全部条目
struct CBPersistedState: Codable
{

    static let currentVersion = 1

    var version: Int
    var settings: AppSettings
    var items: [ClipItem]

    init(settings: AppSettings, items: [ClipItem])
    {

        self.version = CBPersistedState.currentVersion
        self.settings = settings
        self.items = items

    }

}

// 负责目录、图片文件与 JSON 读写的薄层
final class CBDiskStore
{

    let root: URL

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(root: URL, fileManager: FileManager = .default)
    {

        self.root = root.standardizedFileURL
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // 用 Double 而不是 ISO 字符串：ISO8601 只保留到秒或毫秒，同一秒内创建的多条记录
        // 会丢失先后顺序；这里直接写 Date 的内部表示（自 2001 起的秒数），可以逐位精确往返
        encoder.dateEncodingStrategy = .custom
        {
            date, encoder in

            var container = encoder.singleValueContainer()
            try container.encode(date.timeIntervalSinceReferenceDate)
        }
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom
        {
            decoder in

            let container = try decoder.singleValueContainer()
            return Date(timeIntervalSinceReferenceDate: try container.decode(Double.self))
        }
        self.decoder = decoder

    }

    var imagesDirectory: URL
    {
        return root.appendingPathComponent("images", isDirectory: true)
    }

    var stateFileURL: URL
    {
        return root.appendingPathComponent("store.json")
    }

    // 建立数据目录与 images 子目录
    func ensureDirectories() throws
    {

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

    }

    // 函数：读取落盘状态
    // 返回值：状态对象；文件不存在或损坏时返回 nil（宁可空启动，也不要崩）
    func load() -> CBPersistedState?
    {

        guard let data = try? Data(contentsOf: stateFileURL), !data.isEmpty else
        {
            return nil
        }

        return try? decoder.decode(CBPersistedState.self, from: data)

    }

    // 函数：原子写入状态
    // 说明：先写临时文件，再用 replaceItemAt 顶替，避免中途失败留下半截 JSON
    func save(_ state: CBPersistedState) throws
    {

        try ensureDirectories()

        let data = try encoder.encode(state)
        let temporaryURL = root.appendingPathComponent("store-\(UUID().uuidString).tmp.json")
        try data.write(to: temporaryURL, options: .atomic)

        if fileManager.fileExists(atPath: stateFileURL.path)
        {
            _ = try fileManager.replaceItemAt(stateFileURL, withItemAt: temporaryURL)
        }
        else
        {
            try fileManager.moveItem(at: temporaryURL, to: stateFileURL)
        }

    }

    func imageURL(named name: String) -> URL
    {

        return imagesDirectory.appendingPathComponent(name)

    }

    func readImage(named name: String) -> Data?
    {

        return try? Data(contentsOf: imageURL(named: name))

    }

    // 写入一张图片并返回落盘位置
    @discardableResult
    func writeImage(_ data: Data, name: String) throws -> URL
    {

        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

        let url = imageURL(named: name)
        try data.write(to: url, options: .atomic)

        return url

    }

    func deleteImage(named name: String)
    {

        try? fileManager.removeItem(at: imageURL(named: name))

    }

    func deleteAllImages()
    {

        guard let entries = try? fileManager.contentsOfDirectory(at: imagesDirectory,
                                                               includingPropertiesForKeys: nil)
        else
        {
            return
        }

        for entry in entries
        {
            try? fileManager.removeItem(at: entry)
        }

    }

}
