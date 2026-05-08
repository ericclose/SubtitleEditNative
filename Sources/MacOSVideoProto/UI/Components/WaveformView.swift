import SwiftUI

struct WaveformView: View {
    @ObservedObject var player: VLCPlayer
    @State private var zoomFactor: Double = 1.0
    @State private var verticalZoom: Double = 1.0
    @State private var scrollOffset: Double = 0.0
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Color.black.opacity(0.05)
                    
                    // Waveform Canvas
                    Canvas { context, size in
                        guard !player.waveformSamples.isEmpty else { return }
                        
                        let width = size.width
                        let height = size.height
                        let midY = height / 2
                        let samples = player.waveformSamples
                        
                        let visibleSamplesCount = Int(Double(samples.count) / zoomFactor)
                        let startSample = Int(scrollOffset * Double(samples.count))
                        let endSample = min(startSample + visibleSamplesCount, samples.count)
                        
                        let visibleSamples = samples[startSample..<endSample]
                        let step = width / CGFloat(visibleSamples.count)
                        
                        var path = Path()
                        for (index, peak) in visibleSamples.enumerated() {
                            let x = CGFloat(index) * step
                            let topY = midY - (CGFloat(peak.max) * midY * 0.9 * verticalZoom)
                            let bottomY = midY - (CGFloat(peak.min) * midY * 0.9 * verticalZoom)
                            
                            path.move(to: CGPoint(x: x, y: topY))
                            path.addLine(to: CGPoint(x: x, y: bottomY))
                        }
                        
                        context.stroke(path, with: .color(.blue.opacity(0.6)), lineWidth: 1)
                    }
                    
                    // Subtitle Blocks
                    ForEach(player.subtitles) { item in
                        SubtitleBlock(item: item, player: player, zoomFactor: zoomFactor, scrollOffset: scrollOffset, totalWidth: geometry.size.width)
                    }
                    
                    // Playhead (Red Line)
                    if isVisible(time: player.currentTime) {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2)
                            .offset(x: timeToX(time: player.currentTime, width: geometry.size.width))
                    }
                }
                .cornerRadius(8)
                .clipped()
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let percentage = value.location.x / geometry.size.width
                            let visibleDuration = player.duration / zoomFactor
                            let startTime = scrollOffset * player.duration
                            let targetTime = max(0, min(startTime + (Double(percentage) * visibleDuration), player.duration))
                            player.seek(to: targetTime)
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoomFactor = max(1.0, min(50.0, zoomFactor * Double(value)))
                        }
                )
            }
            
            // Timeline Controls
            HStack(spacing: 16) {
                // Horizontal Zoom
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.and.right")
                        .foregroundColor(.secondary)
                    Button { zoomFactor = max(1.0, zoomFactor - 1.0) } label: { Image(systemName: "minus.circle") }
                    Slider(value: $zoomFactor, in: 1.0...200.0)
                        .frame(width: 100)
                    Button { zoomFactor = min(200.0, zoomFactor + 5.0) } label: { Image(systemName: "plus.circle") }
                    Button("Reset") { zoomFactor = 1.0; scrollOffset = 0.0 }
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
            .padding(.top, 4)
        }
        .onChange(of: player.currentTime) { _, newTime in
            if !player.isUserInteracting {
                updateScrollOffset(for: newTime)
            }
        }
        .onChange(of: player.selectedSubtitleId) { _, newId in
            if let selected = player.subtitles.first(where: { $0.id == newId }) {
                updateScrollOffset(for: selected.startTime.totalSeconds)
            }
        }
    }
    
    private func updateScrollOffset(for time: Double) {
        guard zoomFactor > 1.0 else { 
            scrollOffset = 0
            return 
        }
        
        let visibleDuration = player.duration / zoomFactor
        let startTime = scrollOffset * player.duration
        let endTime = startTime + visibleDuration
        
        // If playhead is outside the visible area, or approaching edges (within 10%)
        let padding = visibleDuration * 0.1
        if time < (startTime + padding) || time > (endTime - padding) {
            // Center the time
            let newStart = max(0, min(time - (visibleDuration / 2), player.duration - visibleDuration))
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollOffset = newStart / player.duration
            }
        }
    }
    
    private func isVisible(time: Double) -> Bool {
        let startTime = scrollOffset * player.duration
        let endTime = startTime + (player.duration / zoomFactor)
        return time >= startTime && time <= endTime
    }
    
    private func timeToX(time: Double, width: CGFloat) -> CGFloat {
        let startTime = scrollOffset * player.duration
        let visibleDuration = player.duration / zoomFactor
        let relativeTime = time - startTime
        return CGFloat(relativeTime / visibleDuration) * width
    }
}

struct SubtitleBlock: View {
    let item: Paragraph
    @ObservedObject var player: VLCPlayer
    let zoomFactor: Double
    let scrollOffset: Double
    let totalWidth: CGFloat
    
    @State private var dragMode: DragMode = .none
    @State private var initialStartTime: Double = 0
    @State private var initialEndTime: Double = 0
    
    enum DragMode {
        case none, moving, resizingLeft, resizingRight
    }
    
    var body: some View {
        let startTimeVisible = scrollOffset * player.duration
        let visibleDuration = player.duration / zoomFactor
        let endTimeVisible = startTimeVisible + visibleDuration
        
        if item.endTime.totalSeconds < startTimeVisible || item.startTime.totalSeconds > endTimeVisible {
            EmptyView()
        } else {
            let xStart = max(0, CGFloat((item.startTime.totalSeconds - startTimeVisible) / visibleDuration) * totalWidth)
            let xEnd = min(totalWidth, CGFloat((item.endTime.totalSeconds - startTimeVisible) / visibleDuration) * totalWidth)
            let width = xEnd - xStart
            
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(player.selectedSubtitleId == item.id ? Color.yellow.opacity(0.3) : Color.blue.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(player.selectedSubtitleId == item.id ? Color.yellow : Color.blue.opacity(0.5), lineWidth: 1)
                    )
                
                Text(item.text)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .foregroundColor(.white)
                
                // Invisible handles for resizing
                HStack(spacing: 0) {
                    Rectangle().fill(Color.clear).frame(width: 10).contentShape(Rectangle())
                        .onHover { inside in if inside { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() } }
                        .gesture(dragGesture(mode: .resizingLeft))
                    
                    Spacer()
                    
                    Rectangle().fill(Color.clear).frame(width: 10).contentShape(Rectangle())
                        .onHover { inside in if inside { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() } }
                        .gesture(dragGesture(mode: .resizingRight))
                }
            }
            .frame(width: max(0, width), height: 80)
            .offset(x: xStart, y: 10)
            .onTapGesture {
                player.selectedSubtitleId = item.id
                player.seek(to: item.startTime.totalSeconds + 0.001)
            }
            .gesture(dragGesture(mode: .moving))
        }
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
                
                let visibleDuration = player.duration / zoomFactor
                let deltaSeconds = Double(value.translation.width / totalWidth) * visibleDuration
                
                if let index = player.subtitles.firstIndex(where: { $0.id == item.id }) {
                    let itemDuration = initialEndTime - initialStartTime
                    let videoDuration = player.duration > 0 ? player.duration : 3600
                    
                    // Find neighbors for collision detection
                    let sortedSubs = player.subtitles.sorted { $0.startTime.totalSeconds < $1.startTime.totalSeconds }
                    let myIndex = sortedSubs.firstIndex(where: { $0.id == item.id }) ?? 0
                    
                    let minBound: Double = (myIndex > 0) ? sortedSubs[myIndex - 1].endTime.totalSeconds : 0
                    let maxBound: Double = (myIndex < sortedSubs.count - 1) ? sortedSubs[myIndex + 1].startTime.totalSeconds : videoDuration
                    
                    switch dragMode {
                    case .moving:
                        let newStart = max(minBound, min(initialStartTime + deltaSeconds, maxBound - itemDuration))
                        player.subtitles[index].startTime.totalSeconds = newStart
                        player.subtitles[index].endTime.totalSeconds = newStart + itemDuration
                    case .resizingLeft:
                        let newStart = max(minBound, min(initialStartTime + deltaSeconds, initialEndTime - 0.1))
                        player.subtitles[index].startTime.totalSeconds = newStart
                    case .resizingRight:
                        let newEnd = min(maxBound, max(initialEndTime + deltaSeconds, initialStartTime + 0.1))
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
