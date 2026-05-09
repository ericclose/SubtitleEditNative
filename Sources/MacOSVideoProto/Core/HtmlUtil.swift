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
        let plainText = self.removeHtmlTags()
        var attrStr = AttributedString(plainText)
        let nsString = self as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        
        // 1. Italic <i>...</i>
        if let regex = try? NSRegularExpression(pattern: "<i>(.*?)</i>", options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            for match in regex.matches(in: self, range: fullRange) where match.numberOfRanges > 1 {
                let inner = nsString.substring(with: match.range(at: 1))
                if let r = attrStr.range(of: inner) {
                    attrStr[r].font = Font.system(size: 10).italic()
                }
            }
        }
        
        // 2. Bold <b>...</b>
        if let regex = try? NSRegularExpression(pattern: "<b>(.*?)</b>", options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            for match in regex.matches(in: self, range: fullRange) where match.numberOfRanges > 1 {
                let inner = nsString.substring(with: match.range(at: 1))
                if let r = attrStr.range(of: inner) {
                    attrStr[r].font = Font.system(size: 10, weight: .bold)
                }
            }
        }
        
        // 3. Underline <u>...</u>
        if let regex = try? NSRegularExpression(pattern: "<u>(.*?)</u>", options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            for match in regex.matches(in: self, range: fullRange) where match.numberOfRanges > 1 {
                let inner = nsString.substring(with: match.range(at: 1))
                if let r = attrStr.range(of: inner) {
                    attrStr[r].underlineStyle = .single
                }
            }
        }
        
        // 4. Color <font color="...">...</font>
        let colorPattern = "<font color=\"?(#[0-9A-Fa-f]{6})\"?>(.*?)</font>"
        if let regex = try? NSRegularExpression(pattern: colorPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            for match in regex.matches(in: self, range: fullRange) where match.numberOfRanges > 2 {
                let hex = nsString.substring(with: match.range(at: 1))
                let inner = nsString.substring(with: match.range(at: 2))
                if let r = attrStr.range(of: inner), let color = NSColor(hex: hex) {
                    attrStr[r].foregroundColor = Color(color)
                }
            }
        }
        
        return attrStr
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
