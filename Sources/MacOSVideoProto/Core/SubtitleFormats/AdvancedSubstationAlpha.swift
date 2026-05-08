import Foundation

public class AdvancedSubstationAlpha: SubtitleFormat {
    public override var extensionName: String {
        return ".ass"
    }

    public override var name: String {
        return "Advanced Substation Alpha"
    }

    public override func isMine(lines: [String], fileName: String?) -> Bool {
        for line in lines {
            if line.contains("[Events]") || line.contains("Format: Layer, Start, End, Style") {
                return true
            }
        }
        return false
    }

    public override func loadSubtitle(subtitle: Subtitle, lines: [String], fileName: String?) {
        subtitle.paragraphs.removeAll()
        var eventsReached = false
        var format: [String] = []
        var header = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased() == "[events]" {
                eventsReached = true
                header += line + "\n"
                continue
            }

            if !eventsReached {
                header += line + "\n"
                continue
            }

            if trimmed.hasPrefix("Format:") {
                format = trimmed.replacingOccurrences(of: "Format:", with: "").components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                header += line + "\n"
                continue
            }

            if trimmed.hasPrefix("Dialogue:") {
                let rawData = line.replacingOccurrences(of: "Dialogue:", with: "").trimmingCharacters(in: .whitespaces)
                let parts = splitData(rawData, count: format.count)
                
                if parts.count >= format.count {
                    let p = Paragraph()
                    for (i, field) in format.enumerated() {
                        let value = parts[i].trimmingCharacters(in: .whitespaces)
                        switch field.lowercased() {
                        case "start":
                            p.startTime = parseTime(value)
                        case "end":
                            p.endTime = parseTime(value)
                        case "text":
                            p.text = value.replacingOccurrences(of: "\\N", with: "\n")
                                         .replacingOccurrences(of: "\\n", with: "\n")
                        case "style":
                            p.style = value
                        case "name":
                            p.actor = value
                        default:
                            break
                        }
                    }
                    subtitle.paragraphs.append(p)
                }
            } else {
                header += line + "\n"
            }
        }
        
        subtitle.header = header.trimmingCharacters(in: .whitespacesAndNewlines)
        subtitle.renumber()
    }

    private func splitData(_ data: String, count: Int) -> [String] {
        var parts: [String] = []
        var current = data
        for _ in 0..<count-1 {
            if let range = current.range(of: ",") {
                parts.append(String(current[..<range.lowerBound]))
                current = String(current[range.upperBound...])
            } else {
                break
            }
        }
        parts.append(current)
        return parts
    }

    private func parseTime(_ input: String) -> TimeCode {
        // Format: h:mm:ss.cc (centiseconds)
        let parts = input.replacingOccurrences(of: ".", with: ":").components(separatedBy: ":")
        if parts.count == 4 {
            let h = Int(parts[0]) ?? 0
            let m = Int(parts[1]) ?? 0
            let s = Int(parts[2]) ?? 0
            let cs = Int(parts[3]) ?? 0 // centiseconds
            return TimeCode(hours: h, minutes: m, seconds: s, milliseconds: cs * 10)
        }
        return TimeCode()
    }
}
