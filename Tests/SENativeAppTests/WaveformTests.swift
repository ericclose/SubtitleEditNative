import XCTest
import CoreGraphics
import Accelerate
import LibSENative

final class WaveformTests: XCTestCase {
    
    func testWaveformRenderingReturnsImage() {
        let sampleCount = 8000 // 1 second
        let samples = [Float](repeating: 0.5, count: sampleCount)
        
        let width = 400
        let height = 100
        let currentTime = 0.5
        
        let image = samples.withUnsafeBufferPointer { buffer in
            return WaveformRenderer.renderWaveform(
                samples: buffer.baseAddress!,
                count: sampleCount,
                width: width,
                height: height,
                currentTime: currentTime
            )
        }
        
        XCTAssertNotNil(image, "Waveform should produce a CGImage")
        XCTAssertEqual(image?.width, width)
        XCTAssertEqual(image?.height, height)
    }
    
    func testWaveformRenderingWithSilentAudio() {
        let sampleCount = 8000
        let samples = [Float](repeating: 0, count: sampleCount)
        
        let width = 400
        let height = 100
        let currentTime = 0.5
        
        let image = samples.withUnsafeBufferPointer { buffer in
            return WaveformRenderer.renderWaveform(
                samples: buffer.baseAddress!,
                count: sampleCount,
                width: width,
                height: height,
                currentTime: currentTime
            )
        }
        
        XCTAssertNotNil(image, "Waveform should produce an image even with silence")
    }
    
    func testWaveformRenderingOutOfBounds() {
        let sampleCount = 1000
        let samples = [Float](repeating: 1.0, count: sampleCount)
        
        let width = 400
        let height = 100
        let currentTime = 10.0 // Far beyond 1000 samples
        
        let image = samples.withUnsafeBufferPointer { buffer in
            return WaveformRenderer.renderWaveform(
                samples: buffer.baseAddress!,
                count: sampleCount,
                width: width,
                height: height,
                currentTime: currentTime
            )
        }
        
        XCTAssertNotNil(image, "Waveform should still return an image (likely blank) for out of bounds time")
    }
}
