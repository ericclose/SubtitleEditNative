import SwiftUI
import LibSENative

struct EditAreaView: View {
    @Binding var selectedLine: SubtitleLine?
    var onUpdateText: (Int, String) -> Void
    var onUpdateTimes: (Int, Double, Double) -> Void
    
    @State private var text: String = ""
    @State private var start: Double = 0
    @State private var end: Double = 0
    
    @FocusState private var isTextFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 20) {
                // Time Controls
                VStack(alignment: .leading, spacing: 10) {
                    timeField(label: "Show", value: $start)
                    timeField(label: "Hide", value: $end)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration").font(.caption2).foregroundColor(.gray)
                        Text(formatDuration(end - start))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                }
                .frame(width: 120)
                
                // Text Editor
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("TEXT").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                        Spacer()
                        if selectedLine != nil {
                            Text("\(text.count) chars | \(String(format: "%.1f", calculateCPS(text: text, start: start, end: end))) cps")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(calculateCPS(text: text, start: start, end: end) > 20 ? .red : .gray)
                        }
                    }
                    
                    TextEditor(text: $text)
                        .font(.system(size: 16))
                        .focused($isTextFocused)
                        .frame(minHeight: 80)
                        .padding(4)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(4)
                        .onChange(of: text) { newValue in
                            if let line = selectedLine {
                                onUpdateText(line.index, newValue)
                            }
                        }
                }
                
                // Action Buttons (Original Style)
                VStack(spacing: 8) {
                    Button(action: { /* Auto break logic */ }) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .help("Auto break")
                    
                    Button(action: { text = text.replacingOccurrences(of: "\n", with: " ") }) {
                        Image(systemName: "line.horizontal.3")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .help("Unbreak")
                }
            }
            .padding()
            .background(Color.black.opacity(0.2))
        }
        .onChange(of: selectedLine) { _ in
            let newLine = selectedLine
            if let line = newLine {
                text = line.text
                start = line.start
                end = line.end
                
                // Auto-focus when selection changes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFocused = true
                }
            } else {
                text = ""
                start = 0
                end = 0
            }
        }
    }
    
    private func timeField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.gray)
            TextField("", value: value, formatter: TimeFormatter())
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .onChange(of: value.wrappedValue) { newValue in
                    if let line = selectedLine {
                        onUpdateTimes(line.index, start * 1000, end * 1000)
                    }
                }
        }
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let ms = Int((duration.truncatingRemainder(dividingBy: 1)) * 1000)
        let seconds = Int(duration) % 60
        let minutes = Int(duration / 60) % 60
        return String(format: "%02d:%02d.%03d", minutes, seconds, ms)
    }
}
