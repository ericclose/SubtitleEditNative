import Foundation

public struct SubtitleLine: Identifiable, Equatable {
    public var id: UUID
    public let index: Int
    public let start: Double
    public let end: Double
    public let text: String
    public var gap: Double?
    
    public init(id: UUID = UUID(), index: Int, start: Double, end: Double, text: String, gap: Double? = nil) {
        self.id = id
        self.index = index
        self.start = start
        self.end = end
        self.text = text
        self.gap = gap
    }
    
    public var timeString: String {
        return "\(startTimeString) --> \(endTimeString)"
    }
    
    public var duration: Double {
        return end - start
    }
    
    public var cps: Double {
        guard duration > 0 else { return 0 }
        return Double(text.count) / duration
    }
    
    public var wpm: Double {
        guard duration > 0 else { return 0 }
        let wordCount = text.split(separator: " ").count
        return (Double(wordCount) / duration) * 60.0
    }
    
    public var startTimeString: String { formatTime(start) }
    public var endTimeString: String { formatTime(end) }
    public var durationString: String { String(format: "%.3f", duration) }

    private func formatTime(_ t: Double) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        let ms = Int((t.truncatingRemainder(dividingBy: 1) * 1000).rounded())
        return String(format: "%02d:%02d:%02d.%03d", h, m, s, ms)
    }
}
