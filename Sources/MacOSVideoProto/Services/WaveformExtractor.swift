import Foundation
import AVFoundation

class WaveformExtractor {
    /// 提取音频采样点，全面对齐 Swift 6 并发安全标准
    static func extract(from url: URL, targetCount: Int = 2000, completion: @escaping @Sendable ([Float]) -> Void) {
        let asset = AVURLAsset(url: url)
        
        Task {
            do {
                // 加载轨道信息
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                guard let track = tracks.first else {
                    completion([])
                    return
                }
                
                let reader = try AVAssetReader(asset: asset)
                let outputSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
                
                let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
                reader.add(output)
                reader.startReading()
                
                var samples = [Int16]()
                while let buffer = output.copyNextSampleBuffer() {
                    if let blockBuffer = CMSampleBufferGetDataBuffer(buffer) {
                        let length = CMBlockBufferGetDataLength(blockBuffer)
                        var data = [Int16](repeating: 0, count: length / 2)
                        CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &data)
                        samples.append(contentsOf: data)
                    }
                }
                
                // 执行降采样逻辑
                let result = self.downsample(samples: samples, targetCount: targetCount)
                completion(result)
                
            } catch {
                print("Waveform Extraction Error: \(error)")
                completion([])
            }
        }
    }
    
    private static func downsample(samples: [Int16], targetCount: Int) -> [Float] {
        guard samples.count > targetCount else {
            return samples.map { Float(abs($0)) / Float(Int16.max) }
        }
        
        let bucketSize = samples.count / targetCount
        var result = [Float]()
        
        for i in 0..<targetCount {
            let start = i * bucketSize
            let end = min(start + bucketSize, samples.count)
            var maxVal: Int16 = 0
            for j in start..<end {
                maxVal = max(maxVal, abs(samples[j]))
            }
            result.append(Float(maxVal) / Float(Int16.max))
        }
        
        return result
    }
}
