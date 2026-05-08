import SwiftUI

struct ContentView: View {
    @ObservedObject var player: VLCPlayer
    
    var body: some View {
        VSplitView {
            // Preview Area
            ZStack(alignment: .bottom) {
                VLCVideoView(player: player)
                    .overlay(
                        VStack(spacing: 12) {
                            if player.currentFileName == nil {
                                Image(systemName: "video.badge.plus")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.15))
                                
                                Text("No Video Loaded")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.4))
                                
                                Text("Press ⌘O to import")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.2))
                            }
                        }
                    )
                
                FloatingControlBar(player: player)
                    .padding(.bottom, 30)
            }
            .frame(minHeight: 400)
            
            // Timeline Area
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Timeline", systemImage: "waveform.path")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(formatTime(player.currentTime)) / \(formatTime(player.duration))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                WaveformView(player: player)
                    .frame(height: 120)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .frame(height: 200)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .preferredColorScheme(.dark)
    }
    
    private func formatTime(_ time: Double) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
