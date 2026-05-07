import Foundation

public struct SubtitleLine: Identifiable {
    public let id = UUID()
    public let index: Int
    public let start: Double
    public let end: Double
    public let text: String
    
    public init(index: Int, start: Double, end: Double, text: String) {
        self.index = index
        self.start = start
        self.end = end
        self.text = text
    }
    
    public var timeString: String {
        let s = formatTime(start)
        let e = formatTime(end)
        return "\(s) --> \(e)"
    }
    
    private func formatTime(_ t: Double) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        let ms = Int((t - floor(t)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
    }
}
