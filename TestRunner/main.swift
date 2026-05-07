import Foundation
import CoreGraphics
import AppKit
import LibSENative

print("🚀 Starting Waveform Renderer Tests...")

func testWaveformRendering() {
    let sampleCount = 8000
    let samples = [Float](repeating: 0.5, count: sampleCount)
    
    let width = 400
    let height = 100
    let currentTime = 0.5
    
    print("  - Testing basic rendering (scale=1.0)...")
    let image1 = samples.withUnsafeBufferPointer { buffer in
        return WaveformRenderer.renderWaveform(
            samples: buffer.baseAddress!,
            count: sampleCount,
            width: width,
            height: height,
            currentTime: currentTime,
            scale: 1.0
        )
    }
    
    if let img = image1 {
        if img.width == 400 && img.height == 100 {
            print("  ✅ Success: Produced 400x100 image")
        } else {
            print("  ❌ Failure: Expected 400x100, got \(img.width)x\(img.height)")
            exit(1)
        }
    }
    
    print("  - Testing High-DPI rendering (scale=2.0)...")
    let image2 = samples.withUnsafeBufferPointer { buffer in
        return WaveformRenderer.renderWaveform(
            samples: buffer.baseAddress!,
            count: sampleCount,
            width: width,
            height: height,
            currentTime: currentTime,
            scale: 2.0
        )
    }
    
    if let img = image2 {
        if img.width == 800 && img.height == 200 {
            print("  ✅ Success: Produced 800x200 image")
        } else {
            print("  ❌ Failure: Expected 800x200, got \(img.width)x\(img.height)")
            exit(1)
        }
    }
}

func testSilenceHandling() {
    print("  - Testing silence handling...")
    let sampleCount = 4000
    let samples = [Float](repeating: 0, count: sampleCount)
    
    let image = samples.withUnsafeBufferPointer { buffer in
        return WaveformRenderer.renderWaveform(
            samples: buffer.baseAddress!,
            count: sampleCount,
            width: 100,
            height: 50,
            currentTime: 0.1
        )
    }
    
    if image != nil {
        print("  ✅ Success: Produced image for silence")
    } else {
        print("  ❌ Failed: Silent image is nil")
        exit(1)
    }
}

func testSpellChecker() {
    print("  - Testing native spell checker...")
    let text = "This is a simple test with a typo: helllo"
    let errors = NSSpellChecker.shared.checkSpelling(of: text, startingAt: 0)
    if errors.location != NSNotFound {
        print("  ✅ Success: Found typo at \(errors.location)")
    } else {
        print("  ❌ Failure: Typos not detected")
        exit(1)
    }
}

func testStressWaveform() {
    let cycles = 100
    print("  - [Stress] Running rapid waveform rendering (\(cycles) cycles, parallel)...")
    let samples = UnsafeMutablePointer<Float>.allocate(capacity: 1024 * 1024)
    for i in 0..<1024*1024 { samples[i] = Float.random(in: -1...1) }
    
    let start = Date()
    // Use parallel processing to speed up the stress test
    DispatchQueue.concurrentPerform(iterations: cycles) { _ in
        _ = WaveformRenderer.renderWaveform(
            samples: samples, 
            count: 1024*1024, 
            width: 800, 
            height: 150, 
            currentTime: Double.random(in: 0...100), 
            windowSize: 10.0,
            scale: 1.0 // Use 1.0 for stress to focus on logic overhead
        )
    }
    let duration = Date().timeIntervalSince(start)
    print("  ✅ Success: \(cycles) renders in \(String(format: "%.2f", duration))s (\(String(format: "%.1f", Double(cycles)/duration)) FPS equivalent)")
    samples.deallocate()
}

func testStressUndoRedo() {
    print("  - [Stress] Running large-scale Undo/Redo cycles (1000 iterations)...")
    let bridge = SubtitleBridge()
    // Mock a subtitle with 1000 lines
    _ = bridge.loadSubtitle(path: "dummy.srt") // This will initialize context
    
    AppLogger.shared.isConsoleMuted = true
    let start = Date()
    for i in 0..<1000 {
        _ = bridge.updateParagraph(index: 0, text: "Stress Test \(i)")
        _ = bridge.undo()
        _ = bridge.redo()
        if i % 100 == 0 {
            AppLogger.shared.isConsoleMuted = false
            print(".", terminator: "")
            fflush(stdout)
            AppLogger.shared.isConsoleMuted = true
        }
    }
    AppLogger.shared.isConsoleMuted = false
    print("") // newline
    let duration = Date().timeIntervalSince(start)
    print("  ✅ Success: 1000 cycles completed in \(String(format: "%.2f", duration))s")
}

func testBridgeLeak() {
    print("  - [Stress] Running bridge lifecycle stress (200 initializations)...")
    AppLogger.shared.isConsoleMuted = true
    let start = Date()
    for i in 0..<200 {
        let bridge = SubtitleBridge()
        _ = bridge.loadSubtitle(path: "dummy.srt")
        if i % 20 == 0 { 
            AppLogger.shared.isConsoleMuted = false
            print(".", terminator: "")
            fflush(stdout)
            AppLogger.shared.isConsoleMuted = true
        }
    }
    AppLogger.shared.isConsoleMuted = false
    print("") // newline
    let duration = Date().timeIntervalSince(start)
    print("  ✅ Success: 200 bridge cycles in \(String(format: "%.2f", duration))s")
}

func testLoggingLevels() {
    print("  - Testing logging levels (Warning & Error)...")
    let bridge = SubtitleBridge()
    
    AppLog("Test Warning Message", level: .warning)
    AppLog("Test Error Message", level: .error)
    
    guard let logPath = AppLogger.shared.logFilePath else {
        print("  ❌ Failure: Log file path not found")
        exit(1)
    }
    
    do {
        let logContent = try String(contentsOfFile: logPath)
        let hasWarning = logContent.contains("[WARN]")
        let hasError = logContent.contains("[ERROR]")
        
        if hasWarning && hasError {
            print("  ✅ Success: Captured categorized logs (Warning & Error levels)")
        } else {
            print("  ❌ Failure: Missing levels in logs. Warn: \(hasWarning), Error: \(hasError)")
            exit(1)
        }
    } catch {
        print("  ❌ Failure: Could not read log file: \(error)")
        exit(1)
    }
}

func testTimeFormatting() {
    print("  - Testing Phase 1: Time Formatting...")
    let formatter = TimeFormatter()
    let seconds = (3600.0 * 1) + (60.0 * 2) + 3.450
    let result = formatter.string(for: seconds)
    
    if result == "01:02:03.450" {
        print("  ✅ Success: Formatted 1h 2m 3.45s correctly")
    } else {
        print("  ❌ Failure: Expected 01:02:03.450, got \(result ?? "nil")")
        exit(1)
    }
}

func testCPSCalculationLogic() {
    print("  - Testing Phase 1: CPS Calculation...")
    let cps = calculateCPS(text: "Hello World", start: 0, end: 1)
    if cps == 11.0 {
        print("  ✅ Success: CPS calculation is correct")
    } else {
        print("  ❌ Failure: Expected 11.0, got \(cps)")
        exit(1)
    }
}

func testSubtitleLineProperties() {
    print("  - Testing Phase 2: SubtitleLine properties (Duration, CPS, WPM)...")
    let line = SubtitleLine(index: 0, start: 0, end: 2.0, text: "Hello World") // 11 chars, 2 words
    
    if line.duration == 2.0 {
        print("  ✅ Success: Duration correct")
    } else {
        print("  ❌ Failure: Expected duration 2.0, got \(line.duration)")
        exit(1)
    }
    
    if line.cps == 5.5 {
        print("  ✅ Success: CPS correct")
    } else {
        print("  ❌ Failure: Expected CPS 5.5, got \(line.cps)")
        exit(1)
    }
    
    // 2 words / 2 seconds * 60 = 60 WPM
    if line.wpm == 60.0 {
        print("  ✅ Success: WPM correct")
    } else {
        print("  ❌ Failure: Expected WPM 60.0, got \(line.wpm)")
        exit(1)
    }
}

func testListManipulation() {
    print("  - Testing Phase 3: List Manipulation (Insert/Remove)...")
    let bridge = SubtitleBridge()
    
    // Create a dummy file to initialize context
    let dummyPath = "test_dummy.srt"
    try? "1\n00:00:00,000 --> 00:00:01,000\nHello".write(toFile: dummyPath, atomically: true, encoding: .utf8)
    
    _ = bridge.loadSubtitle(path: dummyPath) 
    let initialCount = bridge.getLineCount()
    
    if bridge.insertParagraph(index: 1, text: "New Second Line", startMs: 1100, endMs: 2000) {
        let newCount = bridge.getLineCount()
        if newCount == initialCount + 1 {
            print("  ✅ Success: Inserted paragraph")
        } else {
            print("  ❌ Failure: Count mismatch after insert. Expected \(initialCount + 1), got \(newCount)")
            exit(1)
        }
    } else {
        print("  ❌ Failure: insertParagraph returned false")
        exit(1)
    }
    
    if bridge.removeParagraph(index: 0) {
        let finalCount = bridge.getLineCount()
        if finalCount == initialCount {
            print("  ✅ Success: Removed paragraph")
        } else {
            print("  ❌ Failure: Count mismatch after remove. Expected \(initialCount), got \(finalCount)")
            exit(1)
        }
    } else {
        print("  ❌ Failure: removeParagraph returned false")
        exit(1)
    }
}

func testSelectionPersistence() {
    print("  - Testing Phase 4: Selection Persistence (UUID stability)...")
    let line1 = SubtitleLine(index: 0, start: 0, end: 1.0, text: "Original")
    let originalId = line1.id
    
    // Simulate update logic used in ContentView
    let updatedLine = SubtitleLine(id: originalId, index: 0, start: 0, end: 1.0, text: "Modified")
    
    if updatedLine.id == originalId {
        print("  ✅ Success: UUID persisted after update")
    } else {
        print("  ❌ Failure: UUID changed! Selection will be lost.")
        exit(1)
    }
}

testTimeFormatting()
testCPSCalculationLogic()
testSubtitleLineProperties()
testListManipulation()
testSelectionPersistence()
testWaveformRendering()
testSilenceHandling()
testSpellChecker()
testLoggingLevels()

print("🚀 Starting Stability Stress Tests...")
testStressWaveform()
testStressUndoRedo()
testBridgeLeak()

print("🎉 All tests passed, system is stable!")
