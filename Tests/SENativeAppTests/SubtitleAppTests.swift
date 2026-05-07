import XCTest
import SwiftUI
import LibSENative

final class SubtitleAppTests: XCTestCase {

    func testSubtitleLineFormatting() {
        let line = SubtitleLine(index: 0, start: 1.5, end: 4.25, text: "Hello World")
        
        // Expected: 00:00:01,500 --> 00:00:04,250
        XCTAssertEqual(line.timeString, "00:00:01,500 --> 00:00:04,250")
    }

    func testSubtitleLineFormattingLargeTime() {
        let line = SubtitleLine(index: 10, start: 3661.0, end: 3665.5, text: "One hour later")
        
        // 3661s = 01:01:01
        XCTAssertEqual(line.timeString, "01:01:01,000 --> 01:01:05,500")
    }

    func testColorToHex() {
        let white = Color.white
        XCTAssertEqual(white.toHex(), "#FFFFFF")
        
        let red = Color(red: 1.0, green: 0, blue: 0)
        XCTAssertEqual(red.toHex(), "#FF0000")
    }
    
    func testActiveLineDetection() {
        // This simulates the logic in ContentView
        let line = SubtitleLine(index: 0, start: 10.0, end: 20.0, text: "Test")
        
        func isLineActive(currentTime: Double) -> Bool {
            return currentTime >= line.start && currentTime <= line.end
        }
        
        XCTAssertTrue(isLineActive(currentTime: 15.0))
        XCTAssertFalse(isLineActive(currentTime: 5.0))
        XCTAssertFalse(isLineActive(currentTime: 25.0))
    }
}
