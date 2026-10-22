import Foundation
import AppKit

// 内容指纹：FNV-1a 64 位
// 用它而不是 Hasher，是因为 Hasher 每个进程种子不同，跨启动比较会失效
enum CBHash
{

    // 函数：计算一段字节的稳定指纹
    // 参数：data —— 参与计算的字节
    // 返回值：16 位十六进制字符串，同一输入永远得到同一结果
    static func fingerprint(_ data: Data) -> String
    {

        var value: UInt64 = 0xcbf2_9ce4_8422_2325

        for byte in data
        {
            value ^= UInt64(byte)
            value = value &* 0x0000_0100_0000_01b3
        }

        return String(format: "%016llx", value)

    }

    // 函数：计算一段文本的稳定指纹
    static func fingerprint(_ text: String) -> String
    {

        return fingerprint(Data(text.utf8))

    }

}

// 数据目录解析
enum CoreDataPaths
{

    static let environmentKey = "CUTBOARDAR_DATA_DIR"

    // 函数：解析数据根目录
    // 说明：优先环境变量（自检用），否则 ~/Library/Application Support/CutBoardar/
    // 返回值：标准化后的目录 URL
    static func dataDirectory() -> URL
    {

        if let pointer = getenv(environmentKey)
        {
            let raw = String(cString: pointer).trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty
            {
                let expanded = (raw as NSString).expandingTildeInPath
                return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
            }
        }

        if let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        {
            return base.appendingPathComponent("CutBoardar", isDirectory: true)
        }

        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return home.appendingPathComponent("Library/Application Support/CutBoardar", isDirectory: true)

    }

}

// 图片格式统一：一律转成 png 落盘
enum CBImageCodec
{

    // 函数：把任意 AppKit 认识的图片数据转成 png
    // 参数：data —— 原始数据（png / tiff / jpeg 等）
    // 返回值：png 字节；无法解析时返回 nil
    static func pngData(from data: Data) -> Data?
    {

        guard !data.isEmpty else
        {
            return nil
        }

        if let representation = NSBitmapImageRep(data: data),
           let png = representation.representation(using: .png, properties: [:])
        {
            return png
        }

        if let image = NSImage(data: data),
           let tiff = image.tiffRepresentation,
           let representation = NSBitmapImageRep(data: tiff)
        {
            return representation.representation(using: .png, properties: [:])
        }

        return nil

    }

    // 函数：生成一张小图（只给自检用）
    // 参数：width / height —— 像素尺寸
    // 返回值：png 字节；创建失败返回 nil
    // 说明：直接写像素字节，不走 NSColor —— 无显示环境里命名颜色会刷一堆色彩空间告警
    static func makeTestPNG(width: Int, height: Int) -> Data?
    {

        guard width > 0, height > 0,
              let representation = NSBitmapImageRep(bitmapDataPlanes: nil,
                                                    pixelsWide: width,
                                                    pixelsHigh: height,
                                                    bitsPerSample: 8,
                                                    samplesPerPixel: 4,
                                                    hasAlpha: true,
                                                    isPlanar: false,
                                                    colorSpaceName: .deviceRGB,
                                                    bytesPerRow: 0,
                                                    bitsPerPixel: 0),
              let pixels = representation.bitmapData
        else
        {
            return nil
        }

        let samplesPerPixel = representation.samplesPerPixel
        let bytesPerRow = representation.bytesPerRow

        for y in 0 ..< height
        {
            for x in 0 ..< width
            {
                let offset = y * bytesPerRow + x * samplesPerPixel
                pixels[offset] = 0x33
                pixels[offset + 1] = 0x99
                pixels[offset + 2] = 0xCC
                pixels[offset + 3] = 0xFF
            }
        }

        return representation.representation(using: .png, properties: [:])

    }

}
