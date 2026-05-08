import Foundation

class SubtitleParser {
    static func parseSRT(content: String) -> [SubtitleItem] {
        var items: [SubtitleItem] = []
        // Normalize line endings to \n and split by double \n
        let normalizedContent = content.replacingOccurrences(of: "\r\n", with: "\n")
        let blocks = normalizedContent.components(separatedBy: "\n\n")
        
        for block in blocks {
            let lines = block.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard lines.count >= 3 else { continue }
            
            // 1. Index (may not always be an integer in malformed files, but we try)
            guard let index = Int(lines[0]) else { continue }
            
            // 2. Time Range
            let timeRangeLine = lines[1]
            let times = timeRangeLine.components(separatedBy: " --> ")
            guard times.count == 2 else { continue }
            
            let start = parseTime(times[0])
            let end = parseTime(times[1])
            
            // 3. Text (all remaining lines)
            let text = lines[2...].joined(separator: "\n")
            
            items.append(SubtitleItem(index: index, startTime: start, endTime: end, text: text))
        }
        
        return items
    }
    
    private static func parseTime(_ timeString: String) -> Double {
        // Format: 00:00:20,000
        let parts = timeString.replacingOccurrences(of: ",", with: ".").components(separatedBy: ":")
        guard parts.count == 3 else { return 0 }
        
        let hours = Double(parts[0]) ?? 0
        let minutes = Double(parts[1]) ?? 0
        let seconds = Double(parts[2]) ?? 0
        
        return (hours * 3600) + (minutes * 60) + seconds
    }
}
