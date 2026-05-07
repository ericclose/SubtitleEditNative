import SwiftUI
import AppKit

extension Color {
    public func toHex() -> String? {
        let nscolor = NSColor(self)
        guard let rgbColor = nscolor.usingColorSpace(.deviceRGB) else { return nil }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
