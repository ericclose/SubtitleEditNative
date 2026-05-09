import SwiftUI

struct SubtitleEditorView: View {
    @ObservedObject var player: VLCPlayer
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    
    var selectedItem: Paragraph? {
        player.subtitles.first { $0.id == player.selectedSubtitleId }
    }
    
    // Statistics logic
    private var charCount: Int { selectedItem?.text.count ?? 0 }
    private var charsPerSecond: Double {
        guard let item = selectedItem, item.duration.totalSeconds > 0 else { return 0 }
        return Double(charCount) / item.duration.totalSeconds
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 20) { // Increased horizontal spacing
            if let item = selectedItem {
                // 1. Left Column: Top and Bottom Symmetrical Time Controls
                VStack(alignment: .leading, spacing: 0) {
                    ClassicTimeField(label: "Start", seconds: item.startTime.totalSeconds) { 
                        player.updateStartTime(for: item, to: $0)
                    }
                    
                    Spacer() // Pushes Duration to the very bottom
                    
                    ClassicTimeField(label: "Duration", seconds: item.duration.totalSeconds, isDuration: true) { 
                        player.updateDuration(for: item, to: $0)
                    }
                }
                .frame(width: 140)
                .padding(.vertical, 16) // Added padding to separate from edges
                
                // 2. Middle Column: Text Editor (Takes all remaining space)
                VStack(spacing: 4) {
                    HStack {
                        Text("Text").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "Chars/second: %.1f", charsPerSecond))
                            .font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    
                    ParagraphEditor(text: Binding(
                        get: { item.text },
                        set: { player.updateText(for: item, to: $0) }
                    ), onSelectionChange: { range in
                        self.selectedRange = range
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    
                    HStack {
                        Text("Line length: \(charCount)").font(.system(size: 10)).padding(2).background(Color.red.opacity(0.1))
                        Spacer()
                        Text("Total chars: \(charCount)").font(.system(size: 10)).padding(2).background(Color.red.opacity(0.1))
                    }
                }
                .padding(.vertical, 4)
                
                // 3. Right Column: Evenly Distributed Tools
                VStack(spacing: 0) {
                    VerticalToolButton(icon: "text.justify.left", help: "Auto-break selected lines") { player.autoBreakSelected() }
                    
                    Spacer()
                    
                    VerticalToolButton(icon: "arrow.left.and.right.text.vertical", help: "Unbreak selected lines") { player.unbreakSelected() }
                    
                    Spacer()
                    
                    VerticalToolButton(icon: "italic", help: "Italic selected lines/text") { 
                        player.italicizeSelected(range: selectedRange)
                    }
                }
                .frame(width: 34)
                .padding(.vertical, 16) // Match left column padding
            } else {
                Text("No subtitle selected")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(15) // Extra padding for the whole container
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Classic SE Style Time Field
struct ClassicTimeField: View {
    let label: String
    let seconds: Double
    var isDuration: Bool = false
    let onUpdate: (Double) -> Void
    
    @State private var tempText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11, weight: .bold)).foregroundColor(.primary)
            
            HStack(spacing: 0) {
                TextField("", text: $tempText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(.horizontal, 6)
                    .frame(height: 32)
                    .background(Color(NSColor.textBackgroundColor))
                    .focused($isFocused)
                    .onChange(of: isFocused) { oldValue, newValue in
                        if !newValue { commit() }
                    }
                    .onSubmit { commit() }
                
                Divider().frame(height: 32)
                
                VStack(spacing: 0) {
                    Button(action: { onUpdate(seconds + 0.1) }) {
                        Image(systemName: "chevron.up").font(.system(size: 10, weight: .bold))
                            .frame(width: 24, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.gray.opacity(0.1))
                    
                    Divider().frame(width: 24)
                    
                    Button(action: { onUpdate(max(0, seconds - 0.1)) }) {
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                            .frame(width: 24, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.gray.opacity(0.1))
                }
            }
            .border(Color.gray.opacity(0.4), width: 1)
        }
        .onAppear { syncText() }
        .onChange(of: seconds) { oldValue, newValue in syncText() }
    }
    
    private func syncText() {
        if !isFocused {
            tempText = isDuration ? formatDuration(seconds) : formatTime(seconds)
        }
    }
    
    private func commit() {
        if let parsed = parseTime(tempText) {
            onUpdate(parsed)
        } else {
            syncText()
        }
    }
    
    private func formatTime(_ s: Double) -> String {
        let ms = Int((s.truncatingRemainder(dividingBy: 1)) * 1000)
        let secs = Int(s) % 60
        let mins = Int(s / 60) % 60
        let hrs = Int(s / 3600)
        return String(format: "%02d:%02d:%02d,%03d", hrs, mins, secs, ms)
    }
    
    private func formatDuration(_ s: Double) -> String {
        return String(format: "%.3f", s)
    }
    
    private func parseTime(_ text: String) -> Double? {
        let clean = text.replacingOccurrences(of: ",", with: ".")
        let parts = clean.split(separator: ":")
        if parts.count == 3 {
            guard let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) else { return nil }
            return h * 3600 + m * 60 + s
        } else if parts.count == 2 {
            guard let m = Double(parts[0]), let s = Double(parts[1]) else { return nil }
            return m * 60 + s
        } else if let s = Double(clean) {
            return s
        }
        return nil
    }
}

struct VerticalToolButton: View {
    let icon: String
    let help: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 32, height: 28)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { inside in
            if inside { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
        }
    }
}
