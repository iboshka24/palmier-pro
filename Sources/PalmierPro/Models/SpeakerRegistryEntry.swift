import Foundation

/// Persisted per-project speaker identity.
struct SpeakerRegistryEntry: Codable, Sendable, Identifiable {
    var id: Int
    var name: String
    var color: [Double]
    var centroid: [Float]
}
