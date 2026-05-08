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
                    HStack(spacing: 0) {
                        // 1. Explicit Leading Gutter
                        Spacer().frame(width: leftMargin)
                        
                        ZStack(alignment: .topLeading) {
                            let totalWidth = player.duration * pixelsPerSecond
                            
                            // 2. Waveform Background
                            Color.black.opacity(0.9)
                                .frame(width: totalWidth, height: 140)
                            
                            // 3. Waveform Chunks
                            LazyHStack(alignment: .top, spacing: 0) {
                                let totalChunks = Int(ceil(player.duration / chunkSize))
                                let samples = player.waveformSamples
                                ForEach(0..<totalChunks, id: \.self) { i in
                                    let startTime = Double(i) * chunkSize
                                    WaveformChunk(
                                        samples: samples,
                                        startTime: startTime,
                                        duration: chunkSize,
                                        pixelsPerSecond: pixelsPerSecond,
                                        verticalZoom: verticalZoom
                                    )
                                    .frame(width: CGFloat(chunkSize * pixelsPerSecond))
                                }
                            }
                            
                            // 4. Subtitle Blocks
                            ZStack(alignment: .leading) {
                                ForEach(player.subtitles) { item in
                                    SubtitleBlock(item: item, player: player, pixelsPerSecond: pixelsPerSecond)
                                }
                            }
                            .offset(y: 20)
                            
                            // 5. Playhead
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2)
                                .offset(x: CGFloat(player.currentTime * pixelsPerSecond))
                                .id("playhead")
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { event in
                                    let time = Double(event.location.x) / pixelsPerSecond
                                    player.seek(to: max(0, min(time, player.duration)))
                                }
                        )
                        
                        // 6. Trailing Gutter
                        Spacer().frame(width: 50.0) 
                    }
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
        VStack(spacing: 0) {
            Canvas { context, size in
                let end = startTime + duration
                for s in stride(from: startTime, to: end, by: 1.0) {
                    let relativeX = CGFloat((s - startTime) * pixelsPerSecond)
                    
                    var path = Path()
                    path.move(to: CGPoint(x: relativeX, y: 12))
                    path.addLine(to: CGPoint(x: relativeX, y: 20))
                    context.stroke(path, with: .color(.gray), lineWidth: 1)
                    
                    if Int(s) % 5 == 0 {
                        let timeStr = formatTime(s)
                        context.draw(
                            Text(timeStr).font(.system(size: 10, weight: .bold)).foregroundColor(.white),
                            at: CGPoint(x: relativeX + 20, y: 6)
                        )
                    }
                }
            }
            .frame(height: 20)
            .background(Color.white.opacity(0.05))
            
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
    static let minimumGap: Double = 0.024
    
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
        .id(item.id)
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
                    
                    let sortedSubs = player.subtitles.sorted { $0.startTime.totalSeconds < $1.startTime.totalSeconds }
                    let myIndex = sortedSubs.firstIndex(where: { $0.id == item.id }) ?? 0
                    let minBound: Double = (myIndex > 0) ? sortedSubs[myIndex - 1].endTime.totalSeconds + SubtitleBlock.minimumGap : 0
                    let maxBound: Double = (myIndex < sortedSubs.count - 1) ? sortedSubs[myIndex + 1].startTime.totalSeconds - SubtitleBlock.minimumGap : player.duration
                    
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
