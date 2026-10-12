import Foundation

/// Canonical effect-stack ordering shared by the UI and portable model helpers.
/// CI-backed descriptors live in `EffectRegistry.swift` (macOS-only).
enum EffectRegistry {
    static let canonicalOrder: [String] = [
        "color.exposure", "color.contrast", "color.highlightsShadows", "color.blacksWhites",
        "color.temperature", "color.vibrance", "color.saturation", "color.wheels", "color.curves",
        "color.hueCurves", "color.lut", "detail.clarity", "key.chroma", "blur.gaussian", "blur.sharpen",
        "blur.noiseReduction", "blur.motion", "stylize.invert", "stylize.grain", "stylize.vignette",
        "stylize.glow",
    ]

    static func insertIndex(_ effects: [Effect], for id: String) -> Int {
        let rank = canonicalOrder.firstIndex(of: id) ?? Int.max
        return effects.firstIndex { (canonicalOrder.firstIndex(of: $0.type) ?? Int.max) > rank } ?? effects.count
    }
}
