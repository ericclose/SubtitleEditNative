import XCTest
@testable import MacOSVideoProto

final class SubtitleParserTests: XCTestCase {
    
    func testSubRipBasicParsing() {
        let srtContent = """
        1
        00:00:01,000 --> 00:00:02,500
        Hello world!
        
        2
        00:00:03,000 --> 00:00:05,000
        Line 1
        Line 2
        """
        
        let parser = SubRip()
        let subtitle = Subtitle()
        let lines = srtContent.components(separatedBy: .newlines)
        parser.loadSubtitle(subtitle: subtitle, lines: lines, fileName: nil)
        
        XCTAssertEqual(subtitle.paragraphs.count, 2)
        XCTAssertEqual(subtitle.paragraphs[0].text, "Hello world!")
        XCTAssertEqual(subtitle.paragraphs[1].text, "Line 1\nLine 2")
        XCTAssertEqual(subtitle.paragraphs[0].startTime.totalMilliseconds, 1000)
        XCTAssertEqual(subtitle.paragraphs[1].endTime.totalMilliseconds, 5000)
    }
    
    func testMalformedTimecodes() {
        // Subtitle Edit is famous for handling these "broken" SRTs
        let brokenSrt = """
        1
        00:00:01.000 --> 00:00:02.500
        Dot instead of comma
        
        2
        00:01,000 --> 00:02,500
        Missing hours
        
        3
        00:00:05,000 -> 00:00:07,000
        Single arrow instead of triple
        """
        
        let parser = SubRip()
        let subtitle = Subtitle()
        let lines = brokenSrt.components(separatedBy: .newlines)
        parser.loadSubtitle(subtitle: subtitle, lines: lines, fileName: nil)
        
        XCTAssertEqual(subtitle.paragraphs.count, 3)
        XCTAssertEqual(subtitle.paragraphs[0].startTime.totalMilliseconds, 1000)
        XCTAssertEqual(subtitle.paragraphs[1].startTime.totalMilliseconds, 1000)
        XCTAssertEqual(subtitle.paragraphs[2].startTime.totalMilliseconds, 5000)
    }
    
    func testHtmlTagRemoval() {
        let taggedText = "<i>Italic</i> <b>Bold</b> <font color=\"red\">Colored</font>"
        let cleanText = taggedText.removeHtmlTags()
        
        XCTAssertEqual(cleanText, "Italic Bold Colored")
    }
    
    func testSubtitleRenumbering() {
        let subtitle = Subtitle()
        subtitle.paragraphs = [
            Paragraph(text: "A", startTotalMilliseconds: 1000, endTotalMilliseconds: 2000),
            Paragraph(text: "B", startTotalMilliseconds: 3000, endTotalMilliseconds: 4000)
        ]
        
        subtitle.renumber(startNumber: 10)
        
        XCTAssertEqual(subtitle.paragraphs[0].number, 10)
        XCTAssertEqual(subtitle.paragraphs[1].number, 11)
    }
    
    func testTimeCodeEdgeCases() {
        let tc = TimeCode(hours: 1, minutes: 60, seconds: 0, milliseconds: 0)
        // Should handle overflow correctly (1:60:00 -> 2:00:00)
        XCTAssertEqual(tc.hours, 2)
        XCTAssertEqual(tc.minutes, 0)
        
        tc.totalMilliseconds = -1000
        XCTAssertEqual(tc.toString(), "-00:00:01,000")
    }
}
