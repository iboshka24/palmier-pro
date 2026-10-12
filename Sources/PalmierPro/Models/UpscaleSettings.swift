import Foundation

struct UpscaleSettings: Codable, Sendable, Equatable {
    var selections: [String: String] = [:]
    var numbers: [String: Double] = [:]
    var toggles: [String: Bool] = [:]
}
