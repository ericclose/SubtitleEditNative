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
        sampleRate: Double = 8000.0,
        scale: CGFloat = 2.0
    ) -> CGImage? {
        let scaledWidth = Int(CGFloat(width) * scale)
        let scaledHeight = Int(CGFloat(height) * scale)
        let midY = CGFloat(scaledHeight) / 2.0
        let pxPerSecond = CGFloat(scaledWidth) / CGFloat(windowSize)
        let startTime = currentTime - (windowSize / 2.0)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.clear(CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
        context.setStrokeColor(NSColor.orange.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(1.0 * scale)
        context.setLineCap(.round)
        context.setShouldAntialias(true)
        
        let samplesPerPixel = Int(sampleRate / Double(pxPerSecond))
        
        for x in 0..<scaledWidth {
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
                    
                    let yMin = midY - CGFloat(maxVal) * (CGFloat(scaledHeight) / 2.2)
                    let yMax = midY - CGFloat(minVal) * (CGFloat(scaledHeight) / 2.2)
                    
                    context.move(to: CGPoint(x: CGFloat(x), y: yMin))
                    context.addLine(to: CGPoint(x: CGFloat(x), y: yMax))
                }
            }
        }
        
        context.strokePath()
        return context.makeImage()
    }
}
