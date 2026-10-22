// CutBoardar 占位图标绘制脚本（离屏 CoreGraphics，无需 GUI 会话）
// 用法：swiftc -O -sdk <SDK> -target arm64-apple-macos14.0 -module-cache-path ./.build/mc \
//        -o .build/make_icon Tools/make_icon.swift && ./.build/make_icon Assets/AppIcon.png
// 输出：1024x1024 sRGB PNG，透明画布 + 米白圆角方形 + 暖灰线性剪贴板符号。

import Foundation
import CoreGraphics
import ImageIO

let canvas: CGFloat = 1024

// 米白底 / 暖灰描边（纯色，无渐变、无噪点）
let paper      = CGColor(srgbRed: 0.976, green: 0.965, blue: 0.941, alpha: 1.0) // #F9F6F0
let ink        = CGColor(srgbRed: 0.408, green: 0.369, blue: 0.325, alpha: 1.0) // #685E53
let hairline   = CGColor(srgbRed: 0.545, green: 0.502, blue: 0.451, alpha: 0.18)

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath
{
    return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIcon(into ctx: CGContext)
{
    // 图标坐标以左上角为原点，方便按视觉位置摆布
    ctx.translateBy(x: 0, y: canvas)
    ctx.scaleBy(x: 1, y: -1)

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // 1. 底板：留 10% 边距，圆角半径约 22%
    let inset: CGFloat = canvas * 0.10
    let tile = CGRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
    let tileRadius = tile.width * 0.22
    let tilePath = rounded(tile, tileRadius)

    ctx.addPath(tilePath)
    ctx.setFillColor(paper)
    ctx.fillPath()

    // 2. 极细描边，避免浅色桌面背景下边缘消失
    ctx.addPath(rounded(tile.insetBy(dx: 1.5, dy: 1.5), tileRadius - 1.5))
    ctx.setStrokeColor(hairline)
    ctx.setLineWidth(3)
    ctx.strokePath()

    // 3. 剪贴板板身（线性描边）
    let stroke: CGFloat = 26
    let bodyW: CGFloat = 344
    let bodyH: CGFloat = 452
    let body = CGRect(x: (canvas - bodyW) / 2, y: (canvas - bodyH) / 2, width: bodyW, height: bodyH)
    ctx.addPath(rounded(body, 48))
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(stroke)
    ctx.strokePath()

    // 4. 顶部夹子：先用底色盖住板身上沿，再描边
    let tabW: CGFloat = 132
    let tabH: CGFloat = 62
    let tab = CGRect(x: (canvas - tabW) / 2, y: body.minY - tabH / 2, width: tabW, height: tabH)
    ctx.addPath(rounded(tab, 26))
    ctx.setFillColor(paper)
    ctx.fillPath()
    ctx.addPath(rounded(tab, 26))
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(stroke)
    ctx.strokePath()

    // 5. 两条内容线（长短不一，圆头）
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(24)
    ctx.setLineCap(.round)
    let lines: [(CGFloat, CGFloat)] = [(492, 216), (568, 152)]
    for (y, w) in lines
    {
        ctx.move(to: CGPoint(x: (canvas - 216) / 2, y: y))
        ctx.addLine(to: CGPoint(x: (canvas - 216) / 2 + w, y: y))
        ctx.strokePath()
    }
}

func main() throws
{
    let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Assets/AppIcon.png"
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(data: nil,
                              width: Int(canvas),
                              height: Int(canvas),
                              bitsPerComponent: 8,
                              bytesPerRow: 0,
                              space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else
    {
        FileHandle.standardError.write("错误：无法创建离屏位图上下文。\n".data(using: .utf8)!)
        exit(1)
    }

    drawIcon(into: ctx)

    guard let image = ctx.makeImage() else
    {
        FileHandle.standardError.write("错误：离屏绘制未产出图像。\n".data(using: .utf8)!)
        exit(1)
    }

    let url = URL(fileURLWithPath: outPath)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else
    {
        FileHandle.standardError.write("错误：无法创建 PNG 输出目标：\(outPath)\n".data(using: .utf8)!)
        exit(1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else
    {
        FileHandle.standardError.write("错误：PNG 写入失败：\(outPath)\n".data(using: .utf8)!)
        exit(1)
    }

    print("已生成占位图标：\(outPath)（\(Int(canvas))x\(Int(canvas))）")
}

do
{
    try main()
}
catch
{
    FileHandle.standardError.write("错误：\(error)\n".data(using: .utf8)!)
    exit(1)
}
