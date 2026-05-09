import SwiftUI

struct SubtitleListView: View {
    @ObservedObject var player: VLCPlayer
    
    var body: some View {
        VStack(spacing: 0) {
            // Table Header
            HeaderView()
            
            List(player.subtitles, selection: $player.selectedSubtitleId) { item in
                SubtitleRow(item: item, player: player)
                    .tag(item.id)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(player.selectedSubtitleId == item.id ? Color.accentColor.opacity(0.2) : Color.clear)
                    .onTapGesture(count: 2) {
                        player.selectedSubtitleId = item.id
                        player.seek(to: item.startTime.totalSeconds + 0.001)
                    }
            }
            .listStyle(.plain)
        }
    }
}

struct HeaderView: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("#").frame(width: 40, alignment: .leading)
            Text("Start").frame(width: 90, alignment: .leading)
            Text("End").frame(width: 90, alignment: .leading)
            Text("Duration").frame(width: 60, alignment: .leading)
            Text("Text").frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct SubtitleRow: View {
    let item: Paragraph
    @ObservedObject var player: VLCPlayer
    
    var body: some View {
        HStack(spacing: 0) {
            Text("\(item.number)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            
            Text(item.startTime.toDisplayString())
                .font(.system(.caption, design: .monospaced))
                .frame(width: 90, alignment: .leading)
            
            Text(item.endTime.toDisplayString())
                .font(.system(.caption, design: .monospaced))
                .frame(width: 90, alignment: .leading)
            
            Text(String(format: "%.3f", item.durationTotalSeconds))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(item.plainText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
