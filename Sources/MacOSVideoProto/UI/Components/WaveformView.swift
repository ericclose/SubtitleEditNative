import SwiftUI

struct WaveformView: View {
    @ObservedObject var player: VLCPlayer
    
    var body: some View {
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
                    let step = width / CGFloat(samples.count)
                    
                    var path = Path()
                    for (index, sample) in samples.enumerated() {
                        let x = CGFloat(index) * step
                        let h = CGFloat(sample) * midY * 0.8
                        path.move(to: CGPoint(x: x, y: midY - h))
                        path.addLine(to: CGPoint(x: x, y: midY + h))
                    }
                    
                    context.stroke(path, with: .color(.blue.opacity(0.6)), lineWidth: 1)
                }
                
                // Playhead (Red Line)
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2)
                    .offset(x: player.duration > 0 ? CGFloat(player.currentTime / player.duration) * geometry.size.width : 0)
            }
            .cornerRadius(8)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let percentage = value.location.x / geometry.size.width
                        let targetTime = max(0, min(player.duration * Double(percentage), player.duration))
                        player.seek(to: targetTime)
                    }
            )
        }
    }
}
