import SwiftUI

struct SubtitleListView: View {
    @ObservedObject var player: VLCPlayer
    
    var body: some View {
        Table(player.subtitles, selection: $player.selectedSubtitleId) {
            TableColumn("#") { item in
                Text("\(item.index)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .width(40)
            
            TableColumn("Start") { item in
                Text(player.formatTime(item.startTime))
                    .font(.system(.caption, design: .monospaced))
            }
            .width(90)
            
            TableColumn("End") { item in
                Text(player.formatTime(item.endTime))
                    .font(.system(.caption, design: .monospaced))
            }
            .width(90)
            
            TableColumn("Duration") { item in
                Text(String(format: "%.3f", item.duration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .width(60)
            
            TableColumn("Text") { item in
                Text(item.text)
                    .lineLimit(2)
            }
        }
        .onChange(of: player.selectedSubtitleId) { _, newId in
            // Selection sync
        }
        .onTapGesture(count: 2) {
            if let selectedId = player.selectedSubtitleId,
               let selected = player.subtitles.first(where: { $0.id == selectedId }) {
                player.seek(to: selected.startTime)
            }
        }
        .contextMenu {
            Button("Delete") {
                // Delete logic
            }
        }
    }
}
