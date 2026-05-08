import Foundation

class SubtitleParser {
    static func parse(content: String, fileName: String? = nil) -> Subtitle? {
        let lines = content.components(separatedBy: .newlines)
        let subtitle = Subtitle()
        
        for format in SubtitleFormat.allSubtitleFormats {
            if format.isMine(lines: lines, fileName: fileName) {
                format.loadSubtitle(subtitle: subtitle, lines: lines, fileName: fileName)
                return subtitle
            }
        }
        
        // Default to SubRip if nothing else matches (as SE sometimes does)
        let subRip = SubRip()
        subRip.loadSubtitle(subtitle: subtitle, lines: lines, fileName: fileName)
        return subtitle
    }
}
