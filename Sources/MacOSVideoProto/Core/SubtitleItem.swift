import Foundation

struct SubtitleItem: Identifiable, Equatable {
    let id: UUID
    var index: Int
    var startTime: Double // in seconds
    var endTime: Double   // in seconds
    var text: String
    
    var duration: Double {
        endTime - startTime
    }
    
    init(id: UUID = UUID(), index: Int, startTime: Double, endTime: Double, text: String) {
        self.id = id
        self.index = index
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
    
    static func == (lhs: SubtitleItem, rhs: SubtitleItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.index == rhs.index &&
        lhs.startTime == rhs.startTime &&
        lhs.endTime == rhs.endTime &&
        lhs.text == rhs.text
    }
}
