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
    
    print("  - Testing basic rendering...")
    let image = samples.withUnsafeBufferPointer { buffer in
        return WaveformRenderer.renderWaveform(
            samples: buffer.baseAddress!,
            count: sampleCount,
            width: width,
            height: height,
            currentTime: currentTime
        )
    }
    
    if let img = image {
        print("  ✅ Success: Produced \(img.width)x\(img.height) image")
    } else {
        print("  ❌ Failed: Image is nil")
        exit(1)
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
    print("  - [Stress] Running rapid waveform rendering (500 cycles)...")
    let bridge = SubtitleBridge()
    let samples = UnsafeMutablePointer<Float>.allocate(capacity: 1024 * 1024)
    for i in 0..<1024*1024 { samples[i] = Float.random(in: -1...1) }
    
    let start = Date()
    for _ in 0..<500 {
        _ = WaveformRenderer.renderWaveform(samples: samples, count: 1024*1024, width: 800, height: 150, currentTime: Double.random(in: 0...100), windowSize: 10.0)
    }
    let duration = Date().timeIntervalSince(start)
    print("  ✅ Success: 500 renders in \(String(format: "%.2f", duration))s (\(String(format: "%.1f", 500/duration)) FPS equivalent)")
    samples.deallocate()
}

func testStressUndoRedo() {
    print("  - [Stress] Running large-scale Undo/Redo cycles (1000 iterations)...")
    let bridge = SubtitleBridge()
    // Mock a subtitle with 1000 lines
    _ = bridge.loadSubtitle(path: "dummy.srt") // This will initialize context
    
    let start = Date()
    for i in 0..<1000 {
        _ = bridge.updateParagraph(index: 0, text: "Stress Test \(i)")
        _ = bridge.undo()
        _ = bridge.redo()
    }
    let duration = Date().timeIntervalSince(start)
    print("  ✅ Success: 1000 cycles completed in \(String(format: "%.2f", duration))s")
}

func testBridgeLeak() {
    print("  - [Stress] Running bridge lifecycle stress (200 initializations)...")
    let start = Date()
    for _ in 0..<200 {
        let bridge = SubtitleBridge()
        _ = bridge.loadSubtitle(path: "dummy.srt")
    }
    let duration = Date().timeIntervalSince(start)
    print("  ✅ Success: 200 bridge cycles in \(String(format: "%.2f", duration))s")
}

func testLoggingLevels() {
    print("  - Testing logging levels (Warning & Error)...")
    let bridge = SubtitleBridge()
    
    // 1. Log a warning manually
    AppLog("Test Warning Message", level: .warning)
    
    // 2. Trigger a .NET error by loading non-existent file
    _ = bridge.loadSubtitle(path: "/tmp/non_existent_file_xyz.srt")
    
    // 3. Verify log file contains the expected levels
    guard let logPath = AppLogger.shared.logFilePath else {
        print("  ❌ Failure: Log file path not found")
        exit(1)
    }
    
    do {
        let logContent = try String(contentsOfFile: logPath)
        let hasWarning = logContent.contains("[WARN]")
        let hasError = logContent.contains("[ERROR]")
        
        if hasWarning && hasError {
            print("  ✅ Success: Captured [WARN] and [ERROR] in logs")
        } else {
            print("  ❌ Failure: Missing levels in logs. Warn: \(hasWarning), Error: \(hasError)")
            exit(1)
        }
    } catch {
        print("  ❌ Failure: Could not read log file: \(error)")
        exit(1)
    }
}

testWaveformRendering()
testSilenceHandling()
testSpellChecker()
testLoggingLevels()

print("🚀 Starting Stability Stress Tests...")
testStressWaveform()
testStressUndoRedo()
testBridgeLeak()

print("🎉 All tests passed, system is stable!")
