import AppKit
import SwiftUI

@MainActor
struct DetailPanel: View
{
    let item: ClipItem
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onFlash: (String) -> Void

    @State private var draftText: String = ""
    @State private var draftNote: String = ""
    @State private var loadedID: ClipItem.ID?

    private var canEditText: Bool { item.cbKind == .text }

    private var isDirty: Bool
    {
        if canEditText && draftText != item.cbText { return true }
        return draftNote != item.cbNote
    }

    private var retentionText: String
    {
        if item.cbIsPermanent { return "永久保留" }
        let retention = Core.retentionDays
        let days = item.cbRetentionDays ?? retention
        guard let left = item.cbDaysLeft(defaultRetention: retention) else { return "保留 \(days) 天" }
        if left < 0 { return "保留 \(days) 天 · 已过期 \(abs(left)) 天" }
        if left == 0 { return "保留 \(days) 天 · 今天到期" }
        return "保留 \(days) 天 · \(left) 天后到期"
    }

    var body: some View
    {
        ScrollView
        {
            VStack(alignment: .leading, spacing: Space.s4)
            {
                heading
                contentSection
                noteSection
                retentionSection
                actionRow
                metaRow
            }
            .padding(Space.s4)
        }
        .background(Theme.canvas)
        .onAppear { load() }
        .onChange(of: item.id) { _, _ in load() }
    }

    private var heading: some View
    {
        HStack(spacing: Space.s2)
        {
            KindBadge(kind: item.cbKind)
            Text(CBTime.relative(item.cbCreatedAt)).font(.cbCaption).foregroundStyle(Theme.inkSecondary)
            Spacer(minLength: Space.s2)
            if isDirty
            {
                Button("保存修改") { save() }.buttonStyle(AccentButtonStyle())
            }
        }
    }

    private var contentSection: some View
    {
        VStack(alignment: .leading, spacing: Space.s2)
        {
            sectionTitle("内容")
            if canEditText
            {
                TextEditor(text: $draftText)
                    .font(.cbBody)
                    .lineSpacing(3)
                    .scrollContentBackground(.hidden)
                    .padding(Space.s2)
                    .frame(minHeight: 200)
                    .background(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous).fill(Theme.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                            .stroke(Theme.hairline, lineWidth: Theme.hairWidth)
                    )
            }
            else if item.cbKind == .image
            {
                imageBody
            }
            else
            {
                Text(item.cbText.isEmpty ? "（无路径信息）" : item.cbText)
                    .font(.cbBody)
                    .textSelection(.enabled)
                    .padding(Space.s3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .paperSurface(radius: Theme.buttonRadius)
            }
        }
    }

    private var imageBody: some View
    {
        Group
        {
            if let url = Core.imageURL(item), let image = NSImage(contentsOf: url)
            {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 280)
                    .paperSurface(radius: Theme.buttonRadius)
            }
            else
            {
                Text("图片文件缺失")
                    .font(.cbBody)
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .paperSurface(radius: Theme.buttonRadius)
            }
        }
    }

    private var noteSection: some View
    {
        VStack(alignment: .leading, spacing: Space.s2)
        {
            HStack
            {
                sectionTitle("备注")
                Spacer()
                Text("三种视图里都会显示").font(.cbCaption).foregroundStyle(Theme.inkSecondary)
            }

            TextEditor(text: $draftNote)
                .font(.cbBody)
                .scrollContentBackground(.hidden)
                .padding(Space.s2)
                .frame(minHeight: 64)
                .background(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous).fill(Theme.surfaceAlt))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: Theme.hairWidth)
                )
        }
    }

    private var retentionSection: some View
    {
        VStack(alignment: .leading, spacing: Space.s2)
        {
            sectionTitle("保留期限")
            HStack(spacing: Space.s2)
            {
                Text(retentionText).font(.cbBody).foregroundStyle(Theme.inkSecondary)
                Spacer(minLength: Space.s2)
                Button("保留更久（+30 天）")
                {
                    Core.extend(item, days: 30)
                    onFlash("已延长 30 天")
                }
                .buttonStyle(QuietButtonStyle())

                if !item.cbIsPermanent
                {
                    Button("永久保留")
                    {
                        Core.makePermanent(item)
                        onFlash("已设为永久保留")
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
        }
    }

    private var actionRow: some View
    {
        HStack(spacing: Space.s2)
        {
            Button("复制") { onCopy() }.buttonStyle(AccentButtonStyle())
            Spacer()
            Button("删除这条") { onDelete() }.buttonStyle(QuietButtonStyle())
        }
    }

    private var metaRow: some View
    {
        VStack(alignment: .leading, spacing: Space.s1)
        {
            Hairline()
            Text("创建于 \(CBTime.absolute(item.cbCreatedAt))").font(.cbCaption).foregroundStyle(Theme.inkSecondary)
            Text("类型 \(KindStyle.title(item.cbKind)) · 大小 \(CBTime.byteSize(item.cbByteSize))").font(.cbCaption).foregroundStyle(Theme.inkSecondary)
        }
        .padding(.top, Space.s1)
    }

    private func sectionTitle(_ text: String) -> some View
    {
        Text(text).font(.cbSection).foregroundStyle(Theme.ink)
    }

    private func load()
    {
        guard loadedID != item.id else { return }
        loadedID = item.id
        draftText = item.cbText
        draftNote = item.cbNote
    }

    private func save()
    {
        if canEditText { Core.updateText(item.id, draftText) }
        Core.updateNote(item.id, draftNote)
        onFlash("已保存")
    }
}
