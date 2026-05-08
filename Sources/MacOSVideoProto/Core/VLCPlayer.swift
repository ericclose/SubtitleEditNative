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
    @Published var subtitles: [SubtitleItem] = []
    @Published var selectedSubtitleId: UUID? = nil
    @Published var isMuted: Bool = false
    @Published var isUserInteracting: Bool = false
    
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
        
        // Immediate update of selected subtitle
        if let activeSub = subtitles.first(where: { time >= $0.startTime && time <= $0.endTime }) {
            selectedSubtitleId = activeSub.id
        } else {
            selectedSubtitleId = nil
        }
        
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
                guard let self = self, !self.isSeeking, !self.isUserInteracting else { return }
                
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
                
                // Update selected subtitle based on current time
                if let activeSub = self.subtitles.first(where: { self.currentTime >= $0.startTime && self.currentTime <= $0.endTime }) {
                    if self.selectedSubtitleId != activeSub.id {
                        self.selectedSubtitleId = activeSub.id
                    }
                }
            }
        }
    }
    
    func formatTime(_ time: Double) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let ms = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, ms)
        } else {
            return String(format: "%02d:%02d.%03d", minutes, seconds, ms)
        }
    }
}
