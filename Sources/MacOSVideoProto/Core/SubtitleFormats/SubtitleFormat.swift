import Foundation

public struct Configuration {
    public struct Settings {
        public struct General {
            public static var currentFrameRate: Double = 23.976
            public static var subtitleMinimumDisplayMilliseconds: Int = 100
            public static var subtitleMaximumDisplayMilliseconds: Int = 8000
            public static var minimumMillisecondsBetweenLines: Int = 24
        }
    }
}

open class SubtitleFormat {
    public static let allSubtitleFormats: [SubtitleFormat] = [
        SubRip(),
        WebVTT(),
        AdvancedSubstationAlpha()
    ]
    
    public init() {}
    
    open var extensionName: String {
        return ""
    }
    
    open var name: String {
        return ""
    }
    
    open var isTimeBased: Bool {
        return true
    }
    
    open func isMine(lines: [String], fileName: String?) -> Bool {
        return false
    }
    
    open func toText(subtitle: Subtitle, title: String) -> String {
        return ""
    }
    
    open func loadSubtitle(subtitle: Subtitle, lines: [String], fileName: String?) {
        // To be implemented by subclasses
    }
    
    // Frame rate conversion methods from SE
    public static func millisecondsToFrames(milliseconds: Double) -> Int {
        return millisecondsToFrames(milliseconds: milliseconds, frameRate: Configuration.Settings.General.currentFrameRate)
    }
    
    public static func millisecondsToFrames(milliseconds: Double, frameRate: Double) -> Int {
        return Int(round(milliseconds / (TimeCode.baseUnit / getFrameForCalculation(frameRate: frameRate))))
    }
    
    public static func getFrameForCalculation(frameRate: Double) -> Double {
        if abs(frameRate - 23.976) < 0.001 {
            return 24000.0 / 1001.0
        }
        if abs(frameRate - 29.97) < 0.001 {
            return 30000.0 / 1001.0
        }
        if abs(frameRate - 59.94) < 0.001 {
            return 60000.0 / 1001.0
        }
        return frameRate
    }
    
    public static func millisecondsToFramesMaxFrameRate(milliseconds: Double) -> Int {
        var frames = Int(round(milliseconds / (TimeCode.baseUnit / getFrameForCalculation(frameRate: Configuration.Settings.General.currentFrameRate))))
        if Double(frames) >= Configuration.Settings.General.currentFrameRate {
            frames = Int(Configuration.Settings.General.currentFrameRate - 0.01)
        }
        return frames
    }
    
    public static func framesToMilliseconds(frames: Double) -> Int {
        return framesToMilliseconds(frames: frames, frameRate: Configuration.Settings.General.currentFrameRate)
    }
    
    public static func framesToMilliseconds(frames: Double, frameRate: Double) -> Int {
        return Int(round(frames * (TimeCode.baseUnit / getFrameForCalculation(frameRate: frameRate))))
    }
    
    public static func framesToMillisecondsMax999(frames: Double) -> Int {
        let ms = Int(round(frames * (TimeCode.baseUnit / getFrameForCalculation(frameRate: Configuration.Settings.General.currentFrameRate))))
        return min(ms, 999)
    }
}
