import Foundation
import SwiftUI
import Combine

@MainActor
class VLCPlayer: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playbackSpeed: Double = 1.0
    @Published var currentFileName: String? = nil
    @Published var waveformSamples: [Float] = []
    @Published var isMuted: Bool = false
    
    private var lastVolume: Int = 100
    private var timer: Timer?
    private var isSeeking: Bool = false
    let bridge = VLCBridge()
    
    init() {
        startSyncTimer()
    }
    
    func loadFile(url: URL) {
        currentFileName = url.lastPathComponent
        bridge.loadMedia(path: url.path)
        bridge.play()
        isPlaying = true
        
        WaveformExtractor.extract(from: url) { [weak self] samples in
            Task { @MainActor in
                self?.waveformSamples = samples
            }
        }
    }
    
    func togglePlay() {
        let vlcState = bridge.state
        
        // Manual Restart: Only reset to 0 if user clicks Play from an Ended/Stopped state
        if vlcState == 6 || vlcState == 5 {
            bridge.position = 0.0
            currentTime = 0
            bridge.play()
            isPlaying = true
            return
        }
        
        if isPlaying {
            bridge.pause()
        } else {
            bridge.play()
        }
        isPlaying.toggle()
    }
    
    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            lastVolume = bridge.volume
            bridge.volume = 0
        } else {
            bridge.volume = lastVolume > 0 ? lastVolume : 100
        }
    }
    
    func seek(to time: Double) {
        guard duration > 0 else { return }
        isSeeking = true
        
        currentTime = time
        let targetPosition = Float(time / duration)
        bridge.position = max(0.0, min(1.0, targetPosition))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isSeeking = false
        }
    }
    
    func setSpeed(_ speed: Double) {
        playbackSpeed = speed
        bridge.rate = Float(speed)
    }
    
    private func startSyncTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.isSeeking else { return }
                
                let vlcState = self.bridge.state
                let newTime = self.bridge.time
                let newDuration = self.bridge.duration
                
                if abs(self.currentTime - newTime) > 0.001 {
                    self.currentTime = newTime
                }
                
                if abs(self.duration - newDuration) > 0.1 {
                    self.duration = newDuration
                }
                
                // End handling: Just update UI state, don't move playhead!
                if vlcState == 6 {
                    self.isPlaying = false
                } else {
                    self.isPlaying = self.bridge.isPlaying
                }
            }
        }
    }
}
