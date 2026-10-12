#if os(macOS)
import AppKit
import CoreText
import SwiftUI

extension TextStyle.RGBA {
    var nsColor: NSColor {
        NSColor(
            srgbRed: CGFloat(r),
            green: CGFloat(g),
            blue: CGFloat(b),
            alpha: CGFloat(a)
        )
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(
            r: Double(ns.redComponent),
            g: Double(ns.greenComponent),
            b: Double(ns.blueComponent),
            a: Double(ns.alphaComponent)
        )
    }
}

extension TextStyle {
    nonisolated(unsafe) private static let resolvedFontCache: NSCache<NSString, NSFont> = {
        let cache = NSCache<NSString, NSFont>()
        cache.countLimit = 512
        return cache
    }()

    func resolvedFont(size: CGFloat) -> NSFont {
        let key = "\(fontName.utf8.count):\(fontName)|\(Double(size).bitPattern)|\(isBold)|\(isItalic)|\(widthScale.bitPattern)|\(heightScale.bitPattern)" as NSString
        if let cached = Self.resolvedFontCache.object(forKey: key) { return cached }

        let namedBase = NSFont(name: fontName, size: size)
        let base = namedBase ?? NSFont.systemFont(ofSize: size)
        var resolved = Self.font(base, size: size, bold: isBold, italic: isItalic)
        if widthScale != 1 || heightScale != 1 {
            var transform = CGAffineTransform(scaleX: CGFloat(widthScale), y: CGFloat(heightScale))
            resolved = CTFontCreateCopyWithAttributes(resolved as CTFont, size, &transform, nil) as NSFont
        }
        // A bundled font may not be registered yet; do not cache its fallback.
        if namedBase != nil { Self.resolvedFontCache.setObject(resolved, forKey: key) }
        return resolved
    }

    var nsColor: NSColor { color.nsColor }

    func paragraphStyle(size: CGFloat, alignment override: NSTextAlignment? = nil) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        if let override {
            p.alignment = override
        } else {
            switch alignment {
            case .left: p.alignment = .left
            case .center: p.alignment = .center
            case .right: p.alignment = .right
            }
        }
        p.lineBreakMode = .byWordWrapping
        let scaledSpacing = lineSpacing * Double(size) / max(1, fontSize * fontScale)
        p.lineSpacing = CGFloat(scaledSpacing.isFinite ? scaledSpacing : 0)
        return p
    }
    /// `includeColor: false` for bounding measurement (color doesn't affect size).
    func attributes(size: CGFloat, includeColor: Bool = true) -> [NSAttributedString.Key: Any] {
        var attrs = baseAttributes(size: size)
        if isUnderlined { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if isStruckThrough { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if includeColor { attrs[.foregroundColor] = nsColor }
        if border.enabled, border.width > 0, !drawsGlyphOutline {
            attrs[.strokeWidth] = NSNumber(value: -100 * max(0, border.width) / max(1, fontSize * fontScale))
            if includeColor { attrs[.strokeColor] = border.color.nsColor }
        }
        return attrs
    }

    /// Stroke-only undercoat at 2× width; the fill drawn on top covers the inner half, leaving `border.width` outward.
    func outlineUndercoatAttributes(size: CGFloat) -> [NSAttributedString.Key: Any] {
        var attrs = baseAttributes(size: size)
        attrs[.strokeWidth] = NSNumber(value: 200 * max(0, border.width) / max(1, fontSize * fontScale))
        attrs[.strokeColor] = border.color.nsColor
        return attrs
    }

    private func baseAttributes(size: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: resolvedFont(size: size),
            .paragraphStyle: paragraphStyle(size: size),
            .kern: tracking * Double(size) / max(1, fontSize * fontScale),
        ]
    }

    private static func font(_ font: NSFont, size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
        var traits = CTFontGetSymbolicTraits(font as CTFont)
        if bold { traits.insert(.traitBold) } else { traits.remove(.traitBold) }
        if italic { traits.insert(.traitItalic) } else { traits.remove(.traitItalic) }

        let mask: CTFontSymbolicTraits = [.traitBold, .traitItalic]
        let descriptor = CTFontCopyFontDescriptor(font as CTFont)
        guard let resolvedDescriptor = CTFontDescriptorCreateCopyWithSymbolicTraits(descriptor, traits, mask) else {
            return font
        }
        return CTFontCreateWithFontDescriptor(resolvedDescriptor, size, nil) as NSFont
    }

    private static func symbolicTraits(fontName: String, size: CGFloat) -> CTFontSymbolicTraits {
        guard let font = NSFont(name: fontName, size: size) else { return [] }
        return CTFontGetSymbolicTraits(font as CTFont)
    }
}
#endif
