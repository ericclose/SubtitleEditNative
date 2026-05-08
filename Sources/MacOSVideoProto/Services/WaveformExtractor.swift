import Foundation
import AVFoundation

class WaveformExtractor {
    /// 提取音频采样点，使用 FFmpeg 对齐 Subtitle Edit 逻辑
    static func extract(from url: URL, completion: @escaping @Sendable ([WavePeak]) -> Void) {
        let tempWavURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        
        Task {
            do {
                // 1. 使用 FFmpeg 提取 16-bit Mono 24kHz PCM
                let process = Process()
                
                // Try to find ffmpeg in bundled location, then common system paths
                var paths = [String]()
                if let bundledPath = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("ffmpeg").path {
                    paths.append(bundledPath)
                }
                paths.append(contentsOf: ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"])
                
                var foundPath: String? = nil
                for path in paths {
                    if FileManager.default.fileExists(atPath: path) {
                        foundPath = path
                        break
                    }
                }
                
                // Fallback to searching in PATH if not found in common absolute paths
                process.executableURL = URL(fileURLWithPath: foundPath ?? "/usr/bin/env")
                if foundPath == nil {
                    process.arguments = ["ffmpeg"]
                } else {
                    process.arguments = []
                }
                
                process.arguments! += [
                    "-i", url.path,
                    "-vn",
                    "-ac", "1",
                    "-ar", "24000",
                    "-f", "wav",
                    "-y", // Overwrite output
                    tempWavURL.path
                ]
                
                try process.run()
                process.waitUntilExit()
                
                guard process.terminationStatus == 0 else {
                    print("FFmpeg failed with status: \(process.terminationStatus)")
                    completion([])
                    return
                }
                
                // 2. 读取生成的 WAV 并计算 Peaks (100 peaks per second)
                let data = try Data(contentsOf: tempWavURL)
                let result = self.generatePeaks(from: data, sampleRate: 24000, targetPeaksPerSecond: 100)
                
                // 清理临时文件
                try? FileManager.default.removeItem(at: tempWavURL)
                
                completion(result)
                
            } catch {
                print("Waveform Extraction Error: \(error)")
                completion([])
            }
        }
    }
    
    private static func generatePeaks(from data: Data, sampleRate: Int, targetPeaksPerSecond: Int) -> [WavePeak] {
        let bytesPerSample = 2 // 16-bit
        let samplesPerPeak = sampleRate / targetPeaksPerSecond
        
        var rawPeaks = [(min: Int16, max: Int16)]()
        let totalSamples = data.count / bytesPerSample
        
        var globalMax: Int16 = 1 // Avoid division by zero
        
        data.withUnsafeBytes { buffer in
            let int16Samples = buffer.bindMemory(to: Int16.self)
            
            for i in stride(from: 0, to: totalSamples, by: samplesPerPeak) {
                let end = min(i + samplesPerPeak, totalSamples)
                var minVal: Int16 = 0
                var maxVal: Int16 = 0
                
                for j in i..<end {
                    let sample = int16Samples[j]
                    if sample < minVal { minVal = sample }
                    if sample > maxVal { maxVal = sample }
                }
                
                rawPeaks.append((min: minVal, max: maxVal))
                
                let absMax = max(abs(Int32(minVal)), abs(Int32(maxVal)))
                if absMax > globalMax {
                    globalMax = Int16(absMax)
                }
            }
        }
        
        // Normalize using the global maximum to fill the vertical space
        let normalizationFactor = Float(globalMax)
        return rawPeaks.map { peak in
            WavePeak(
                min: Float(peak.min) / normalizationFactor,
                max: Float(peak.max) / normalizationFactor
            )
        }
    }
}
