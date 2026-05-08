import Foundation

public class WebVTT: SubtitleFormat {
    private static let regexTimeCodes = try! NSRegularExpression(pattern: "^-?\\d+:-?\\d+:-?\\d+\\.-?\\d+\\s*-->\\s*-?\\d+:-?\\d+:-?\\d+\\.-?\\d+", options: [])
    private static let regexTimeCodesMiddle = try! NSRegularExpression(pattern: "^-?\\d+:-?\\d+\\.-?\\d+\\s*-->\\s*-?\\d+:-?\\d+:-?\\d+\\.-?\\d+", options: [])
    private static let regexTimeCodesShort = try! NSRegularExpression(pattern: "^-?\\d+:-?\\d+\\.-?\\d+\\s*-->\\s*-?\\d+:-?\\d+\\.-?\\d+", options: [])

    public override var extensionName: String {
        return ".vtt"
    }

    public override var name: String {
        return "WebVTT"
    }

    public override func isMine(lines: [String], fileName: String?) -> Bool {
        if lines.count > 0 && lines[0].lowercased().hasPrefix("webvtt") {
            return true
        }
        return false
    }

    public override func toText(subtitle: Subtitle, title: String) -> String {
        var sb = "WEBVTT\n\n"
        if !subtitle.header.isEmpty && subtitle.header.hasPrefix("WEBVTT") {
            sb = subtitle.header + "\n\n"
        }
        
        for p in subtitle.paragraphs {
            let start = formatTime(p.startTime)
            let end = formatTime(p.endTime)
            sb += "\(start) --> \(end)\n\(p.text)\n\n"
        }
        return sb.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
    }

    private func formatTime(_ tc: TimeCode) -> String {
        return String(format: "%02d:%02d:%02d.%03d", tc.hours, tc.minutes, tc.seconds, tc.milliseconds)
    }

    public override func loadSubtitle(subtitle: Subtitle, lines: [String], fileName: String?) {
        subtitle.paragraphs.removeAll()
        var p: Paragraph?
        var noteOn = false
        var styleOn = false
        var regionOn = false
        var header = "WEBVTT\n"

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if index == 0 && trimmedLine.hasPrefix("WEBVTT") {
                header = line + "\n"
                continue
            }

            if index > 0 && lines[index-1].isEmpty && (trimmedLine == "NOTE" || trimmedLine.hasPrefix("NOTE ")) {
                noteOn = true
                continue
            } else if (trimmedLine == "STYLE" || trimmedLine.hasPrefix("STYLE ")) && subtitle.paragraphs.count == 0 {
                styleOn = true
                continue
            } else if (trimmedLine == "REGION" || trimmedLine.hasPrefix("REGION ")) && subtitle.paragraphs.count == 0 {
                regionOn = true
                continue
            }

            if (styleOn || regionOn || noteOn) && !trimmedLine.isEmpty {
                header += line + "\n"
                continue
            }

            noteOn = false
            styleOn = false
            regionOn = false

            let isTimeCode = line.contains("-->")
            if isTimeCode && isMatch(line, regex: WebVTT.regexTimeCodes) || isMatch(line, regex: WebVTT.regexTimeCodesMiddle) || isMatch(line, regex: WebVTT.regexTimeCodesShort) {
                if let paragraph = p {
                    subtitle.paragraphs.append(paragraph)
                }
                
                let parts = line.replacingOccurrences(of: "-->", with: "@").components(separatedBy: "@")
                if parts.count >= 2 {
                    p = Paragraph()
                    p?.startTime = parseTime(parts[0])
                    p?.endTime = parseTime(parts[1])
                }
            } else if let paragraph = p {
                if trimmedLine.isEmpty {
                    if !paragraph.text.isEmpty {
                        subtitle.paragraphs.append(paragraph)
                        p = nil
                    }
                } else {
                    if !paragraph.text.isEmpty {
                        paragraph.text += "\n"
                    }
                    paragraph.text += trimmedLine
                }
            }
        }

        if let paragraph = p {
            subtitle.paragraphs.append(paragraph)
        }
        
        subtitle.header = header.trimmingCharacters(in: .whitespacesAndNewlines)
        subtitle.renumber()
    }

    private func isMatch(_ input: String, regex: NSRegularExpression) -> Bool {
        let range = NSRange(location: 0, length: input.utf16.count)
        return regex.firstMatch(in: input, options: [], range: range) != nil
    }

    private func parseTime(_ input: String) -> TimeCode {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.replacingOccurrences(of: ".", with: ":").components(separatedBy: ":")
        
        var h = 0, m = 0, s = 0, ms = 0
        
        if parts.count == 4 {
            h = Int(parts[0]) ?? 0
            m = Int(parts[1]) ?? 0
            s = Int(parts[2]) ?? 0
            ms = Int(parts[3]) ?? 0
        } else if parts.count == 3 {
            m = Int(parts[0]) ?? 0
            s = Int(parts[1]) ?? 0
            ms = Int(parts[2]) ?? 0
        }
        
        return TimeCode(hours: h, minutes: m, seconds: s, milliseconds: ms)
    }
}
