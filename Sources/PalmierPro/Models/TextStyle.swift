import Foundation

struct TextStyle: Codable, Sendable, Equatable, Hashable {
    static let axisScaleRange = 0.1...10.0

    var fontName: String = "Helvetica"
    var fontSize: Double = 96
    var fontScale: Double = 1.0
    var widthScale: Double = 1.0
    var heightScale: Double = 1.0
    var tracking: Double = 0
    var lineSpacing: Double = 0
    var fontCase: FontCase = .mixed
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderlined: Bool = false
    var isStruckThrough: Bool = false
    var isOverlined: Bool = false
    var color: RGBA = RGBA()
    var alignment: Alignment = .center
    var blur: Double = 0
    var shadow: Shadow = Shadow()
    var background: Background = Background()
    var border: Outline = Outline()

    enum Alignment: String, Codable, Sendable, CaseIterable, Hashable {
        case left
        case center
        case right
    }

    enum FontCase: String, Codable, Sendable, CaseIterable, Hashable {
        case mixed
        case uppercase
        case lowercase

        var label: String {
            switch self {
            case .mixed: L10n.key("Mixed")
            case .uppercase: L10n.key("UPPERCASE")
            case .lowercase: L10n.key("lowercase")
            }
        }

        func apply(to text: String) -> String {
            switch self {
            case .mixed: text
            case .uppercase: text.uppercased()
            case .lowercase: text.lowercased()
            }
        }
    }

    struct RGBA: Codable, Sendable, Equatable, Hashable {
        var r: Double = 1
        var g: Double = 1
        var b: Double = 1
        var a: Double = 1
    }

    struct Shadow: Codable, Sendable, Equatable, Hashable {
        var enabled: Bool = false
        /// Alpha doubles as opacity; layer.shadowOpacity stays at 1.
        var color: RGBA = RGBA(r: 0, g: 0, b: 0, a: 0.6)
        /// Canvas points; scaled at render time.
        var offsetX: Double = 0
        var offsetY: Double = -2
        var blur: Double = 6
    }

    struct Outline: Codable, Sendable, Equatable, Hashable {
        var enabled: Bool = false
        var color: RGBA = RGBA(r: 0, g: 0, b: 0, a: 1)
        /// Width in reference-canvas points.
        var width: Double = 4

        init(enabled: Bool = false, color: RGBA = RGBA(r: 0, g: 0, b: 0, a: 1), width: Double = 4) {
            self.enabled = enabled
            self.color = color
            self.width = width
        }

        private enum CodingKeys: String, CodingKey { case enabled, color, width }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                enabled: (try? c.decode(Bool.self, forKey: .enabled)) ?? false,
                color: (try? c.decode(RGBA.self, forKey: .color)) ?? RGBA(r: 0, g: 0, b: 0, a: 1),
                width: (try? c.decode(Double.self, forKey: .width)) ?? 4
            )
        }
    }

    struct Background: Codable, Sendable, Equatable, Hashable {
        var enabled: Bool = false
        var color: RGBA = RGBA(r: 0, g: 0, b: 0, a: 0.6)
        var paddingX: Double = 0
        var paddingY: Double = 0
        var cornerRadius: Double = 0
        var offsetX: Double = 0
        var offsetY: Double = 0
        var outlineColor: RGBA = RGBA(r: 0, g: 0, b: 0, a: 1)
        var outlineWidth: Double = 0

        init(
            enabled: Bool = false,
            color: RGBA = RGBA(r: 0, g: 0, b: 0, a: 0.6),
            paddingX: Double = 0,
            paddingY: Double = 0,
            cornerRadius: Double = 0,
            offsetX: Double = 0,
            offsetY: Double = 0,
            outlineColor: RGBA = RGBA(r: 0, g: 0, b: 0, a: 1),
            outlineWidth: Double = 0
        ) {
            self.enabled = enabled
            self.color = color
            self.paddingX = paddingX
            self.paddingY = paddingY
            self.cornerRadius = cornerRadius
            self.offsetX = offsetX
            self.offsetY = offsetY
            self.outlineColor = outlineColor
            self.outlineWidth = outlineWidth
        }

        private enum CodingKeys: String, CodingKey {
            case enabled, color, paddingX, paddingY, cornerRadius, offsetX, offsetY, outlineColor, outlineWidth
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                enabled: (try? c.decode(Bool.self, forKey: .enabled)) ?? false,
                color: (try? c.decode(RGBA.self, forKey: .color)) ?? RGBA(r: 0, g: 0, b: 0, a: 0.6),
                paddingX: (try? c.decode(Double.self, forKey: .paddingX)) ?? 0,
                paddingY: (try? c.decode(Double.self, forKey: .paddingY)) ?? 0,
                cornerRadius: (try? c.decode(Double.self, forKey: .cornerRadius)) ?? 0,
                offsetX: (try? c.decode(Double.self, forKey: .offsetX)) ?? 0,
                offsetY: (try? c.decode(Double.self, forKey: .offsetY)) ?? 0,
                outlineColor: (try? c.decode(RGBA.self, forKey: .outlineColor)) ?? RGBA(r: 0, g: 0, b: 0, a: 1),
                outlineWidth: (try? c.decode(Double.self, forKey: .outlineWidth)) ?? 0
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case fontName, fontSize, fontScale, widthScale, heightScale, tracking, lineSpacing, fontCase
        case isBold, isItalic, isUnderlined, isStruckThrough, isOverlined
        case color, alignment, blur, shadow, background, border
    }
}

extension TextStyle {
    static var caption: TextStyle { TextStyle(fontSize: AppTheme.Caption.defaultFontSize) }
}

extension TextStyle {
    /// Missing-key-tolerant decode — older files pick up defaults for fields added later.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = TextStyle()
        let fontName = (try? c.decode(String.self, forKey: .fontName)) ?? defaults.fontName
        let fontSize = (try? c.decode(Double.self, forKey: .fontSize)) ?? defaults.fontSize
        #if canImport(AppKit)
        let inferredBold = Self.symbolicTraits(fontName: fontName, size: CGFloat(fontSize)).contains(.traitBold)
        let inferredItalic = Self.symbolicTraits(fontName: fontName, size: CGFloat(fontSize)).contains(.traitItalic)
        #else
        let inferredBold = defaults.isBold
        let inferredItalic = defaults.isItalic
        #endif
        self.init(
            fontName: fontName,
            fontSize: fontSize,
            fontScale: (try? c.decode(Double.self, forKey: .fontScale)) ?? defaults.fontScale,
            widthScale: (try? c.decode(Double.self, forKey: .widthScale)) ?? defaults.widthScale,
            heightScale: (try? c.decode(Double.self, forKey: .heightScale)) ?? defaults.heightScale,
            tracking: (try? c.decode(Double.self, forKey: .tracking)) ?? defaults.tracking,
            lineSpacing: (try? c.decode(Double.self, forKey: .lineSpacing)) ?? defaults.lineSpacing,
            fontCase: (try? c.decode(FontCase.self, forKey: .fontCase)) ?? defaults.fontCase,
            isBold: (try? c.decode(Bool.self, forKey: .isBold)) ?? inferredBold,
            isItalic: (try? c.decode(Bool.self, forKey: .isItalic)) ?? inferredItalic,
            isUnderlined: (try? c.decode(Bool.self, forKey: .isUnderlined)) ?? defaults.isUnderlined,
            isStruckThrough: (try? c.decode(Bool.self, forKey: .isStruckThrough)) ?? defaults.isStruckThrough,
            isOverlined: (try? c.decode(Bool.self, forKey: .isOverlined)) ?? defaults.isOverlined,
            color: (try? c.decode(RGBA.self, forKey: .color)) ?? defaults.color,
            alignment: (try? c.decode(Alignment.self, forKey: .alignment)) ?? defaults.alignment,
            blur: (try? c.decode(Double.self, forKey: .blur)) ?? defaults.blur,
            shadow: (try? c.decode(Shadow.self, forKey: .shadow)) ?? defaults.shadow,
            background: (try? c.decode(Background.self, forKey: .background)) ?? defaults.background,
            border: (try? c.decode(Outline.self, forKey: .border)) ?? defaults.border
        )
    }
}

// MARK: - Rendering helpers

extension TextStyle.RGBA {
    mutating func setRGB(from color: Self) {
        r = color.r
        g = color.g
        b = color.b
    }

    var hexString: String {
        let bytes = [r, g, b, a].map { Int((min(max($0, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X%02X", bytes[0], bytes[1], bytes[2], bytes[3])
    }

    /// Accepts `#RGB`, `#RRGGBB`, or `#RRGGBBAA`. Leading `#` optional.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        let chars = Array(s)
        func component(_ start: Int, _ len: Int) -> Double? {
            let slice = String(chars[start..<start + len])
            let byteStr = len == 1 ? slice + slice : slice
            guard let n = UInt8(byteStr, radix: 16) else { return nil }
            return Double(n) / 255.0
        }
        switch chars.count {
        case 3:
            guard let r = component(0, 1), let g = component(1, 1), let b = component(2, 1) else { return nil }
            self.init(r: r, g: g, b: b, a: 1)
        case 6:
            guard let r = component(0, 2), let g = component(2, 2), let b = component(4, 2) else { return nil }
            self.init(r: r, g: g, b: b, a: 1)
        case 8:
            guard let r = component(0, 2), let g = component(2, 2),
                  let b = component(4, 2), let a = component(6, 2) else { return nil }
            self.init(r: r, g: g, b: b, a: a)
        default:
            return nil
        }
    }
}


extension TextStyle {
    var scaledVisualStyle: TextStyle {
        guard fontScale != 1 else { return self }
        var style = self
        style.fontSize *= fontScale
        style.tracking *= fontScale
        style.lineSpacing *= fontScale
        style.shadow.offsetX *= fontScale
        style.shadow.offsetY *= fontScale
        style.shadow.blur *= fontScale
        style.border.width *= fontScale
        style.background.paddingX *= fontScale
        style.background.paddingY *= fontScale
        style.background.cornerRadius *= fontScale
        style.background.offsetX *= fontScale
        style.background.offsetY *= fontScale
        style.background.outlineWidth *= fontScale
        style.fontScale = 1
        return style
    }

    func displayText(_ text: String) -> String {
        fontCase.apply(to: text)
    }

    /// Two-pass outlines need an opaque fill; translucent fills would show the undercoat through them.
    var drawsGlyphOutline: Bool {
        border.enabled && border.width > 0 && color.a >= 1
    }


    func glyphBorderPadding(fontSize: CGFloat) -> CGFloat {
        ceil(fontSize * CGFloat(max(0, border.width)) / CGFloat(max(1, self.fontSize * fontScale)))
    }
}
