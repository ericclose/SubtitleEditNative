import Foundation

public class SubRip: SubtitleFormat {
    private enum ExpectingLine {
        case number
        case timeCodes
        case text
    }
    
    private var paragraph: Paragraph?
    private var lastParagraph: Paragraph?
    private var expecting: ExpectingLine = .number
    private var errorCount: Int = 0
    private var lineNumber: Int = 0
    
    public override var extensionName: String {
        return ".srt"
    }
    
    public override var name: String {
        return "SubRip"
    }
    
    public override func isMine(lines: [String], fileName: String?) -> Bool {
        if lines.count > 0 && lines[0].lowercased().hasPrefix("webvtt") {
            return false
        }
        
        let subtitle = Subtitle()
        loadSubtitle(subtitle: subtitle, lines: lines, fileName: fileName)
        return subtitle.paragraphs.count > 0
    }
    
    public override func toText(subtitle: Subtitle, title: String) -> String {
        var text = ""
        for p in subtitle.paragraphs {
            text += "\(p.number)\n"
            text += "\(p.startTime.toString()) --> \(p.endTime.toString())\n"
            text += "\(p.text)\n\n"
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
    }
    
    public override func loadSubtitle(subtitle: Subtitle, lines: [String], fileName: String?) {
        lineNumber = 0
        paragraph = Paragraph()
        expecting = .number
        errorCount = 0
        
        subtitle.paragraphs.removeAll()
        
        let linesCount = lines.count
        for i in 0..<linesCount {
            lineNumber += 1
            let line = lines[i].trimmingCharacters(in: .controlCharacters)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            let next = (i + 1 < linesCount) ? lines[i + 1].trimmingCharacters(in: .controlCharacters) : ""
            let nextNext = (i + 2 < linesCount) ? lines[i + 2].trimmingCharacters(in: .controlCharacters) : ""
            let nextNextNext = (i + 3 < linesCount) ? lines[i + 3].trimmingCharacters(in: .controlCharacters) : ""
            
            // Check for missing line between paragraphs
            if expecting == .text && i + 1 < linesCount && !(paragraph?.text.isEmpty ?? true) &&
                isInteger(trimmedLine) && tryReadTimeCodesLine(input: trimmedLine, paragraph: nil) {
                if let p = paragraph, !p.text.isEmpty {
                    subtitle.paragraphs.append(p)
                    lastParagraph = p
                    paragraph = Paragraph()
                }
                expecting = .number
            }
            
            if expecting == .number && tryReadTimeCodesLine(input: trimmedLine, paragraph: nil) {
                expecting = .timeCodes
            } else if !(paragraph?.text.isEmpty ?? true) && expecting == .text && tryReadTimeCodesLine(input: trimmedLine, paragraph: nil) {
                if let p = paragraph {
                    subtitle.paragraphs.append(p)
                    lastParagraph = p
                }
                paragraph = Paragraph()
                expecting = .timeCodes
            }
            
            readLine(subtitle: subtitle, line: line, next: next, nextNext: nextNext, nextNextNext: nextNextNext)
        }
        
        if let p = paragraph, !p.isDefault || expecting == .text {
            subtitle.paragraphs.append(p)
        }
        
        subtitle.renumber()
        
        for p in subtitle.paragraphs {
            p.text = p.text.trimmingCharacters(in: .whitespaces)
        }
    }
    
    private func readLine(subtitle: Subtitle, line: String, next: String, nextNext: String, nextNextNext: String) {
        switch expecting {
        case .number:
            if let number = Int(line.trimmingCharacters(in: .whitespaces)) {
                paragraph?.number = number
                expecting = .timeCodes
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                // Potential error handling here
                errorCount += 1
            }
        case .timeCodes:
            if tryReadTimeCodesLine(input: line, paragraph: paragraph) {
                paragraph?.text = ""
                expecting = .text
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                errorCount += 1
                expecting = .number
            }
        case .text:
            if isInteger(line) && (tryReadTimeCodesLine(input: next, paragraph: nil) || (next.isEmpty && tryReadTimeCodesLine(input: nextNext, paragraph: nil))) {
                if let p = paragraph {
                    subtitle.paragraphs.append(p)
                    lastParagraph = p
                }
                paragraph = Paragraph()
                expecting = .number
                if let n = Int(line.trimmingCharacters(in: .whitespaces)) {
                    paragraph?.number = n
                }
            } else if tryReadTimeCodesLine(input: line, paragraph: nil) {
                if let p = paragraph, (p.endTime.totalMilliseconds > 0 || !p.text.isEmpty) {
                    subtitle.paragraphs.append(p)
                    lastParagraph = p
                }
                paragraph = Paragraph()
                _ = tryReadTimeCodesLine(input: line, paragraph: paragraph)
                expecting = .text
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty || isText(next) || isText(nextNext) {
                if let p = paragraph {
                    if !p.text.isEmpty {
                        p.text += "\n"
                    }
                    p.text += line.replacingOccurrences(of: "\0", with: " ").trimmingCharacters(in: .whitespaces)
                }
            } else if line.isEmpty && (paragraph?.text.isEmpty ?? true) {
                // Skip empty lines at start of text
            } else {
                if let p = paragraph {
                    subtitle.paragraphs.append(p)
                    lastParagraph = p
                }
                paragraph = Paragraph()
                expecting = .number
            }
        }
    }
    
    private func isText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return !(trimmed.isEmpty || isInteger(trimmed) || tryReadTimeCodesLine(input: trimmed, paragraph: nil))
    }
    
    private func isInteger(_ s: String) -> Bool {
        return Int(s.trimmingCharacters(in: .whitespaces)) != nil
    }
    
    private func tryReadTimeCodesLine(input: String, paragraph: Paragraph?) -> Bool {
        let trimmedInput = input.trimmingCharacters(in: .whitespaces)
        if trimmedInput.isEmpty || trimmedInput.count < 10 {
            return false
        }
        
        var line = trimmedInput.replacingOccurrences(of: " -> ", with: " --> ")
        line = line.replacingOccurrences(of: "  ", with: " ")
        
        if isValidTimeCode(line) {
            let parts = line.replacingOccurrences(of: "-->", with: ":")
                            .replacingOccurrences(of: ",", with: ":")
                            .replacingOccurrences(of: ".", with: ":")
                            .components(separatedBy: ":")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
            
            if parts.count >= 8 {
                let startHours = Int(parts[0]) ?? 0
                let startMinutes = Int(parts[1]) ?? 0
                let startSeconds = Int(parts[2]) ?? 0
                let startMilliseconds = Int(parts[3]) ?? 0
                
                let endHours = Int(parts[4]) ?? 0
                let endMinutes = Int(parts[5]) ?? 0
                let endSeconds = Int(parts[6]) ?? 0
                let endMilliseconds = Int(parts[7]) ?? 0
                
                if let p = paragraph {
                    p.startTime = TimeCode(hours: startHours, minutes: startMinutes, seconds: startSeconds, milliseconds: startMilliseconds)
                    p.endTime = TimeCode(hours: endHours, minutes: endMinutes, seconds: endSeconds, milliseconds: endMilliseconds)
                }
                return true
            }
        }
        return false
    }
    
    private func isValidTimeCode(_ line: String) -> Bool {
        // Simple version of SE's validation for now
        return line.contains(" --> ")
    }
}
