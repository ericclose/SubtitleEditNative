import Foundation

public class Paragraph: Identifiable {
    public let id: String
    public var number: Int
    public var text: String
    public var startTime: TimeCode
    public var endTime: TimeCode
    
    public var forced: Bool = false
    public var extra: String?
    public var isComment: Bool = false
    public var actor: String?
    public var region: String?
    public var style: String?
    public var language: String?
    
    public var duration: TimeCode {
        return TimeCode(totalMilliseconds: endTime.totalMilliseconds - startTime.totalMilliseconds)
    }
    
    public var durationTotalMilliseconds: Double {
        return endTime.totalMilliseconds - startTime.totalMilliseconds
    }
    
    public var durationTotalSeconds: Double {
        return durationTotalMilliseconds / TimeCode.baseUnit
    }
    
    public var isDefault: Bool {
        return abs(startTime.totalMilliseconds) < 0.01 && abs(endTime.totalMilliseconds) < 0.01 && text.isEmpty
    }
    
    public var plainText: String {
        return text.removeHtmlTags()
    }
    
    public init() {
        self.id = UUID().uuidString
        self.number = 0
        self.text = ""
        self.startTime = TimeCode()
        self.endTime = TimeCode()
    }
    
    public init(startTime: TimeCode, endTime: TimeCode, text: String) {
        self.id = UUID().uuidString
        self.number = 0
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
    
    public init(text: String, startTotalMilliseconds: Double, endTotalMilliseconds: Double) {
        self.id = UUID().uuidString
        self.number = 0
        self.startTime = TimeCode(totalMilliseconds: startTotalMilliseconds)
        self.endTime = TimeCode(totalMilliseconds: endTotalMilliseconds)
        self.text = text
    }
    
    // Copy constructor
    public init(paragraph: Paragraph, generateNewId: Bool = true) {
        self.id = generateNewId ? UUID().uuidString : paragraph.id
        self.number = paragraph.number
        self.text = paragraph.text
        self.startTime = TimeCode(totalMilliseconds: paragraph.startTime.totalMilliseconds)
        self.endTime = TimeCode(totalMilliseconds: paragraph.endTime.totalMilliseconds)
        self.forced = paragraph.forced
        self.extra = paragraph.extra
        self.isComment = paragraph.isComment
        self.actor = paragraph.actor
        self.region = paragraph.region
        self.style = paragraph.style
        self.language = paragraph.language
    }
    
    public func adjust(factor: Double, adjustmentInSeconds: Double) {
        if startTime.isMaxTime {
            return
        }
        
        startTime.totalMilliseconds = startTime.totalMilliseconds * factor + adjustmentInSeconds * TimeCode.baseUnit
        endTime.totalMilliseconds = endTime.totalMilliseconds * factor + adjustmentInSeconds * TimeCode.baseUnit
    }
    
    public var description: String {
        return "\(startTime) --> \(endTime) \(text)"
    }
}

extension Paragraph: Equatable {
    public static func == (lhs: Paragraph, rhs: Paragraph) -> Bool {
        return lhs.id == rhs.id &&
               lhs.number == rhs.number &&
               lhs.text == rhs.text &&
               lhs.startTime == rhs.startTime &&
               lhs.endTime == rhs.endTime
    }
}
