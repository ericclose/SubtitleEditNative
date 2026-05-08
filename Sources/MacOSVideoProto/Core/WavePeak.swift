import Foundation

struct WavePeak: Codable, Sendable {
    var min: Float
    var max: Float
    
    var abs: Float {
        Swift.max(Swift.abs(min), Swift.abs(max))
    }
}
