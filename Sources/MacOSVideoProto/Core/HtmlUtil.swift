import Foundation

public class HtmlUtil {
    public static func removeHtmlTags(_ input: String) -> String {
        if input.count < 3 {
            return input
        }
        
        if !input.contains("<") {
            return input
        }
        
        // Simple regex-based tag removal for common tags (i, b, u, font)
        let pattern = "<[^>]+>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: input.utf16.count)
            return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: "")
        }
        
        return input
    }
}

extension String {
    public func removeHtmlTags() -> String {
        return HtmlUtil.removeHtmlTags(self)
    }
}
