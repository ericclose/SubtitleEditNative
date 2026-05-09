import SwiftUI

struct WaveformView: View {
    @ObservedObject var player: VLCPlayer
    @State private var pixelsPerSecond: Double = 100.0
    @State private var verticalZoom: Double = 1.0
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    private let chunkSize: Double = 10.0
    private let leftMargin: CGFloat = 50.0 
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    let totalWidth = player.duration * pixelsPerSecond + leftMargin + 50.0 // 50 is trailing gutter
                    
                    ZStack(alignment: .topLeading) {
                        // 1. Background
                        Color.black.opacity(0.9)
                            .frame(width: totalWidth, height: 140)
                        
                        // 2. Waveform Chunks (Audio peaks only)
                        let totalChunks = Int(ceil(player.duration / chunkSize))
                        let samples = player.waveformSamples
                        ForEach(0..<totalChunks, id: \.self) { i in
                            let startTime = Double(i) * chunkSize
                            let width = CGFloat(chunkSize * pixelsPerSecond)
                            WaveformChunk(
                                samples: samples,
                                startTime: startTime,
                                duration: chunkSize,
                                pixelsPerSecond: pixelsPerSecond,
                                verticalZoom: verticalZoom
                            )
                            .frame(width: width, height: 120)
                            .position(x: CGFloat(startTime * pixelsPerSecond) + width/2 + leftMargin, y: 80)
                        }
                        
                        // 3. Global Ruler (Time markers) - Single Canvas to prevent clipping
                        Canvas { context, size in
                            let step: Double = 5.0 // Marker every 5 seconds
                            for s in stride(from: 0, to: player.duration, by: 1.0) {
                                let x = CGFloat(s * pixelsPerSecond) + leftMargin
                                
                                var path = Path()
                                path.move(to: CGPoint(x: x, y: 15))
                                path.addLine(to: CGPoint(x: x, y: 20))
                                context.stroke(path, with: .color(.gray), lineWidth: 1)
                                
                                if Int(s) % Int(step) == 0 {
                                    let timeStr = formatTime(s)
                                    context.draw(
                                        Text(timeStr).font(.system(size: 10, weight: .bold)).foregroundColor(.white),
                                        at: CGPoint(x: x, y: 8),
                                        anchor: .center
                                    )
                                }
                            }
                        }
                        .frame(width: totalWidth, height: 25)
                        .background(Color.white.opacity(0.05))
                        
                        // 4. Subtitle Blocks
                        ForEach(player.subtitles) { item in
                            SubtitleBlock(item: item, player: player, pixelsPerSecond: pixelsPerSecond, xOffset: leftMargin)
                        }
                        
                        // 5. Playhead
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2)
                            .position(x: CGFloat(player.currentTime * pixelsPerSecond) + leftMargin, y: 80)
                            .id("playhead")
                    }
                    .frame(width: totalWidth, height: 140)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { event in
                                let time = (Double(event.location.x) - Double(leftMargin)) / pixelsPerSecond
                                player.seek(to: max(0, min(time, player.duration)))
                            }
                    )
                }
                .onAppear {
                    self.scrollProxy = proxy
                }
                .frame(height: 160)
                .background(Color.black)
            }
            
            // Timeline Controls
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.and.right")
                        .foregroundColor(.secondary)
                    Button { pixelsPerSecond = max(10.0, pixelsPerSecond - 10.0) } label: { Image(systemName: "minus.circle") }
                    Slider(value: $pixelsPerSecond, in: 10.0...500.0)
                        .frame(width: 100)
                    Button { pixelsPerSecond = min(500.0, pixelsPerSecond + 10.0) } label: { Image(systemName: "plus.circle") }
                    Text("\(Int(pixelsPerSecond)) px/s").font(.caption2).monospacedDigit()
                }
                
                Divider().frame(height: 16)
                
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.and.down")
                        .foregroundColor(.secondary)
                    Button { verticalZoom = max(0.1, verticalZoom - 0.2) } label: { Image(systemName: "minus.circle") }
                    Slider(value: $verticalZoom, in: 0.1...5.0)
                        .frame(width: 80)
                    Button { verticalZoom = min(5.0, verticalZoom + 0.2) } label: { Image(systemName: "plus.circle") }
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct WaveformChunk: View, Equatable {
    let samples: [WavePeak]
    let startTime: Double
    let duration: Double
    let pixelsPerSecond: Double
    let verticalZoom: Double
    
    static func == (lhs: WaveformChunk, rhs: WaveformChunk) -> Bool {
        return lhs.startTime == rhs.startTime &&
               lhs.duration == rhs.duration &&
               lhs.pixelsPerSecond == rhs.pixelsPerSecond &&
               lhs.verticalZoom == rhs.verticalZoom &&
               lhs.samples.count == rhs.samples.count
    }
    
    var body: some View {
            Canvas { context, size in
                guard !samples.isEmpty else { return }
                let height = size.height
                let midY = height / 2
                let peaksPerSecond = 100.0
                let samplesPerPixel = peaksPerSecond / pixelsPerSecond
                let startSampleIdx = Int(startTime * peaksPerSecond)
                
                var path = Path()
                for x in stride(from: 0, to: size.width, by: 1) {
                    let sampleIdx = startSampleIdx + Int(Double(x) * samplesPerPixel)
                    guard sampleIdx < samples.count else { break }
                    
                    let peak = samples[sampleIdx]
                    let topY = midY - (CGFloat(peak.max) * midY * 0.9 * verticalZoom)
                    let bottomY = midY - (CGFloat(peak.min) * midY * 0.9 * verticalZoom)
                    
                    path.move(to: CGPoint(x: x, y: topY))
                    path.addLine(to: CGPoint(x: x, y: bottomY))
                }
                context.stroke(path, with: .color(.blue.opacity(0.8)), lineWidth: 1)
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
    let xOffset: CGFloat
    
    @State private var dragMode: DragMode = .none
    @State private var initialStartTime: Double = 0
    @State private var initialEndTime: Double = 0
    static let minimumGap: Double = 0.024
    
    enum DragMode {
        case none, moving, resizingLeft, resizingRight, resizingLeftAnd, resizingRightAnd
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
        .position(x: xStart + width/2 + xOffset, y: 70) // Unified absolute anchoring
        .id(item.id)
        .onTapGesture {
            player.selectedSubtitleId = item.id
            player.seek(to: item.startTime.totalSeconds)
        }
        .gesture(dragGesture(mode: .moving))
    }
    
    private func dragGesture(mode: DragMode) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let modifiers = NSEvent.modifierFlags
                let isAltDown = modifiers.contains(.option)
                let isShiftDown = modifiers.contains(.shift)
                
                var currentMode = mode
                if isAltDown {
                    if mode == .resizingLeft { currentMode = .resizingLeftAnd }
                    else if mode == .resizingRight { currentMode = .resizingRightAnd }
                }

                if dragMode == .none {
                    dragMode = currentMode
                    initialStartTime = item.startTime.totalSeconds
                    initialEndTime = item.endTime.totalSeconds
                    player.isUserInteracting = true
                }
                
                let deltaSeconds = Double(value.translation.width) / pixelsPerSecond
                
                if let index = player.subtitles.firstIndex(where: { $0.id == item.id }) {
                    let itemDuration = initialEndTime - initialStartTime
                    let sortedSubs = player.subtitles.sorted { $0.startTime.totalSeconds < $1.startTime.totalSeconds }
                    let myIndex = sortedSubs.firstIndex(where: { $0.id == item.id }) ?? 0
                    
                    // Boundary logic (Shift overrides overlap prevention)
                    var minBound: Double = 0
                    var maxBound: Double = player.duration
                    
                    if !isShiftDown {
                        minBound = (myIndex > 0) ? sortedSubs[myIndex - 1].endTime.totalSeconds + SubtitleBlock.minimumGap : 0
                        maxBound = (myIndex < sortedSubs.count - 1) ? sortedSubs[myIndex + 1].startTime.totalSeconds - SubtitleBlock.minimumGap : player.duration
                    }
                    
                    switch dragMode {
                    case .moving:
                        let newStart = player.snapToFrame(max(minBound, min(initialStartTime + deltaSeconds, maxBound - itemDuration)))
                        player.subtitles[index].startTime.totalSeconds = newStart
                        player.subtitles[index].endTime.totalSeconds = newStart + itemDuration
                        
                    case .resizingLeft:
                        let newStart = player.snapToFrame(max(minBound, min(initialStartTime + deltaSeconds, initialEndTime - 0.05)))
                        player.subtitles[index].startTime.totalSeconds = newStart
                        
                    case .resizingRight:
                        let newEnd = player.snapToFrame(min(maxBound, max(initialEndTime + deltaSeconds, initialStartTime + 0.05)))
                        player.subtitles[index].endTime.totalSeconds = newEnd
                        
                    case .resizingLeftAnd:
                        if myIndex > 0 {
                            let prevId = sortedSubs[myIndex - 1].id
                            if let prevIndex = player.subtitles.firstIndex(where: { $0.id == prevId }) {
                                let newStart = player.snapToFrame(max(0, min(initialStartTime + deltaSeconds, initialEndTime - 0.05)))
                                player.subtitles[index].startTime.totalSeconds = newStart
                                player.subtitles[prevIndex].endTime.totalSeconds = newStart - (isShiftDown ? 0 : SubtitleBlock.minimumGap)
                            }
                        } else {
                            // Fallback to normal resizing if no previous
                            let newStart = player.snapToFrame(max(minBound, min(initialStartTime + deltaSeconds, initialEndTime - 0.05)))
                            player.subtitles[index].startTime.totalSeconds = newStart
                        }
                        
                    case .resizingRightAnd:
                        if myIndex < sortedSubs.count - 1 {
                            let nextId = sortedSubs[myIndex + 1].id
                            if let nextIndex = player.subtitles.firstIndex(where: { $0.id == nextId }) {
                                let newEnd = player.snapToFrame(min(player.duration, max(initialEndTime + deltaSeconds, initialStartTime + 0.05)))
                                player.subtitles[index].endTime.totalSeconds = newEnd
                                player.subtitles[nextIndex].startTime.totalSeconds = newEnd + (isShiftDown ? 0 : SubtitleBlock.minimumGap)
                            }
                        } else {
                            // Fallback to normal resizing if no next
                            let newEnd = player.snapToFrame(min(maxBound, max(initialEndTime + deltaSeconds, initialStartTime + 0.05)))
                            player.subtitles[index].endTime.totalSeconds = newEnd
                        }
                        
                    case .none: break
                    }
                }
            }
            .onEnded { _ in
                dragMode = .none
                player.isUserInteracting = false
            }
    }
}
