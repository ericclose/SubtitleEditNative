import SwiftUI

struct ContentView: View {
    @ObservedObject var player: VLCPlayer
    
    var body: some View {
        VSplitView {
            HSplitView {
                // Subtitle List Area
                VStack(spacing: 0) {
                    HStack {
                        Label("Subtitles", systemImage: "list.dash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(player.subtitles.count) items")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    
                    SubtitleListView(player: player)
                }
                .frame(minWidth: 400, maxWidth: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
                
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
                                    
                                    Text("Press ⌘O to import video")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.2))
                                }
                            }
                        )
                    
                    FloatingControlBar(player: player)
                        .padding(.bottom, 30)
                }
                .frame(minWidth: 400, minHeight: 300)
            }
            .layoutPriority(1)
            
            // Timeline Area
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Timeline", systemImage: "waveform.path")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(player.formatTime(player.currentTime)) / \(player.formatTime(player.duration))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                WaveformView(player: player)
                    .frame(height: 180) // Slightly taller
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .frame(height: 240)
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
