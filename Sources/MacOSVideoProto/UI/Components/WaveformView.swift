import SwiftUI

struct WaveformView: View {
    @ObservedObject var player: VLCPlayer
    @State private var pixelsPerSecond: Double = 100.0
    @State private var verticalZoom: Double = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Time Ruler
            TimeRuler(duration: player.duration, pixelsPerSecond: pixelsPerSecond)
                .frame(height: 20)
                .background(Color(NSColor.controlBackgroundColor))
            
            ScrollView(.horizontal, showsIndicators: true) {
                ZStack(alignment: .leading) {
                    // Background
                    Color.black.opacity(0.05)
                    
                    let totalWidth = player.duration * pixelsPerSecond
                    
                    // Waveform Canvas
                    WaveformCanvas(player: player, pixelsPerSecond: pixelsPerSecond, verticalZoom: verticalZoom)
                        .frame(width: CGFloat(totalWidth))
                    
                    // Subtitle Blocks
                    ZStack(alignment: .leading) {
                        ForEach(player.subtitles) { item in
                            SubtitleBlock(item: item, player: player, pixelsPerSecond: pixelsPerSecond)
                        }
                    }
                    
                    // Playhead (Red Line)
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2)
                        .offset(x: CGFloat(player.currentTime * pixelsPerSecond))
                }
                .frame(height: 120)
            }
            
            // Timeline Controls
            HStack(spacing: 16) {
                // Horizontal Zoom (Pixels per second)
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.and.right")
                        .foregroundColor(.secondary)
                    Button { pixelsPerSecond = max(10.0, pixelsPerSecond - 10.0) } label: { Image(systemName: "minus.circle") }
                    Slider(value: $pixelsPerSecond, in: 10.0...500.0)
                        .frame(width: 100)
                    Button { pixelsPerSecond = min(500.0, pixelsPerSecond + 10.0) } label: { Image(systemName: "plus.circle") }
                    Text("\(Int(pixelsPerSecond)) px/s").font(.caption2).monospacedDigit()
                    Button("Reset") { pixelsPerSecond = 100.0 }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
                
                Divider().frame(height: 16)
                
                // Vertical Zoom (Amplitude)
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.and.down")
                        .foregroundColor(.secondary)
                    Button { verticalZoom = max(0.1, verticalZoom - 0.2) } label: { Image(systemName: "minus.circle") }
                    Slider(value: $verticalZoom, in: 0.1...5.0)
                        .frame(width: 80)
                    Button { verticalZoom = min(5.0, verticalZoom + 0.2) } label: { Image(systemName: "plus.circle") }
                    Button("Reset") { verticalZoom = 1.0 }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

struct WaveformCanvas: View {
    @ObservedObject var player: VLCPlayer
    let pixelsPerSecond: Double
    let verticalZoom: Double
    
    var body: some View {
        Canvas { context, size in
            guard !player.waveformSamples.isEmpty else { return }
            
            let height = size.height
            let midY = height / 2
            let samples = player.waveformSamples
            let peaksPerSecond = 100.0
            let samplesPerPixel = peaksPerSecond / pixelsPerSecond
            
            var path = Path()
            for x in stride(from: 0, to: size.width, by: 1) {
                let sampleIdx = Int(Double(x) * samplesPerPixel)
                guard sampleIdx < samples.count else { break }
                
                let peak = samples[sampleIdx]
                let topY = midY - (CGFloat(peak.max) * midY * verticalZoom)
                let bottomY = midY - (CGFloat(peak.min) * midY * verticalZoom)
                
                path.move(to: CGPoint(x: x, y: topY))
                path.addLine(to: CGPoint(x: x, y: bottomY))
            }
            
            context.stroke(path, with: .color(.blue.opacity(0.6)), lineWidth: 1)
        }
    }
}

struct TimeRuler: View {
    let duration: Double
    let pixelsPerSecond: Double
    
    var body: some View {
        Canvas { context, size in
            let step = 1.0 // 1 second
            for s in stride(from: 0, to: duration, by: step) {
                let x = CGFloat(s * pixelsPerSecond)
                
                var path = Path()
                path.move(to: CGPoint(x: x, y: 10))
                path.addLine(to: CGPoint(x: x, y: 20))
                context.stroke(path, with: .color(.secondary), lineWidth: 1)
                
                if Int(s) % 5 == 0 {
                    let timeStr = formatTime(s)
                    context.draw(Text(timeStr).font(.system(size: 8)).foregroundColor(.secondary), at: CGPoint(x: x + 2, y: 5))
                }
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct SubtitleBlock: View {
    let item: Paragraph
    @ObservedObject var player: VLCPlayer
    let pixelsPerSecond: Double
    
    @State private var dragMode: DragMode = .none
    @State private var initialStartTime: Double = 0
    @State private var initialEndTime: Double = 0
    
    enum DragMode {
        case none, moving, resizingLeft, resizingRight
    }
    
    var body: some View {
        let xStart = CGFloat(item.startTime.totalSeconds * pixelsPerSecond)
        let xEnd = CGFloat(item.endTime.totalSeconds * pixelsPerSecond)
        let width = xEnd - xStart
        
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(player.selectedSubtitleId == item.id ? Color.yellow.opacity(0.4) : Color.blue.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(player.selectedSubtitleId == item.id ? Color.yellow : Color.blue.opacity(0.6), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(2)
                    .padding(.horizontal, 4)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.vertical, 4)
            
            HStack(spacing: 0) {
                Rectangle().fill(Color.white.opacity(0.001)).frame(width: 8).contentShape(Rectangle())
                    .onHover { inside in if inside { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() } }
                    .gesture(dragGesture(mode: .resizingLeft))
                Spacer()
                Rectangle().fill(Color.white.opacity(0.001)).frame(width: 8).contentShape(Rectangle())
                    .onHover { inside in if inside { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() } }
                    .gesture(dragGesture(mode: .resizingRight))
            }
        }
        .frame(width: max(0, width), height: 100)
        .offset(x: xStart, y: 10)
        .onTapGesture {
            player.selectedSubtitleId = item.id
            player.seek(to: item.startTime.totalSeconds)
        }
        .gesture(dragGesture(mode: .moving))
    }
    
    private func dragGesture(mode: DragMode) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragMode == .none {
                    dragMode = mode
                    initialStartTime = item.startTime.totalSeconds
                    initialEndTime = item.endTime.totalSeconds
                    player.isUserInteracting = true
                }
                
                let deltaSeconds = Double(value.translation.width) / pixelsPerSecond
                
                if let index = player.subtitles.firstIndex(where: { $0.id == item.id }) {
                    let itemDuration = initialEndTime - initialStartTime
                    
                    switch dragMode {
                    case .moving:
                        let newStart = max(0, min(initialStartTime + deltaSeconds, player.duration - itemDuration))
                        player.subtitles[index].startTime.totalSeconds = newStart
                        player.subtitles[index].endTime.totalSeconds = newStart + itemDuration
                    case .resizingLeft:
                        let newStart = max(0, min(initialStartTime + deltaSeconds, initialEndTime - 0.1))
                        player.subtitles[index].startTime.totalSeconds = newStart
                    case .resizingRight:
                        let newEnd = min(player.duration, max(initialEndTime + deltaSeconds, initialStartTime + 0.1))
                        player.subtitles[index].endTime.totalSeconds = newEnd
                    case .none:
                        break
                    }
                }
            }
            .onEnded { _ in
                dragMode = .none
                player.isUserInteracting = false
            }
    }
}
