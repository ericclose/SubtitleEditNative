import Foundation

public class TimeFormatter: Formatter {
    public override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override func string(for obj: Any?) -> String? {
        guard let seconds = obj as? Double else { return nil }
        let h = Int(seconds / 3600)
        let m = Int((seconds / 60).truncatingRemainder(dividingBy: 60))
        let s = Int(seconds.truncatingRemainder(dividingBy: 60))
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1) * 1000).rounded())
        return String(format: "%02d:%02d:%02d.%03d", h, m, s, ms)
    }
    
    public override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        let parts = string.split(separator: ":")
        if parts.count == 3 {
            let h = Double(parts[0]) ?? 0
            let m = Double(parts[1]) ?? 0
            let sParts = parts[2].split(separator: ".")
            let s = Double(sParts[0]) ?? 0
            let ms = sParts.count > 1 ? Double(sParts[1]) ?? 0 : 0
            obj?.pointee = (h * 3600 + m * 60 + s + ms / 1000.0) as AnyObject
            return true
        }
        return false
    }
}

public func calculateCPS(text: String, start: Double, end: Double) -> Double {
    let duration = end - start
    guard duration > 0 else { return 0 }
    return Double(text.count) / duration
}
