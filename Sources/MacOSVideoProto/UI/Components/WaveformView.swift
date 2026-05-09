import SwiftUI

struct WaveformView: View {
    @ObservedObject var player: VLCPlayer
    @State private var pixelsPerSecond: Double = 100.0
    @State private var verticalZoom: Double = 1.0
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportWidth: CGFloat = 800
    
    private let leftMargin: CGFloat = 50.0
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    let totalWidth = player.duration * pixelsPerSecond + leftMargin + 50.0
                    
                    ZStack(alignment: .topLeading) {
                        // 1. Spacer to define total scrollable width
                        Color.clear.frame(width: totalWidth, height: 140)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(key: ScrollOffsetKey.self, value: geo.frame(in: .named("scroll")).origin.x)
                                }
                            )
                        
                        // 2. Viewport-aware Drawing Layer
                        // This canvas translates its drawing origin based on scrollOffset
                        Canvas { context, size in
                            let scrollX = -scrollOffset // Current scroll position in pixels
                            let visibleStart = max(0, (scrollX - leftMargin) / pixelsPerSecond)
                            let visibleEnd = visibleStart + (Double(viewportWidth) / pixelsPerSecond) + 1.0
                            
                            // A. Draw Waveform
                            let samples = player.waveformSamples
                            let peaksPerSecond = 100.0
                            let midY: CGFloat = 80
                            
                            // Draw only peaks within the visible time range
                            for s in stride(from: visibleStart, to: visibleEnd, by: 1.0 / pixelsPerSecond) {
                                let sampleIdx = Int(s * peaksPerSecond)
                                if sampleIdx >= 0 && sampleIdx < samples.count {
                                    let peak = samples[sampleIdx]
                                    let x = CGFloat(s * pixelsPerSecond) + leftMargin
                                    let topY = midY - (CGFloat(peak.max) * 40 * verticalZoom)
                                    let bottomY = midY - (CGFloat(peak.min) * 40 * verticalZoom)
                                    
                                    var path = Path()
                                    path.move(to: CGPoint(x: x, y: topY))
                                    path.addLine(to: CGPoint(x: x, y: bottomY))
                                    context.stroke(path, with: .color(.blue.opacity(0.8)), lineWidth: 1)
                                }
                            }
                            
                            // B. Draw Ruler (Markers every 1s, labels every 5s)
                            for s in stride(from: floor(visibleStart), to: visibleEnd, by: 1.0) {
                                let x = CGFloat(s * pixelsPerSecond) + leftMargin
                                var path = Path()
                                path.move(to: CGPoint(x: x, y: 15))
                                path.addLine(to: CGPoint(x: x, y: 20))
                                context.stroke(path, with: .color(.gray), lineWidth: 1)
                                
                                if Int(s) % 5 == 0 {
                                    context.draw(
                                        Text(formatTime(s)).font(.system(size: 10, weight: .bold)).foregroundColor(.white),
                                        at: CGPoint(x: x, y: 8),
                                        anchor: .center
                                    )
                                }
                            }
                        }
                        .frame(width: totalWidth, height: 140)
                        
                        // 3. Subtitle Blocks (Kept as separate views for interaction)
                        ForEach(player.subtitles) { item in
                            SubtitleBlock(item: item, player: player, pixelsPerSecond: pixelsPerSecond, xOffset: leftMargin)
                        }
                        
                        // 4. Playhead
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
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    self.scrollOffset = value
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear { self.viewportWidth = geo.size.width }
                            .onChange(of: geo.size.width) { self.viewportWidth = geo.size.width }
                    }
                )
                .frame(height: 160)
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

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// SubtitleBlock and other components...

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
                handleDragChanged(value, mode: mode)
            }
            .onEnded { _ in
                handleDragEnded()
            }
    }
    
    private func handleDragChanged(_ value: DragGesture.Value, mode: DragMode) {
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
        
        guard let index = player.subtitles.firstIndex(where: { $0.id == item.id }) else { return }
        let itemDuration = initialEndTime - initialStartTime
        let sortedSubs = player.subtitles.sorted { $0.startTime.totalSeconds < $1.startTime.totalSeconds }
        let myIndex = sortedSubs.firstIndex(where: { $0.id == item.id }) ?? 0
        
        // 1. Calculate Boundaries
        var minBound: Double = 0
        var maxBound: Double = player.duration
        if !isShiftDown {
            minBound = (myIndex > 0) ? sortedSubs[myIndex - 1].endTime.totalSeconds + SubtitleBlock.minimumGap : 0
            maxBound = (myIndex < sortedSubs.count - 1) ? sortedSubs[myIndex + 1].startTime.totalSeconds - SubtitleBlock.minimumGap : player.duration
        }
        
        // 2. Execute Mode-based Update (State Machine Pattern)
        updatePositions(delta: deltaSeconds, index: index, myIndex: myIndex, sortedSubs: sortedSubs, itemDuration: itemDuration, minBound: minBound, maxBound: maxBound, isShiftDown: isShiftDown)
    }
    
    private func updatePositions(delta: Double, index: Int, myIndex: Int, sortedSubs: [Paragraph], itemDuration: Double, minBound: Double, maxBound: Double, isShiftDown: Bool) {
        switch dragMode {
        case .moving:
            let newStart = player.snapToFrame(max(minBound, min(initialStartTime + delta, maxBound - itemDuration)))
            player.subtitles[index].startTime.totalSeconds = newStart
            player.subtitles[index].endTime.totalSeconds = newStart + itemDuration
            
        case .resizingLeft:
            let newStart = player.snapToFrame(max(minBound, min(initialStartTime + delta, initialEndTime - 0.05)))
            player.subtitles[index].startTime.totalSeconds = newStart
            
        case .resizingRight:
            let newEnd = player.snapToFrame(min(maxBound, max(initialEndTime + delta, initialStartTime + 0.05)))
            player.subtitles[index].endTime.totalSeconds = newEnd
            
        case .resizingLeftAnd:
            if myIndex > 0 {
                let prevIndex = player.subtitles.firstIndex(where: { $0.id == sortedSubs[myIndex - 1].id })!
                let newStart = player.snapToFrame(max(0, min(initialStartTime + delta, initialEndTime - 0.05)))
                player.subtitles[index].startTime.totalSeconds = newStart
                player.subtitles[prevIndex].endTime.totalSeconds = newStart - (isShiftDown ? 0 : SubtitleBlock.minimumGap)
            }
            
        case .resizingRightAnd:
            if myIndex < sortedSubs.count - 1 {
                let nextIndex = player.subtitles.firstIndex(where: { $0.id == sortedSubs[myIndex + 1].id })!
                let newEnd = player.snapToFrame(min(player.duration, max(initialEndTime + delta, initialStartTime + 0.05)))
                player.subtitles[index].endTime.totalSeconds = newEnd
                player.subtitles[nextIndex].startTime.totalSeconds = newEnd + (isShiftDown ? 0 : SubtitleBlock.minimumGap)
            }
        default: break
        }
    }
    
    private func handleDragEnded() {
        dragMode = .none
        player.isUserInteracting = false
    }
}
