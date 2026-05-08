import Foundation

public class Subtitle {
    public var paragraphs: [Paragraph]
    public var header: String = ""
    public var footer: String = ""
    public var fileName: String = "Untitled"
    
    public init() {
        self.paragraphs = []
    }
    
    public init(paragraphs: [Paragraph]) {
        self.paragraphs = paragraphs
    }
    
    // Copy constructor
    public init(subtitle: Subtitle, generateNewId: Bool = true) {
        self.paragraphs = subtitle.paragraphs.map { Paragraph(paragraph: $0, generateNewId: generateNewId) }
        self.header = subtitle.header
        self.footer = subtitle.footer
        self.fileName = subtitle.fileName
    }
    
    public func getParagraphOrDefault(index: Int) -> Paragraph? {
        guard index >= 0 && index < paragraphs.count else {
            return nil
        }
        return paragraphs[index]
    }
    
    public func renumber(startNumber: Int = 1) {
        for (index, paragraph) in paragraphs.enumerated() {
            paragraph.number = startNumber + index
        }
    }
    
    public func addTimeToAllParagraphs(time: TimeInterval) {
        let milliseconds = time * 1000.0
        for p in paragraphs {
            p.startTime.totalMilliseconds += milliseconds
            p.endTime.totalMilliseconds += milliseconds
        }
    }
    
    public func getIndex(seconds: Double) -> Int {
        let totalMilliseconds = seconds * 1000.0
        for (index, p) in paragraphs.enumerated() {
            if totalMilliseconds >= p.startTime.totalMilliseconds && totalMilliseconds <= p.endTime.totalMilliseconds {
                return index
            }
        }
        return -1
    }
}
