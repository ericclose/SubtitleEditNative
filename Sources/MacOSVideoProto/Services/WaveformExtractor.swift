import Foundation
import AVFoundation

class WaveformExtractor {
    static func extract(from url: URL, completion: @escaping @Sendable ([WavePeak]) -> Void) {
        let tempWavURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        
        Task {
            do {
                Logger.shared.log("Preparing extraction for: \(url.lastPathComponent)")
                let process = Process()
                let errorPipe = Pipe()
                process.standardError = errorPipe
                
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
                
                guard let ffmpegPath = foundPath else {
                    Logger.shared.log("FFmpeg not found", level: .error)
                    completion([])
                    return
                }
                
                process.executableURL = URL(fileURLWithPath: ffmpegPath)
                process.arguments = [
                    "-i", url.path,
                    "-map", "0:a:0",
                    "-vn",
                    "-ac", "1",
                    "-ar", "24000",
                    "-f", "wav",
                    "-y",
                    tempWavURL.path
                ]
                
                Logger.shared.log("Running FFmpeg...")
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown FFmpeg error"
                    Logger.shared.log("FFmpeg FAILED: \(errorString)", level: .error)
                    completion([])
                    return
                }
                
                // Load whole data back as requested, but keep it safe
                let data = try Data(contentsOf: tempWavURL)
                Logger.shared.log("FFmpeg success. Loaded WAV: \(data.count / 1024) KB")
                
                let result = self.generatePeaks(from: data, sampleRate: 24000, targetPeaksPerSecond: 100)
                
                Logger.shared.log("Peak generation completed. Total peaks: \(result.count)")
                
                try? FileManager.default.removeItem(at: tempWavURL)
                completion(result)
                
            } catch {
                Logger.shared.error("Critical failure during extraction", error: error)
                completion([])
            }
        }
    }
    
    private static func generatePeaks(from data: Data, sampleRate: Int, targetPeaksPerSecond: Int) -> [WavePeak] {
        let samplesPerPeak = sampleRate / targetPeaksPerSecond
        
        var rawPeaks = [(min: Int16, max: Int16)]()
        var globalMax: Int32 = 1 // Keep Int32 to prevent overflow crash
        
        data.withUnsafeBytes { buffer in
            // Skip 44 bytes header
            let headerOffset = 44
            guard buffer.count > headerOffset else { return }
            
            let pSamples = buffer.baseAddress!.advanced(by: headerOffset).assumingMemoryBound(to: Int16.self)
            let totalSamples = (buffer.count - headerOffset) / 2
            
            var i = 0
            while i < totalSamples {
                let end = min(i + samplesPerPeak, totalSamples)
                var minVal: Int16 = 0
                var maxVal: Int16 = 0
                
                for j in i..<end {
                    let sample = pSamples[j]
                    if sample < minVal { minVal = sample }
                    if sample > maxVal { maxVal = sample }
                }
                
                rawPeaks.append((min: minVal, max: maxVal))
                let absMax = max(abs(Int32(minVal)), abs(Int32(maxVal)))
                if absMax > globalMax { globalMax = absMax }
                
                i += samplesPerPeak
            }
        }
        
        let normalizationFactor = Float(globalMax)
        return rawPeaks.map { peak in
            WavePeak(
                min: Float(peak.min) / normalizationFactor,
                max: Float(peak.max) / normalizationFactor
            )
        }
    }
}
