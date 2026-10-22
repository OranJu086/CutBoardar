import SwiftUI

/// 视觉规范唯一出处：颜色、字号、间距、圆角、描边。视图里不许再写裸数值。
enum Theme
{
    static let canvas = Color(cbHex: 0xFAF7F2)
    static let surface = Color(cbHex: 0xFFFFFF)
    static let surfaceAlt = Color(cbHex: 0xF3EFE7)
    static let hairline = Color(cbHex: 0xE4DED3)
    static let ink = Color(cbHex: 0x26241F)
    static let inkSecondary = Color(cbHex: 0x6B655B)
    static let accent = Color(cbHex: 0xA8643C)

    static let cardRadius: CGFloat = 10
    static let chipRadius: CGFloat = 7
    static let buttonRadius: CGFloat = 8
    static let hairWidth: CGFloat = 1
}

/// 4/8/12/16/24 刻度，禁止随手数字。
enum Space
{
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s6: CGFloat = 24
    static let titlebar: CGFloat = 30
}

extension Color
{
    init(cbHex hex: UInt32)
    {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// 字号梯度 22 / 15 / 13 / 11；标题用衬线营造纸感。
extension Font
{
    static var cbDisplay: Font { .system(size: 22, weight: .semibold, design: .serif) }
    static var cbSection: Font { .system(size: 15, weight: .medium, design: .serif) }
    static var cbBody: Font { .system(size: 13, weight: .regular) }
    static var cbBodyMedium: Font { .system(size: 13, weight: .medium) }
    static var cbCaption: Font { .system(size: 11, weight: .regular) }
    static var cbCaptionMedium: Font { .system(size: 11, weight: .medium) }
}

struct Hairline: View
{
    var body: some View
    {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: Theme.hairWidth)
    }
}

/// 发丝描边替代阴影；只在 hover / 选中时加一层极淡阴影。
struct PaperSurface: ViewModifier
{
    var radius: CGFloat = Theme.cardRadius
    var elevated: Bool = false
    var highlighted: Bool = false

    func body(content: Content) -> some View
    {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(highlighted ? Theme.accent : Theme.hairline, lineWidth: Theme.hairWidth)
            )
            .shadow(color: Theme.ink.opacity(elevated ? 0.06 : 0), radius: elevated ? 6 : 0, x: 0, y: 2)
    }
}

extension View
{
    func paperSurface(radius: CGFloat = Theme.cardRadius, elevated: Bool = false, highlighted: Bool = false) -> some View
    {
        modifier(PaperSurface(radius: radius, elevated: elevated, highlighted: highlighted))
    }
}

struct QuietButtonStyle: ButtonStyle
{
    func makeBody(configuration: Configuration) -> some View
    {
        configuration.label
            .font(.cbBody)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, Space.s3)
            .padding(.vertical, Space.s2 - 2)
            .background(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous).fill(configuration.isPressed ? Theme.surfaceAlt : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous).stroke(Theme.hairline, lineWidth: Theme.hairWidth))
    }
}

/// 强调色只给关键按钮，一屏最多一处。
struct AccentButtonStyle: ButtonStyle
{
    func makeBody(configuration: Configuration) -> some View
    {
        configuration.label
            .font(.cbBodyMedium)
            .foregroundStyle(Color.white)
            .padding(.horizontal, Space.s3)
            .padding(.vertical, Space.s2 - 2)
            .background(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous).fill(Theme.accent.opacity(configuration.isPressed ? 0.82 : 1)))
    }
}

struct PlainTextButtonStyle: ButtonStyle
{
    func makeBody(configuration: Configuration) -> some View
    {
        configuration.label
            .font(.cbBody)
            .foregroundStyle(configuration.isPressed ? Theme.accent : Theme.ink)
            .padding(.horizontal, Space.s2)
            .padding(.vertical, Space.s1)
    }
}

struct IconButton: View
{
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View
    {
        Button(action: action)
        {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(hovering ? Theme.ink : Theme.inkSecondary)
                .frame(width: 26, height: 22)
                .background(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous).fill(hovering ? Theme.surfaceAlt : Color.clear))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}
