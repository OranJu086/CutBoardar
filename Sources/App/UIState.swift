import SwiftUI

enum KindFilter: String, CaseIterable, Identifiable
{
    case all
    case text
    case image
    case file

    var id: String { rawValue }

    var title: String
    {
        switch self
        {
        case .all: return "全部"
        case .text: return "文本"
        case .image: return "图片"
        case .file: return "文件"
        }
    }

    func matches(_ kind: ClipKind) -> Bool
    {
        switch self
        {
        case .all: return true
        case .text: return kind == .text
        case .image: return kind == .image
        case .file: return kind == .file
        }
    }
}

@MainActor
final class UIState: ObservableObject
{
    @Published var searchText: String = ""
    @Published var filter: KindFilter = .all
    @Published var onlyExpiring: Bool = false
    @Published var selection: ClipItem.ID?
    @Published var viewMode: ViewMode = .grid
    @Published var showSettings: Bool = false
    @Published var showCleanup: Bool = false
    @Published var showAdd: Bool = false
    @Published var toast: String?

    private var toastTask: Task<Void, Never>?

    func loadSavedViewMode()
    {
        viewMode = Core.settings.viewMode
    }

    func changeViewMode(_ mode: ViewMode)
    {
        viewMode = mode
        Core.setViewMode(mode)
    }

    func flash(_ message: String = "已复制")
    {
        toast = message
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard let self, !Task.isCancelled else { return }
            self.toast = nil
        }
    }

    /// 搜索（标题/内容/备注）+ 类型筛选 + 仅看即将到期。
    func visible(_ items: [ClipItem]) -> [ClipItem]
    {
        let retention = Core.retentionDays
        let warn = Core.warnDays
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return items.filter { item in
            guard filter.matches(item.cbKind) else { return false }
            if onlyExpiring {
                guard let left = item.cbDaysLeft(defaultRetention: retention), left <= warn else { return false }
            }
            guard !query.isEmpty else { return true }
            if item.cbTitle.lowercased().contains(query) { return true }
            if item.cbText.lowercased().contains(query) { return true }
            if item.cbNote.lowercased().contains(query) { return true }
            return false
        }
    }

    func isFiltering() -> Bool
    {
        return filter != .all || onlyExpiring || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
