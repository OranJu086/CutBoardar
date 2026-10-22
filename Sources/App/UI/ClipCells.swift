import AppKit
import SwiftUI

enum CBTime
{
    static func relative(_ date: Date, now: Date = Date()) -> String
    {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return "刚刚" }
        if seconds < 3_600 { return "\(Int(seconds / 60)) 分钟前" }
        if seconds < 86_400 { return "\(Int(seconds / 3_600)) 小时前" }
        let days = Int(seconds / 86_400)
        if days == 1 { return "昨天" }
        if days < 7 { return "\(days) 天前" }
        return shortDate(date)
    }

    static func shortDate(_ date: Date) -> String
    {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"
        return formatter.string(from: date)
    }

    static func absolute(_ date: Date) -> String
    {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月 d 日 HH:mm"
        return formatter.string(from: date)
    }

    static func byteSize(_ bytes: Int) -> String
    {
        guard bytes > 0 else { return "—" }
        if bytes < 1_024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", Double(bytes) / 1_024) }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }
}

enum CBSummaries
{
    static func oneLine(_ item: ClipItem) -> String
    {
        switch item.cbKind
        {
        case .image:
            let title = item.cbTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? "图片" : title
        case .file:
            let title = item.cbTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? "文件" : title
        case .text:
            let flat = item.cbText.replacingOccurrences(of: "\n", with: " ")
            let trimmed = flat.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "（空文本）" : trimmed
        }
    }
}

enum KindStyle
{
    static func symbol(_ kind: ClipKind) -> String
    {
        switch kind
        {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    static func title(_ kind: ClipKind) -> String
    {
        switch kind
        {
        case .text: return "文本"
        case .image: return "图片"
        case .file: return "文件"
        }
    }
}

struct KindBadge: View
{
    let kind: ClipKind

    var body: some View
    {
        HStack(spacing: Space.s1)
        {
            Image(systemName: KindStyle.symbol(kind)).font(.system(size: 9, weight: .medium))
            Text(KindStyle.title(kind)).font(.cbCaption)
        }
        .foregroundStyle(Theme.inkSecondary)
        .padding(.horizontal, Space.s2)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous).fill(Theme.surfaceAlt))
    }
}

struct NoteChip: View
{
    let note: String

    var body: some View
    {
        HStack(spacing: Space.s1)
        {
            Image(systemName: "quote.opening").font(.system(size: 9))
            Text(note).font(.cbCaption).lineLimit(1).truncationMode(.tail)
        }
        .foregroundStyle(Theme.inkSecondary)
        .padding(.horizontal, Space.s2)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous).fill(Theme.surfaceAlt))
        .overlay(RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous).stroke(Theme.hairline, lineWidth: Theme.hairWidth))
    }
}

/// 图片缩略图缓存，避免列表滚动时反复读盘。
@MainActor
enum ImageCache
{
    private static var storage: [String: NSImage] = [:]

    static func image(for item: ClipItem) -> NSImage?
    {
        guard let name = item.cbImageName else { return nil }
        if let hit = storage[name] { return hit }
        guard let url = Core.imageURL(item), let image = NSImage(contentsOf: url) else { return nil }
        storage[name] = image
        return image
    }
}

@MainActor
struct LocalImageThumb: View
{
    let item: ClipItem
    let height: CGFloat

    var body: some View
    {
        Group
        {
            if let image = ImageCache.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipped()
            } else {
                ZStack
                {
                    RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous).fill(Theme.surfaceAlt)
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .ultraLight))
                        .foregroundStyle(Theme.hairline)
                }
                .frame(height: height)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous).stroke(Theme.hairline, lineWidth: Theme.hairWidth))
    }
}

struct ClipSummaryView: View
{
    let item: ClipItem
    var lineLimit: Int = 4
    var imageHeight: CGFloat = 88

    var body: some View
    {
        switch item.cbKind
        {
        case .image:
            LocalImageThumb(item: item, height: imageHeight)
        case .file:
            HStack(spacing: Space.s2)
            {
                Image(systemName: "doc").font(.system(size: 16, weight: .light)).foregroundStyle(Theme.inkSecondary)
                Text(CBSummaries.oneLine(item))
                    .font(.cbBody)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        case .text:
            Text(CBSummaries.oneLine(item))
                .font(.cbBody)
                .lineSpacing(3)
                .lineLimit(lineLimit)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ClipRowView: View
{
    let item: ClipItem
    let isSelected: Bool
    var showNote: Bool = true
    @State private var hovering = false

    var body: some View
    {
        HStack(spacing: Space.s3)
        {
            Image(systemName: KindStyle.symbol(item.cbKind))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: 16, alignment: .center)

            Text(CBSummaries.oneLine(item))
                .font(.cbBody)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)

            if showNote && !item.cbNote.isEmpty
            {
                NoteChip(note: item.cbNote).fixedSize(horizontal: true, vertical: false)
            }

            Spacer(minLength: Space.s2)

            Text(CBTime.relative(item.cbCreatedAt))
                .font(.cbCaption)
                .foregroundStyle(Theme.inkSecondary)
                .layoutPriority(2)
        }
        .padding(.horizontal, Space.s4)
        .frame(height: 44)
        .background(isSelected ? Theme.surfaceAlt : (hovering ? Theme.surfaceAlt.opacity(0.55) : Color.clear))
        .overlay(alignment: .leading)
        {
            if isSelected { Rectangle().fill(Theme.accent).frame(width: 2) }
        }
        .onHover { hovering = $0 }
    }
}

struct ToastView: View
{
    let text: String

    var body: some View
    {
        Text(text)
            .font(.cbBodyMedium)
            .foregroundStyle(Theme.canvas)
            .padding(.horizontal, Space.s3)
            .padding(.vertical, Space.s2 - 2)
            .background(Capsule().fill(Theme.ink.opacity(0.92)))
    }
}

struct FilterChip: View
{
    let title: String
    let isOn: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View
    {
        Button(action: action)
        {
            Text(title)
                .font(.cbCaption)
                .foregroundStyle(isOn ? Theme.ink : Theme.inkSecondary)
                .padding(.horizontal, Space.s3)
                .padding(.vertical, Space.s1)
                .background(
                    RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous)
                        .fill(isOn ? Theme.surface : (hovering ? Theme.surfaceAlt : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous)
                        .stroke(isOn ? Theme.hairline : Color.clear, lineWidth: Theme.hairWidth)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct ModeOption: Identifiable
{
    let mode: ViewMode
    let symbol: String
    let title: String
    var id: String { symbol }
}

struct ViewModeSwitch: View
{
    @Binding var mode: ViewMode

    private var options: [ModeOption]
    {
        [
            ModeOption(mode: .grid, symbol: "square.grid.2x2", title: "图标视图"),
            ModeOption(mode: .list, symbol: "list.bullet", title: "列表视图"),
            ModeOption(mode: .split, symbol: "rectangle.split.2x1", title: "分栏视图")
        ]
    }

    var body: some View
    {
        HStack(spacing: 2)
        {
            ForEach(options)
            { option in
                Button
                {
                    mode = option.mode
                }
                label:
                {
                    Image(systemName: option.symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(mode == option.mode ? Theme.ink : Theme.inkSecondary)
                        .frame(width: 26, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(mode == option.mode ? Theme.surface : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(option.title)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous).fill(Theme.surfaceAlt))
    }
}

struct SearchField: View
{
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var onSubmit: () -> Void

    var body: some View
    {
        HStack(spacing: Space.s2)
        {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Theme.inkSecondary)

            TextField("搜索内容或备注", text: $text)
                .textFieldStyle(.plain)
                .font(.cbBody)
                .foregroundStyle(Theme.ink)
                .focused(focused)
                .onSubmit(onSubmit)

            if !text.isEmpty
            {
                Button
                {
                    text = ""
                }
                label:
                {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSecondary)
                }
                .buttonStyle(.plain)
                .help("清空搜索")
            }
        }
        .padding(.horizontal, Space.s2 + 2)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                .stroke(focused.wrappedValue ? Theme.accent.opacity(0.45) : Theme.hairline, lineWidth: Theme.hairWidth)
        )
    }
}

struct WindowAccessor: NSViewRepresentable
{
    func makeNSView(context: Context) -> NSView
    {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async
        {
            guard let window = view.window else { return }
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = NSColor(Theme.canvas)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
