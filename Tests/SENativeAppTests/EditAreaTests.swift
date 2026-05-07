import XCTest
import SwiftUI
@testable import LibSENative

final class EditAreaTests: XCTestCase {
    
    func testSubtitleLineEquality() {
        let line1 = SubtitleLine(index: 0, start: 1.0, end: 2.0, text: "Hello")
        let line2 = SubtitleLine(index: 0, start: 1.0, end: 2.0, text: "Hello")
        let line3 = SubtitleLine(index: 1, start: 1.0, end: 2.0, text: "Hello")
        
        XCTAssertEqual(line1, line2)
        XCTAssertNotEqual(line1, line3)
    }
    
    func testTimeFormatterString() {
        let formatter = TimeFormatter()
        
        // 1 hour, 2 minutes, 3 seconds, 450 ms
        let seconds = (3600.0 * 1) + (60.0 * 2) + 3.450
        let result = formatter.string(for: seconds)
        
        XCTAssertEqual(result, "01:02:03.450")
    }
    
    func testTimeFormatterParsing() {
        let formatter = TimeFormatter()
        var obj: AnyObject?
        let success = formatter.getObjectValue(&obj, for: "01:02:03.450", errorDescription: nil)
        
        XCTAssertTrue(success)
        let seconds = obj as? Double
        XCTAssertEqual(seconds, (3600.0 * 1) + (60.0 * 2) + 3.450)
    }
    
    func testCPSCalculation() {
        let text = "Hello World" // 11 chars
        let start = 0.0
        let end = 1.0 // 1 second duration
        
        func calculateCPS(text: String, start: Double, end: Double) -> Double {
            let duration = end - start
            guard duration > 0 else { return 0 }
            return Double(text.count) / duration
        }
        
        let cps = calculateCPS(text: text, start: start, end: end)
        XCTAssertEqual(cps, 11.0)
        
        let cpsHigh = calculateCPS(text: "This is a very long line for one second", start: 0, end: 1)
        XCTAssertTrue(cpsHigh > 20.0)
    }
}

// Move TimeFormatter to LibSENative so it can be tested, 
// OR just redefine/test it here if it's only in the App target.
// Since it's in Sources/EditAreaView.swift (App target), and LibSENative is a library target,
// it might be better to move utility classes to LibSENative.
