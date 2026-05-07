import Foundation
import Accelerate
import CoreGraphics
import AppKit

public class WaveformRenderer {
    public static func renderWaveform(
        samples: UnsafePointer<Float>,
        count: Int,
        width: Int,
        height: Int,
        currentTime: Double,
        windowSize: Double = 10.0,
        sampleRate: Double = 8000.0
    ) -> CGImage? {
        let midY = CGFloat(height) / 2.0
        let pxPerSecond = CGFloat(width) / CGFloat(windowSize)
        let startTime = currentTime - (windowSize / 2.0)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setStrokeColor(NSColor.orange.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(1.0)
        context.setLineCap(.round)
        
        // Advanced processing: use Accelerate to find min/max for each pixel
        let samplesPerPixel = Int(sampleRate / Double(pxPerSecond))
        
        for x in 0..<width {
            let timeAtX = startTime + Double(x) / Double(pxPerSecond)
            let startSampleIdx = Int(timeAtX * sampleRate)
            
            if startSampleIdx >= 0 && startSampleIdx < count {
                let rangeCount = min(samplesPerPixel, count - startSampleIdx)
                if rangeCount > 0 {
                    var minVal: Float = 0
                    var maxVal: Float = 0
                    
                    let rangePtr = samples.advanced(by: startSampleIdx)
                    vDSP_minv(rangePtr, 1, &minVal, vDSP_Length(rangeCount))
                    vDSP_maxv(rangePtr, 1, &maxVal, vDSP_Length(rangeCount))
                    
                    let yMin = midY - CGFloat(maxVal) * (CGFloat(height) / 2.5)
                    let yMax = midY - CGFloat(minVal) * (CGFloat(height) / 2.5)
                    
                    context.move(to: CGPoint(x: CGFloat(x), y: yMin))
                    context.addLine(to: CGPoint(x: CGFloat(x), y: yMax))
                }
            }
        }
        
        context.strokePath()
        return context.makeImage()
    }
}
