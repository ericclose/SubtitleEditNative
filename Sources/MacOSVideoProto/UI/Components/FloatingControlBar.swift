import SwiftUI

struct FloatingControlBar: View {
    @ObservedObject var player: VLCPlayer
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress Slider
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...(player.duration > 0 ? player.duration : 1),
                    onEditingChanged: { editing in
                        // Handled internally by player.isSeeking if needed,
                        // but Slider binding is usually sufficient.
                    }
                )
                .tint(.blue)
                .padding(.horizontal, 4)
                
                // Time Labels
                HStack {
                    Text(formatTime(player.currentTime))
                    Spacer()
                    Text(formatTime(player.duration))
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 12)
            
            Divider().background(.white.opacity(0.1))
            
            // Control Buttons
            HStack(spacing: 24) {
                // Speed Control
                Menu {
                    ForEach([0.5, 1.0, 1.5, 2.0, 4.0], id: \.self) { speed in
                        Button("\(speed.formatted())x") {
                            player.setSpeed(speed)
                        }
                    }
                } label: {
                    Text("\(player.playbackSpeed.formatted())x")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(width: 44)
                }
                .buttonStyle(.plain)
                
                // Back 5s
                Button(action: { player.seek(to: player.currentTime - 5) }) {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                
                // Play/Pause
                Button(action: { player.togglePlay() }) {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                
                // Forward 5s
                Button(action: { player.seek(to: player.currentTime + 5) }) {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                
                // Audio/Mute
                Button(action: { player.toggleMute() }) {
                    Image(systemName: player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(player.isMuted ? .red : .white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(width: 480)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let t = max(0, time)
        let mins = Int(t) / 60
        let secs = Int(t) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
