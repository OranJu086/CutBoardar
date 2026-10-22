import Foundation
import AppKit

// 轮询 NSPasteboard 的 changeCount，把新内容交给 store
@MainActor
final class ClipboardMonitor
{

    weak var store: ClipStore?

    // 已由 store 接管写入时，这个回调只作为“已捕获”通知，不要在回调里再 add
    var onCapture: ((ClipboardCapture) -> Void)?

    private(set) var isRunning = false
    private(set) var lastChangeCount: Int

    private let pasteboard: NSPasteboard
    private var timer: Timer?

    init(store: ClipStore? = nil, pasteboard: NSPasteboard = .general)
    {

        self.store = store
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount

    }

    func start()
    {

        if isRunning
        {
            return
        }

        lastChangeCount = pasteboard.changeCount
        isRunning = true
        scheduleTick()

    }

    func stop()
    {

        isRunning = false
        timer?.invalidate()
        timer = nil

    }

    // 函数：轮询一次
    // 说明：changeCount 没变直接返回；是本应用自己写回的内容也跳过
    func pollOnce()
    {

        let currentChangeCount = pasteboard.changeCount

        if currentChangeCount == lastChangeCount
        {
            return
        }

        lastChangeCount = currentChangeCount

        if let store, currentChangeCount == store.lastWrittenChangeCount
        {
            return
        }

        guard let capture = ClipboardMonitor.readCapture(from: pasteboard) else
        {
            return
        }

        if let store
        {
            store.accept(capture)
        }

        onCapture?(capture)

    }

    // 函数：从剪贴板读出内容
    // 说明：优先级为 文件 > 图片 > 文本；从 Finder 复制文件时剪贴板同时带 fileURL 与字符串
    static func readCapture(from pasteboard: NSPasteboard) -> ClipboardCapture?
    {

        let fileOnlyOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: fileOnlyOptions) as? [URL]
        {
            let paths = urls.filter { $0.isFileURL }.map { $0.path }
            if !paths.isEmpty
            {
                return .files(paths)
            }
        }

        if let png = pasteboard.data(forType: .png), !png.isEmpty
        {
            return .image(png)
        }

        if let tiff = pasteboard.data(forType: .tiff), !tiff.isEmpty
        {
            return .image(tiff)
        }

        if let string = pasteboard.string(forType: .string), !string.isEmpty
        {
            return .text(string)
        }

        return nil

    }

    // 每次只用一次性定时器，这样 settings.pollInterval 改了能立刻生效
    private func scheduleTick()
    {

        timer?.invalidate()

        let interval = max(0.05, store?.settings.pollInterval ?? 0.4)
        let tickTimer = Timer(timeInterval: interval, repeats: false)
        {
            [weak self] _ in

            MainActor.assumeIsolated
            {
                self?.tick()
            }
        }

        RunLoop.main.add(tickTimer, forMode: .common)
        timer = tickTimer

    }

    private func tick()
    {

        guard isRunning else
        {
            return
        }

        pollOnce()
        scheduleTick()

    }

}
