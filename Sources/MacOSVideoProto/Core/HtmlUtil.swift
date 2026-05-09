import Foundation
import SwiftUI
import AppKit

public class HtmlUtil {
    public static func removeHtmlTags(_ input: String) -> String {
        if input.count < 3 || !input.contains("<") {
            return input
        }
        
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
    
    public var attributedString: AttributedString {
        if self.isEmpty { return AttributedString("") }
        
        // 1. For plain text without tags, apply standard 13px font
        if !self.contains("<") { 
            var attr = AttributedString(self)
            attr.font = .system(size: 13)
            return attr 
        }
        
        // 2. For tagged text, use HTML engine with precise CSS sizing
        // Using '13px' to match SwiftUI's .system(size: 13)
        let htmlString = "<span style=\"font-family: -apple-system; font-size: 13px; color: white;\">\(self.replacingOccurrences(of: "\n", with: "<br>"))</span>"
        guard let data = htmlString.data(using: .utf16),
              let nsAttrStr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf16.rawValue],
                documentAttributes: nil) else {
            return AttributedString(self.removeHtmlTags())
        }
        
        // This conversion preserves bold/italic traits and uses the 13px size from CSS
        return AttributedString(nsAttrStr)
    }
}
