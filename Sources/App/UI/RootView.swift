import Combine
import SwiftUI

@MainActor
struct RootView: View
{
    @ObservedObject private var store = ClipStore.shared
    @StateObject private var ui = UIState()
    @Environment(\.openWindow) private var openWindow
    @FocusState private var searchFocused: Bool

    private var visibleItems: [ClipItem] { ui.visible(store.items) }
    private var expiring: [ClipItem] { Core.expiringItems() }

    private var minDaysLeft: Int
    {
        let retention = Core.retentionDays
        let values = expiring.compactMap { $0.cbDaysLeft(defaultRetention: retention) }
        return values.min() ?? 0
    }

    private var countText: String
    {
        if visibleItems.count != store.items.count
        {
            return "共 \(store.items.count) 条 · 匹配 \(visibleItems.count) 条"
        }
        return "共 \(store.items.count) 条记录"
    }

    var body: some View
    {
        ZStack(alignment: .bottom)
        {
            Theme.canvas.ignoresSafeArea()

            VStack(spacing: 0)
            {
                header
                Hairline()

                if !expiring.isEmpty
                {
                    WarningBanner(
                        count: expiring.count,
                        daysLeft: minDaysLeft,
                        onShow: { ui.onlyExpiring = true },
                        onExtendAll: {
                            Core.extendAllExpiring(days: 30)
                            ui.flash("已延长 30 天")
                        }
                    )
                }

                filterBar
                Hairline()
                content
            }
            .padding(.top, Space.titlebar)

            if let toast = ui.toast
            {
                ToastView(text: toast)
                    .padding(.bottom, Space.s6)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: ui.toast)
        .frame(minWidth: 720, minHeight: 480)
        .background(Theme.canvas)
        .background(WindowAccessor())
        .sheet(isPresented: $ui.showSettings) { SettingsView() }
        .sheet(isPresented: $ui.showCleanup) { CleanupSheet() }
        .sheet(isPresented: $ui.showAdd) { AddItemSheet() }
        .onAppear
        {
            ui.loadSavedViewMode()
            AppRouter.shared.openWindowAction = openWindow
            Core.runExpirySweep()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cbFocusSearch)) { _ in
            searchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .cbOpenSettings)) { _ in
            ui.showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .cbOpenCleanup)) { _ in
            ui.showCleanup = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .cbOpenAdd)) { _ in
            ui.showAdd = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .cbDeleteSelection)) { _ in
            if let id = ui.selection { remove(id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cbCopySelection)) { _ in
            if let item = visibleItems.first(where: { $0.id == ui.selection }) ?? visibleItems.first
            {
                copy(item)
            }
        }
    }

    private var header: some View
    {
        HStack(alignment: .center, spacing: Space.s3)
        {
            VStack(alignment: .leading, spacing: 2)
            {
                Text("剪贴板").font(.cbDisplay).foregroundStyle(Theme.ink)
                Text(countText).font(.cbCaption).foregroundStyle(Theme.inkSecondary)
            }

            Spacer(minLength: Space.s4)

            SearchField(text: $ui.searchText, focused: $searchFocused)
            {
                if let item = visibleItems.first { copy(item) }
            }
            .frame(width: 240)

            IconButton(symbol: "plus", help: "新增记录（⌘N）") { ui.showAdd = true }
            IconButton(symbol: "trash", help: "清理历史（⇧⌘⌫）") { ui.showCleanup = true }
            IconButton(symbol: "gearshape", help: "设置（⌘,）") { ui.showSettings = true }
        }
        .padding(.horizontal, Space.s4)
        .padding(.top, Space.s2)
        .padding(.bottom, Space.s3)
    }

    private var filterBar: some View
    {
        HStack(spacing: Space.s1)
        {
            ForEach(KindFilter.allCases)
            { kind in
                FilterChip(title: kind.title, isOn: ui.filter == kind) { ui.filter = kind }
            }

            if ui.onlyExpiring
            {
                FilterChip(title: "即将到期", isOn: true) { ui.onlyExpiring = false }
            }

            Spacer(minLength: Space.s2)

            ViewModeSwitch(mode: Binding(get: { ui.viewMode }, set: { ui.changeViewMode($0) }))
        }
        .padding(.horizontal, Space.s4)
        .padding(.vertical, Space.s2)
    }

    @ViewBuilder private var content: some View
    {
        if visibleItems.isEmpty
        {
            EmptyStateView(searching: ui.isFiltering())
        }
        else
        {
            switch ui.viewMode
            {
            case .grid:
                ClipGridView(items: visibleItems, selection: $ui.selection, onCopy: copy, onDelete: remove, onEdit: edit)
            case .list:
                ClipListView(items: visibleItems, selection: $ui.selection, onCopy: copy, onDelete: remove, onEdit: edit)
            case .split:
                SplitBoardView(items: visibleItems, selection: $ui.selection, onCopy: copy, onDelete: remove, onFlash: { ui.flash($0) })
            }
        }
    }

    private func copy(_ item: ClipItem)
    {
        Core.copy(item)
        ui.selection = item.id
        ui.flash("已复制")
    }

    /// 备注与正文的编辑区在分栏详情里，这里直接把选中项带过去。
    private func edit(_ item: ClipItem)
    {
        ui.selection = item.id
        ui.changeViewMode(.split)
    }

    private func remove(_ id: ClipItem.ID)
    {
        if ui.selection == id { ui.selection = nil }
        Core.delete(id)
        ui.flash("已删除")
    }
}
