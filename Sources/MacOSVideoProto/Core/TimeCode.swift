import Foundation

public class TimeCode {
    public static let timeSplitChars: CharacterSet = CharacterSet(charactersIn: ":,.")
    public static let baseUnit: Double = 1000.0
    
    public static let maxTimeTotalMilliseconds: Double = 359999999 // new TimeCode(99, 59, 59, 999).totalMilliseconds
    
    public var totalMilliseconds: Double
    
    public var isMaxTime: Bool {
        return abs(totalMilliseconds - TimeCode.maxTimeTotalMilliseconds) < 0.01
    }
    
    public static func fromSeconds(_ seconds: Double) -> TimeCode {
        return TimeCode(totalMilliseconds: seconds * baseUnit)
    }
    
    public init(totalMilliseconds: Double = 0) {
        self.totalMilliseconds = totalMilliseconds
    }
    
    public init(hours: Int, minutes: Int, seconds: Int, milliseconds: Int) {
        self.totalMilliseconds = Double(hours) * 60 * 60 * TimeCode.baseUnit +
                                 Double(minutes) * 60 * TimeCode.baseUnit +
                                 Double(seconds) * TimeCode.baseUnit +
                                 Double(milliseconds)
    }
    
    public var hours: Int {
        get {
            return Int(totalMilliseconds / (3600 * TimeCode.baseUnit))
        }
        set {
            let current = hours
            totalMilliseconds += Double(newValue - current) * 3600 * TimeCode.baseUnit
        }
    }
    
    public var minutes: Int {
        get {
            return (Int(totalMilliseconds / (60 * TimeCode.baseUnit))) % 60
        }
        set {
            let current = minutes
            totalMilliseconds += Double(newValue - current) * 60 * TimeCode.baseUnit
        }
    }
    
    public var seconds: Int {
        get {
            return (Int(totalMilliseconds / TimeCode.baseUnit)) % 60
        }
        set {
            let current = seconds
            totalMilliseconds += Double(newValue - current) * TimeCode.baseUnit
        }
    }
    
    public var milliseconds: Int {
        get {
            return Int(totalMilliseconds) % 1000
        }
        set {
            let current = milliseconds
            totalMilliseconds += Double(newValue - current)
        }
    }
    
    public var totalSeconds: Double {
        get { return totalMilliseconds / TimeCode.baseUnit }
        set { totalMilliseconds = newValue * TimeCode.baseUnit }
    }
    
    public func toString(localize: Bool = false) -> String {
        let h = hours
        let m = minutes
        let s = seconds
        let ms = milliseconds
        
        let decimalSeparator = localize ? (Locale.current.decimalSeparator ?? ",") : ","
        let formatted = String(format: "%02d:%02d:%02d%@%03d", h, m, s, decimalSeparator, ms)
        
        return prefixSign(formatted)
    }
    
    private func prefixSign(_ time: String) -> String {
        if totalMilliseconds >= 0 {
            return time
        } else {
            return "-" + time.replacingOccurrences(of: "-", with: "")
        }
    }
    
    public func toDisplayString() -> String {
        if isMaxTime {
            return "-"
        }
        return toString(localize: true)
    }
}

extension TimeCode: CustomStringConvertible {
    public var description: String {
        return toString()
    }
}

extension TimeCode: Equatable {
    public static func == (lhs: TimeCode, rhs: TimeCode) -> Bool {
        return abs(lhs.totalMilliseconds - rhs.totalMilliseconds) < 0.01
    }
}
