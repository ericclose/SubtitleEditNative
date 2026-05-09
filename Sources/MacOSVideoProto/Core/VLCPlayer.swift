import Foundation
import Combine

@MainActor
class VLCPlayer: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playbackSpeed: Double = 1.0
    @Published var currentFileName: String? = nil
    @Published var waveformSamples: [WavePeak] = []
    @Published var subtitles: [Paragraph] = []
    @Published var selectedSubtitleId: String? = nil
    @Published var isMuted: Bool = false
    @Published var isUserInteracting: Bool = false
    @Published var fps: Double = 23.976
    
    private var lastVolume: Int = 100
    private var timer: Timer?
    private var isSeeking: Bool = false
    
    // Undo/Redo Stacks
    private var undoStack: [[Paragraph]] = []
    private var redoStack: [[Paragraph]] = []
    private let maxHistory: Int = 100
    
    let bridge = VLCBridge()
    
    init() {
        startSyncTimer()
    }
    
    func loadFile(url: URL) {
        Logger.shared.log("Attempting to load file: \(url.path)")
        currentFileName = url.lastPathComponent
        bridge.loadMedia(path: url.path)
        Logger.shared.log("Media loaded into bridge")
        bridge.play()
        Logger.shared.log("Bridge play command sent")
        isPlaying = true
        
        Logger.shared.log("Starting waveform extraction")
        WaveformExtractor.extract(from: url) { [weak self] samples in
            Logger.shared.log("Waveform extraction completed with \(samples.count) samples")
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
        // Use exclusive end time to avoid boundary issues (SE logic: start <= time < end)
        if let activeSub = subtitles.first(where: { time >= $0.startTime.totalSeconds && time < $0.endTime.totalSeconds }) {
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
    
    
    // MARK: - History Management (Undo/Redo)
    
    func saveHistory() {
        // Create a deep copy of the current subtitles
        let snapshot = subtitles.map { Paragraph(paragraph: $0, generateNewId: false) }
        
        // Only save if it's different from the last state
        if let last = undoStack.last, last == snapshot {
            return
        }
        
        undoStack.append(snapshot)
        if undoStack.count > maxHistory {
            undoStack.removeFirst()
        }
        
        // Clearing redo stack after a new action
        redoStack.removeAll()
    }
    
    func undo() {
        guard undoStack.count > 1 else { return }
        
        // The last element is the CURRENT state, so we move it to redo
        let currentState = undoStack.removeLast()
        redoStack.append(currentState)
        
        // The new last element is the PREVIOUS state
        if let previousState = undoStack.last {
            self.subtitles = previousState.map { Paragraph(paragraph: $0, generateNewId: false) }
        }
    }
    
    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        
        // Save current to undo before applying next
        undoStack.append(nextState)
        self.subtitles = nextState.map { Paragraph(paragraph: $0, generateNewId: false) }
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
                // Using exclusive end time: [start, end)
                if let activeSub = self.subtitles.first(where: { self.currentTime >= $0.startTime.totalSeconds && self.currentTime < $0.endTime.totalSeconds }) {
                    if self.selectedSubtitleId != activeSub.id {
                        self.selectedSubtitleId = activeSub.id
                    }
                }
            }
        }
    }
    
    func snapToFrame(_ seconds: Double) -> Double {
        let frameDuration = 1.0 / fps
        return (seconds / frameDuration).rounded() * frameDuration
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

    // MARK: - Editing Operations
    
    func updateText(for paragraph: Paragraph, to newText: String) {
        if let index = subtitles.firstIndex(where: { $0.id == paragraph.id }) {
            if subtitles[index].text != newText {
                saveHistory()
                subtitles[index].text = newText
            }
        }
    }
    
    func updateStartTime(for paragraph: Paragraph, to newTime: Double) {
        if let index = subtitles.firstIndex(where: { $0.id == paragraph.id }) {
            saveHistory()
            let duration = subtitles[index].endTime.totalSeconds - subtitles[index].startTime.totalSeconds
            subtitles[index].startTime = TimeCode(totalMilliseconds: max(0, newTime) * 1000)
            subtitles[index].endTime = TimeCode(totalMilliseconds: (subtitles[index].startTime.totalSeconds + duration) * 1000)
        }
    }
    
    func updateEndTime(for paragraph: Paragraph, to newTime: Double) {
        if let index = subtitles.firstIndex(where: { $0.id == paragraph.id }) {
            saveHistory()
            subtitles[index].endTime = TimeCode(totalMilliseconds: max(subtitles[index].startTime.totalSeconds + 0.1, newTime) * 1000)
        }
    }
    
    func updateDuration(for paragraph: Paragraph, to newDuration: Double) {
        if let index = subtitles.firstIndex(where: { $0.id == paragraph.id }) {
            saveHistory()
            subtitles[index].endTime = TimeCode(totalMilliseconds: (subtitles[index].startTime.totalSeconds + max(0.1, newDuration)) * 1000)
        }
    }
    
    // MARK: - Text Tools Logic (SE Alignment)
    
    func autoBreakSelected() {
        guard let id = selectedSubtitleId, let index = subtitles.firstIndex(where: { $0.id == id }) else { return }
        let text = subtitles[index].text.replacingOccurrences(of: "\n", with: " ")
        let words = text.split(separator: " ")
        if words.count > 4 {
            saveHistory()
            let mid = words.count / 2
            let firstHalf = words[..<mid].joined(separator: " ")
            let secondHalf = words[mid...].joined(separator: " ")
            subtitles[index].text = "\(firstHalf)\n\(secondHalf)"
        }
    }
    
    func unbreakSelected() {
        guard let id = selectedSubtitleId, let index = subtitles.firstIndex(where: { $0.id == id }) else { return }
        if subtitles[index].text.contains("\n") {
            saveHistory()
            subtitles[index].text = subtitles[index].text.replacingOccurrences(of: "\n", with: " ")
        }
    }
    
    func italicizeSelected(range: NSRange? = nil) {
        guard let id = selectedSubtitleId, let index = subtitles.firstIndex(where: { $0.id == id }) else { return }
        saveHistory()
        let currentText = subtitles[index].text
        let nsString = currentText as NSString
        
        // Handle Selection-based Italic
        if let range = range, range.length > 0, range.location + range.length <= nsString.length {
            let selectedText = nsString.substring(with: range)
            
            // Toggle Logic: If it starts and ends with tags, remove them. Otherwise, add them.
            if selectedText.hasPrefix("<i>") && selectedText.hasSuffix("</i>") {
                let stripped = selectedText.dropFirst(3).dropLast(4)
                subtitles[index].text = nsString.replacingCharacters(in: range, with: String(stripped))
            } else {
                subtitles[index].text = nsString.replacingCharacters(in: range, with: "<i>\(selectedText)</i>")
            }
        } else {
            // Handle Whole Block Toggle
            if currentText.hasPrefix("<i>") && currentText.hasSuffix("</i>") {
                let stripped = currentText.dropFirst(3).dropLast(4)
                subtitles[index].text = String(stripped)
            } else {
                subtitles[index].text = "<i>\(currentText)</i>"
            }
        }
    }
}
