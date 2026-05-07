import SwiftUI
import LibSENative

struct SubtitleTableView: View {
    let lines: [SubtitleLine]
    @Binding var selection: UUID?
    let activeIndex: Int?
    
    var body: some View {
        Table(lines, selection: $selection) {
            TableColumn("#") { line in
                Text("\(line.index + 1)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(line.index == activeIndex ? .orange : .secondary)
            }
            .width(40)
            
            TableColumn("Start") { line in
                Text(line.startTimeString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(line.index == activeIndex ? .orange : .primary)
            }
            .width(100)
            
            TableColumn("End") { line in
                Text(line.endTimeString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(line.index == activeIndex ? .orange : .primary)
            }
            .width(100)
            
            TableColumn("Duration") { line in
                Text(line.durationString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(line.index == activeIndex ? .orange : .secondary)
            }
            .width(70)
            
            TableColumn("Gap") { line in
                if let gap = line.gap {
                    Text(String(format: "%.3f", gap))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(gap < 0.001 ? .red : (line.index == activeIndex ? .orange : .secondary))
                } else {
                    Text("-").foregroundColor(.secondary)
                }
            }
            .width(60)
            
            TableColumn("CPS") { line in
                let cps = line.cps
                Text(String(format: "%.1f", cps))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(cps > 20 ? .red : (line.index == activeIndex ? .orange : .secondary))
            }
            .width(50)
            
            TableColumn("Text") { line in
                Text(line.text)
                    .foregroundColor(line.index == activeIndex ? .orange : .primary)
            }
        }
        .tableStyle(.inset)
    }
}
