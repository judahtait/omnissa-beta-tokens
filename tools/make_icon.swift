// Draws the Omnissa Beta Token Utility app icon with CoreGraphics (no external tools).
//
//   swiftc -O tools/make_icon.swift -o /tmp/make_icon
//   make_icon sheet   <outDir>                         concept PNGs (every variant x tile, 1024 and 64 px)
//   make_icon iconset <variant> <tile> <iconsetDir>    16..1024 px iconset; then: iconutil -c icns <iconsetDir>
//
// Variants: v1-layered, v2-key-bow, v3-badge.
// Tiles: white (white tile, Omnissa-gradient mark), omnissa (navy > indigo > magenta tile, white mark),
//        light (indigo > magenta tile, white mark).
// The beta is a monoline path, not a font glyph: Outfit has no Greek characters, and an
// outlined glyph from a system font would carry that font's licence.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
let white = color(0xFFFFFF)

enum Variant: String, CaseIterable { case layered = "v1-layered", bow = "v2-key-bow", badge = "v3-badge" }
enum Tile: String, CaseIterable { case white, omnissa, light }

// MARK: geometry (1024 x 1024 design space, y down)

func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

func hexagon(radius r: CGFloat, center c: CGPoint = pt(512, 512)) -> CGPath {
    let p = CGMutablePath()
    for i in 0..<6 {
        let a = -CGFloat.pi / 2 + CGFloat(i) * CGFloat.pi / 3
        let q = pt(c.x + r * cos(a), c.y + r * sin(a))
        if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
    }
    p.closeSubpath()
    return p
}

/// Monoline beta: a stem with a descender and two bowls.
func betaPath() -> CGPath {
    let p = CGMutablePath()
    p.move(to: pt(392, 840))
    p.addLine(to: pt(392, 360))
    p.addCurve(to: pt(540, 214), control1: pt(392, 270), control2: pt(452, 214))
    p.addCurve(to: pt(686, 336), control1: pt(628, 214), control2: pt(686, 264))
    p.addCurve(to: pt(566, 462), control1: pt(686, 404), control2: pt(636, 452))
    p.addCurve(to: pt(716, 612), control1: pt(654, 470), control2: pt(716, 520))
    p.addCurve(to: pt(548, 780), control1: pt(716, 716), control2: pt(646, 780))
    p.addCurve(to: pt(392, 700), control1: pt(476, 780), control2: pt(420, 748))
    return p
}
let betaCenter = pt(554, 527)

func keyPath(ringCenter c: CGPoint = pt(372, 512), ringRadius r: CGFloat = 128, shaftEnd: CGFloat = 790,
             teeth: [(x: CGFloat, len: CGFloat)] = [(700, 88), (780, 68)]) -> CGPath {
    let p = CGMutablePath()
    p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    p.move(to: pt(c.x + r, c.y))
    p.addLine(to: pt(shaftEnd, c.y))
    for t in teeth {
        p.move(to: pt(t.x, c.y))
        p.addLine(to: pt(t.x, c.y + t.len))
    }
    return p
}
let keyCenter = pt(517, 512)

func placed(_ path: CGPath, at center: CGPoint, from src: CGPoint, scale s: CGFloat, rotation: CGFloat = 0) -> CGPath {
    var t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotation)
        .scaledBy(x: s, y: s).translatedBy(x: -src.x, y: -src.y)
    return path.copy(using: &t) ?? path
}

// MARK: drawing

struct Painter {
    let ctx: CGContext
    let k: CGFloat   // design-space to pixel factor (shadows are specified in pixels)

    func stroke(_ path: CGPath, width: CGFloat, _ c: CGColor = white, shadow: Bool = false,
                shadowColor: CGColor = color(0x000030, 0.38)) {
        ctx.saveGState()
        if shadow { ctx.setShadow(offset: CGSize(width: 0, height: -14 * k), blur: 24 * k, color: shadowColor) }
        ctx.setStrokeColor(c); ctx.setLineWidth(width); ctx.setLineCap(.round); ctx.setLineJoin(.round)
        ctx.addPath(path); ctx.strokePath()
        ctx.restoreGState()
    }

    func fill(_ path: CGPath, _ c: CGColor) {
        ctx.saveGState(); ctx.setFillColor(c); ctx.addPath(path); ctx.fillPath(); ctx.restoreGState()
    }

    /// Stroke filled with a linear gradient (design-space coordinates), optionally with a soft shadow and a glossy sheen.
    func gradientStroke(_ path: CGPath, width: CGFloat, colors: [CGColor], locs: [CGFloat],
                        from a: CGPoint, to b: CGPoint, shadow: Bool = false, sheen: Bool = false) {
        if shadow {
            stroke(path, width: width, color(0x4A12F0), shadow: true, shadowColor: color(0x1A1A40, 0.22))
        }
        ctx.saveGState()
        ctx.addPath(path); ctx.setLineWidth(width); ctx.setLineCap(.round); ctx.setLineJoin(.round)
        ctx.replacePathWithStrokedPath(); ctx.clip()
        ctx.drawLinearGradient(CGGradient(colorsSpace: srgb, colors: colors as CFArray, locations: locs)!,
                               start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        if sheen {
            let bb = ctx.boundingBoxOfClipPath
            ctx.drawLinearGradient(CGGradient(colorsSpace: srgb, colors: [color(0xFFFFFF, 0.26), color(0xFFFFFF, 0)] as CFArray,
                                              locations: [0, 1])!, start: pt(bb.midX, bb.minY), end: pt(bb.midX, bb.midY), options: [])
        }
        ctx.restoreGState()
    }

    func gradientFill(_ path: CGPath, colors: [CGColor], locs: [CGFloat], from a: CGPoint, to b: CGPoint) {
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        ctx.drawLinearGradient(CGGradient(colorsSpace: srgb, colors: colors as CFArray, locations: locs)!,
                               start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }
}

func render(_ variant: Variant, _ tile: Tile, pixels: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    let k = CGFloat(pixels) / 1024
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: k, y: -k)
    let p = Painter(ctx: ctx, k: k)

    let onWhite = tile == .white

    // Tile (macOS icon grid: 824 px square inside the 1024 canvas)
    let tilePath = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                          cornerWidth: 186, cornerHeight: 186, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * k), blur: 28 * k,
                  color: onWhite ? color(0x1A1A40, 0.16) : color(0x000000, 0.35))
    ctx.setFillColor(onWhite ? white : color(0x4A12F0)); ctx.addPath(tilePath); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    if onWhite {
        ctx.drawLinearGradient(CGGradient(colorsSpace: srgb, colors: [color(0xFFFFFF), color(0xEDEDF5)] as CFArray,
                                          locations: [0, 1])!, start: pt(512, 100), end: pt(512, 924), options: [])
    } else {
        let stops: [CGColor], locs: [CGFloat]
        if tile == .omnissa { stops = [color(0x001E60), color(0x4A12F0), color(0xD600FF)]; locs = [0, 0.55, 1] }
        else { stops = [color(0x4A12F0), color(0xD600FF)]; locs = [0, 1] }
        ctx.drawLinearGradient(CGGradient(colorsSpace: srgb, colors: stops as CFArray, locations: locs)!,
                               start: pt(140, 100), end: pt(880, 924), options: [])
        // liquid-glass sheen across the top half
        ctx.drawLinearGradient(CGGradient(colorsSpace: srgb, colors: [color(0xFFFFFF, 0.30), color(0xFFFFFF, 0)] as CFArray,
                                          locations: [0, 1])!, start: pt(512, 100), end: pt(512, 560), options: [])
    }
    ctx.restoreGState()
    p.stroke(tilePath, width: 3, onWhite ? color(0xD5D5E2) : color(0xFFFFFF, 0.35))

    // Mark painting: white on gradient tiles, Omnissa gradient on the white tile.
    func stops(_ alpha: CGFloat) -> [CGColor] { [color(0x001E60, alpha), color(0x4A12F0, alpha), color(0xD600FF, alpha)] }
    let locs: [CGFloat] = [0, 0.5, 1]
    func mark(_ path: CGPath, _ width: CGFloat, shadow: Bool = false) {
        if onWhite {
            p.gradientStroke(path, width: width, colors: stops(1), locs: locs, from: pt(220, 330), to: pt(820, 700),
                             shadow: shadow, sheen: true)
        } else {
            p.stroke(path, width: width, shadow: shadow)
        }
    }
    func glass(_ path: CGPath, outline w: CGFloat) {
        if onWhite {
            p.gradientFill(path, colors: stops(0.10), locs: locs, from: pt(200, 200), to: pt(830, 830))
            p.gradientStroke(path, width: w, colors: stops(0.50), locs: locs, from: pt(200, 200), to: pt(830, 830))
        } else {
            p.fill(path, color(0xFFFFFF, 0.14))
            p.stroke(path, width: w, color(0xFFFFFF, 0.55))
        }
    }

    switch variant {
    case .layered:
        // Hexagon (glass) > beta > key laid over the lower right.
        glass(hexagon(radius: 305), outline: 10)
        mark(placed(betaPath(), at: pt(500, 500), from: betaCenter, scale: 0.66), 52, shadow: true)
        mark(placed(keyPath(), at: pt(672, 672), from: keyCenter, scale: 0.42, rotation: .pi / 4), 44, shadow: true)
    case .bow:
        // The beta sits inside the bow of the key.
        glass(hexagon(radius: 372), outline: 10)
        mark(keyPath(ringCenter: pt(404, 512), ringRadius: 150, shaftEnd: 772, teeth: [(694, 80), (756, 62)]), 52, shadow: true)
        mark(placed(betaPath(), at: pt(404, 512), from: betaCenter, scale: 0.31), 32)
    case .badge:
        // Hexagon outline with a large beta, and a small key badge on the corner.
        mark(hexagon(radius: 300), 34)
        mark(placed(betaPath(), at: pt(512, 500), from: betaCenter, scale: 0.72), 56, shadow: true)
        glass(CGPath(ellipseIn: CGRect(x: 702 - 118, y: 712 - 118, width: 236, height: 236), transform: nil), outline: 8)
        mark(placed(keyPath(), at: pt(702, 712), from: keyCenter, scale: 0.26, rotation: .pi / 4), 26)
    }
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("cannot write \(url.path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("failed to write \(url.path)") }
}

// MARK: main

let args = CommandLine.arguments
func usage() -> Never {
    FileHandle.standardError.write(Data("usage: make_icon sheet <outDir> | iconset <variant> <tile> <iconsetDir>\n".utf8))
    exit(2)
}
guard args.count >= 3 else { usage() }
let fm = FileManager.default

switch args[1] {
case "sheet":
    let out = URL(fileURLWithPath: args[2])
    try fm.createDirectory(at: out, withIntermediateDirectories: true)
    for v in Variant.allCases { for t in Tile.allCases { for px in [1024, 64] {
        writePNG(render(v, t, pixels: px), to: out.appendingPathComponent("\(v.rawValue)-\(t.rawValue)-\(px).png"))
    } } }
    print("wrote concept PNGs to \(out.path)")
case "iconset":
    guard args.count == 5, let v = Variant(rawValue: args[2]), let t = Tile(rawValue: args[3]) else { usage() }
    let out = URL(fileURLWithPath: args[4])
    try fm.createDirectory(at: out, withIntermediateDirectories: true)
    for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                       ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
        writePNG(render(v, t, pixels: px), to: out.appendingPathComponent("icon_\(name).png"))
    }
    print("wrote iconset to \(out.path)")
default:
    usage()
}
