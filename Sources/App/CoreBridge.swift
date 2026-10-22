import Foundation
import SwiftUI

/// Core 契约适配层。所有对 ClipStore / ClipItem 的访问都收在这里，
/// Core 侧签名变化时只需改本文件，视图层一行不动。
extension ClipItem
{
    var cbID: ClipItem.ID { id }
    var cbKind: ClipKind { kind }
    var cbText: String { text }
    var cbNote: String { note }
    var cbTitle: String { displayTitle }
    var cbSubtitle: String { displaySubtitle }
    var cbCreatedAt: Date { createdAt }
    var cbByteSize: Int { byteSize }
    var cbIsPermanent: Bool { isPermanent }
    var cbRetentionDays: Int? { retentionDays }
    var cbImageName: String? { imageFileName }

    /// 到期日；永久保留返回 nil。与 ClipStore.effectiveRetentionDays 同语义。
    func cbExpiryDate(defaultRetention: Int) -> Date?
    {
        guard !isPermanent else { return nil }
        let days = retentionDays ?? defaultRetention
        guard days > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: days, to: createdAt)
    }

    /// 剩余天数（可为负 = 已过期）；永久保留返回 nil。
    func cbDaysLeft(defaultRetention: Int, now: Date = Date()) -> Int?
    {
        guard let expiry = cbExpiryDate(defaultRetention: defaultRetention) else { return nil }
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: now)
        let to = calendar.startOfDay(for: expiry)
        return calendar.dateComponents([.day], from: from, to: to).day
    }

    /// 展示用的到期文案；过期判定以 ClipStore.expiryDate 为准。
    func cbIsExpiredByCalendar(defaultRetention: Int, now: Date = Date()) -> Bool
    {
        guard let expiry = cbExpiryDate(defaultRetention: defaultRetention) else { return false }
        return expiry <= now
    }
}

@MainActor
enum Core
{
    static var store: ClipStore { ClipStore.shared }
    static var items: [ClipItem] { ClipStore.shared.items }
    static var settings: AppSettings { ClipStore.shared.settings }
    static var retentionDays: Int { ClipStore.shared.settings.retentionDays }
    static var warnDays: Int { ClipStore.shared.settings.warnDaysBefore }

    static func setRetentionDays(_ value: Int) { ClipStore.shared.settings.retentionDays = max(1, value) }
    static func setWarnDays(_ value: Int) { ClipStore.shared.settings.warnDaysBefore = max(0, value) }
    static func setMaxItems(_ value: Int) { ClipStore.shared.settings.maxItems = max(1, value) }
    static func setViewMode(_ value: ViewMode) { ClipStore.shared.settings.viewMode = value }

    static func setNotifications(_ value: Bool)
    {
        ClipStore.shared.settings.notificationsEnabled = value
        if value { ClipNotifier.requestAuthorization() }
    }

    static func addText(_ text: String)
    {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        _ = ClipStore.shared.addText(text)
    }

    static func updateText(_ id: ClipItem.ID, _ text: String)
    {
        ClipStore.shared.update(id: id, text: text, note: nil)
    }

    static func updateNote(_ id: ClipItem.ID, _ note: String)
    {
        ClipStore.shared.update(id: id, text: nil, note: note)
    }

    static func delete(_ id: ClipItem.ID) { ClipStore.shared.delete(id: id) }
    static func deleteAll() { ClipStore.shared.deleteAll() }
    static func copy(_ item: ClipItem) { ClipStore.shared.copyToPasteboard(item) }
    static func imageURL(_ item: ClipItem) -> URL? { ClipStore.shared.imageURL(for: item) }

    static func extend(_ item: ClipItem, days: Int = 30)
    {
        let base = item.retentionDays ?? retentionDays
        ClipStore.shared.setRetention(id: item.id, days: base + days)
    }

    static func makePermanent(_ item: ClipItem) { ClipStore.shared.setPermanent(id: item.id, true) }

    /// 未来预警窗口内即将到期的记录（Core 权威口径，与系统通知一致）。
    static func expiringItems() -> [ClipItem] { ClipStore.shared.expiringSoon }

    /// 过期口径与 ClipStore.runExpirySweep 完全一致：直接问 Core 要到期时刻。
    static func expiredItems() -> [ClipItem]
    {
        let now = Date()
        return items.filter
        {
            guard let expiry = ClipStore.shared.expiryDate(for: $0) else { return false }
            return expiry <= now
        }
    }

    static func deleteExpired()
    {
        for item in expiredItems() { ClipStore.shared.delete(id: item.id) }
    }

    static func extendAllExpiring(days: Int = 30)
    {
        for item in expiringItems() { extend(item, days: days) }
    }

    private static var monitor: ClipboardMonitor?

    static func startMonitoring()
    {
        guard monitor == nil else { return }
        let created = ClipboardMonitor(store: ClipStore.shared)
        created.start()
        monitor = created
    }

    static func runExpirySweep()
    {
        ClipStore.shared.runExpirySweep()
    }

    /// 发送时机由界面层决定：一天最多一次。
    static func notifyExpiringOncePerDay()
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let defaults = UserDefaults.standard
        let key = "cb.lastExpiryNoticeDay"

        guard defaults.string(forKey: key) != today else { return }

        defaults.set(today, forKey: key)
        ClipStore.shared.notifyExpiringSoon()
    }
}
