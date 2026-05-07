import SwiftUI
import AppKit
import LibSENative

struct ContentView: View {
    let bridge = SubtitleBridge()
    @State private var lines: [SubtitleLine] = []
    @State private var statusMessage: String = "Ready"
    @State private var filePath: String = ""
    @State private var selection: UUID?
    @State private var currentTime: Double = 0
    @State private var style = SubtitleStyle()
    @State private var showStyleEditor = false
    @State private var exportProgress: Double = 0
    @State private var videoPath: String = ""
    @State private var showFindReplace = false
    @State private var showTimeShift = false
    @State private var showSTT = false
    @State private var showTranslate = false
    @State private var showSpellCheck = false
    @State private var showOCR = false
    @State private var isTranslationMode = false
    @State private var translationLines: [Int: String] = [:]
    
    // Fix Common Errors state
    @State private var showFixResults = false
    @State private var fixCount = 0
    @State private var fixLogLines: [String] = []
    
    // Find/Replace state
    @State private var findText = ""
    @State private var replaceText = ""
    @State private var matchCase = false
    @State private var isRegex = false
    
    // Time Shift state
    @State private var shiftMs: Double = 1000
    
    // Waveform state
    @State private var waveformZoom: Double = 10.0 // seconds visible
    @State private var waveformOffset: Double = 0.0 // manual offset

    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    let fonts = ["Helvetica Neue", "Inter", "Roboto", "PingFang SC", "Courier New"]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header Toolbar (P5)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SUBTITLE EDIT NATIVE").font(.system(size: 14, weight: .black))
                        Text(statusMessage).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                    }
                    Spacer()
                    
                    Button(action: openVideo) {
                        Label("Video", systemImage: "video.fill")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: openFile) {
                        Label("Subtitle", systemImage: "doc.text.fill")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { isTranslationMode.toggle() }) {
                        Label("Translate Mode", systemImage: "arrow.left.and.right.square")
                    }
                    .buttonStyle(.bordered)
                    .tint(isTranslationMode ? .green : .gray)

                    Button(action: { showStyleEditor.toggle() }) {
                        Image(systemName: "paintbrush.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(showStyleEditor ? .orange : .blue)

                    Button(action: saveFile) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)

                    Button(action: exportVideo) {
                        Image(systemName: "video.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)

                    Button(action: { showOcrDialog() }) {
                        Label("OCR", systemImage: "text.viewfinder")
                    }
                    .buttonStyle(.bordered)
                    .tint(.cyan)

                    Button(action: runFixCommonErrors) {
                        Label("Fix", systemImage: "wrench.and.screwdriver.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding()
                .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
                
                Divider().opacity(0.1)
                
                // Video Preview (P1 Verification)
                ZStack(alignment: .bottom) {
                    VideoPlayerView(bridge: bridge)
                        .frame(height: 250)
                        .background(Color.black)
                        .cornerRadius(8)
                    
                    // Controls Overlay
                    HStack(spacing: 20) {
                        Button(action: { bridge.seek(seconds: -5) }) {
                            Image(systemName: "gobackward.5")
                        }
                        Button(action: { bridge.togglePause() }) {
                            Image(systemName: "playpause.fill")
                                .font(.title2)
                        }
                        Button(action: { bridge.seek(seconds: 5) }) {
                            Image(systemName: "goforward.5")
                        }
                        
                        Divider().frame(height: 20)
                        
                        Button(action: syncStart) {
                            Label("Sync Start", systemImage: "arrow.right.to.line")
                        }
                        .foregroundColor(.green)
                        
                        Button(action: syncEnd) {
                            Label("Sync End", systemImage: "arrow.left.to.line")
                        }
                        .foregroundColor(.red)
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.bottom, 10)
                }
                .padding()
                
                Divider().opacity(0.1)
                
                // Interactive Waveform (Timeline Alignment)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("AUDIO WAVEFORM (DRAG TO ADJUST)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Image(systemName: "minus.magnifyingglass")
                            Slider(value: $waveformZoom, in: 1...30)
                                .frame(width: 100)
                            Image(systemName: "plus.magnifyingglass")
                            
                            Button("Reset View") {
                                waveformOffset = 0
                                waveformZoom = 10
                            }
                            .buttonStyle(.borderless)
                            .font(.system(size: 10))
                        }
                    }
                    
                    TimelineView(.animation) { context in
                        let time = bridge.getVideoTime()
                        if let waveformImage = generateWaveform(currentTime: time) {
                            ZStack {
                                Image(nsImage: waveformImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 80)
                                    .cornerRadius(8)
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                handleWaveformDrag(value: value, width: 800) // Assume fixed width for simplicity or use GeometryReader
                                            }
                                            .onEnded { _ in
                                                loadSubtitle(at: filePath)
                                            }
                                    )
                                
                                // Draw vertical playhead
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: 2)
                                    .offset(x: 0)
                            }
                        }
                    }
                }
                .padding()
                
                Divider().opacity(0.1)
                
                // Content List & Editor (P3)
                VStack(spacing: 0) {
                    HSplitView {
                        List(lines, selection: $selection) { line in
                            let isActive = isLineActive(line)
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(line.index + 1)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(isActive ? .orange : .gray)
                                    .frame(width: 25)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(line.timeString)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(isActive ? .orange : .orange.opacity(0.8))
                                    
                                    HStack(spacing: 20) {
                                        Text(line.text)
                                            .font(.system(size: 13))
                                            .foregroundColor(isActive ? .white : .white.opacity(0.7))
                                            .frame(maxWidth: isTranslationMode ? .infinity : nil, alignment: .leading)
                                        
                                        if isTranslationMode {
                                            TextField("Translation", text: Binding(
                                                get: { translationLines[line.index] ?? "" },
                                                set: { translationLines[line.index] = $0; updateTranslation(line.index, $0) }
                                            ))
                                            .textFieldStyle(.plain)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.green)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(isActive ? Color.orange.opacity(0.2) : (selection == line.id ? Color.white.opacity(0.05) : Color.clear))
                        }
                        .listStyle(.inset)
                        
                        if showStyleEditor {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("STYLE SETTINGS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Font Family").font(.caption2).foregroundColor(.gray)
                                Picker("", selection: $style.fontName) {
                                    ForEach(fonts, id: \.self) { font in
                                        Text(font).tag(font)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Size: \(Int(style.fontSize))pt").font(.caption2).foregroundColor(.gray)
                                Slider(value: $style.fontSize, in: 10...72, step: 1)
                            }
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Text").font(.caption2).foregroundColor(.gray)
                                    ColorPicker("", selection: $style.textColor)
                                }
                                Spacer()
                                VStack(alignment: .leading) {
                                    Text("Outline").font(.caption2).foregroundColor(.gray)
                                    ColorPicker("", selection: $style.outlineColor)
                                }
                            }
                            
                            Button(action: applyStyles) {
                                Text("Apply Global Styles")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(width: 200)
                        .padding()
                        }
                    }
                    
                    // Style Preview (P2)
                    if let selId = selection, let line = lines.first(where: { $0.id == selId }) {
                        VStack {
                            Text(line.text)
                                .font(.custom(style.fontName, size: style.fontSize))
                                .foregroundColor(style.textColor)
                                .shadow(color: style.outlineColor, radius: 2)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.black.opacity(0.8))
                        }
                        .frame(height: 80)
                        .transition(.move(edge: .bottom))
                    }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .onReceive(timer) { _ in
            currentTime = bridge.getVideoTime()
        }
        .onAppear {
            bridge.setProgressCallback { (progress, msg) in
                self.exportProgress = progress
                self.statusMessage = msg
                if progress >= 1.0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.exportProgress = 0
                        loadSubtitle(at: filePath) // Final reload
                    }
                }
            }
        }
        .focusedValue(\.subtitleActions, FocusedSubtitleActions(
            openVideo: { self.openVideo() },
            openSubtitle: { self.openFile() },
            saveSubtitle: { self.saveFile() },
            exportVideo: { self.exportVideo() },
            showFind: { self.showFindReplace = true },
            showShift: { self.showTimeShift = true },
            undo: { self.performUndo() },
            redo: { self.performRedo() },
            runSTT: { self.runSTT() },
            runTranslate: { self.runTranslate() },
            runMerge: { self.runMerge() },
            runSpellCheck: { self.showSpellCheck = true }
        ))
        .sheet(isPresented: $showFindReplace) {
            FindReplaceView(
                findText: $findText,
                replaceText: $replaceText,
                matchCase: $matchCase,
                isRegex: $isRegex,
                onFindNext: performFindNext,
                onReplaceAll: performReplaceAll
            )
        }
        .sheet(isPresented: $showSTT) {
            STTDialog(onStart: performSTT)
        }
        .sheet(isPresented: $showOCR) {
            OCRDialog(onStart: { engine, lang in
                performOCR(engine: engine, language: lang)
            })
        }
        .sheet(isPresented: $showTranslate) {
            TranslateDialog(onTranslate: performTranslate)
        }
        .sheet(isPresented: $showSpellCheck) {
            SpellCheckView(lines: lines, onUpdateLine: updateSubtitleLine)
        }
        .sheet(isPresented: $showTimeShift) {
            TimeShiftView(shiftMs: $shiftMs, onApply: performTimeShift)
        }
        .sheet(isPresented: $showFixResults) {
            FixResultsView(count: fixCount, logLines: fixLogLines)
        }
        .overlay {
            if exportProgress > 0 && exportProgress < 1.0 {
                VStack(spacing: 20) {
                    ProgressView("Processing...", value: exportProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .padding()
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .frame(width: 300)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(radius: 10)
            }
        }
    }

    // --- Interactive Waveform Logic ---
    func handleWaveformDrag(value: DragGesture.Value, width: Double) {
        guard let selId = selection, let line = lines.first(where: { $0.id == selId }) else { return }
        
        let time = bridge.getVideoTime()
        let x = value.location.x
        let timeAtCursor = time + (Double(x) / width - 0.5) * 10.0
        
        // Simple logic: if click was near start, move start. If near end, move end.
        let distStart = abs(timeAtCursor - line.start)
        let distEnd = abs(timeAtCursor - line.end)
        
        var newStart = line.start
        var newEnd = line.end
        
        if distStart < distEnd {
            newStart = timeAtCursor
        } else {
            newEnd = timeAtCursor
        }
        
        if newEnd > newStart {
            bridge.updateParagraphTimes(index: line.index, startMs: newStart * 1000, endMs: newEnd * 1000)
            // We don't reload every frame for performance, just update local state if needed
        }
    }

    // --- Actions ---
    func runSTT() {
        if videoPath.isEmpty {
            statusMessage = "Please open a video first"
            return
        }
        showSTT = true
    }
    
    func performSTT(model: String, lang: String) {
        AppLog("Starting STT: model=\(model), lang=\(lang)")
        bridge.speechToText(videoPath: videoPath)
        statusMessage = "Starting Whisper (\(model), \(lang))..."
    }
    
    func runTranslate() {
        showTranslate = true
    }
    
    func performTranslate(lang: String) {
        AppLog("Starting translation to: \(lang)")
        bridge.translate(targetLang: lang)
        statusMessage = "Translating to \(lang)..."
    }

    func updateSubtitleLine(index: Int, text: String) {
        _ = bridge.updateParagraph(index: index, text: text)
        // No full reload needed, just update the lines array locally for responsiveness
        if let idx = lines.firstIndex(where: { $0.index == index }) {
            lines[idx] = SubtitleLine(index: index, start: lines[idx].start, end: lines[idx].end, text: text)
        }
    }
    
    func runMerge() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.text]
        if panel.runModal() == .OK {
            if let url = panel.url {
                if bridge.mergeSubtitles(path: url.path) {
                    loadSubtitle(at: filePath)
                    statusMessage = "Subtitles merged"
                }
            }
        }
    }
    
    func syncStart() {
        guard let selId = selection, let line = lines.first(where: { $0.id == selId }) else { return }
        let time = bridge.getVideoTime()
        bridge.updateParagraphTimes(index: line.index, startMs: time * 1000, endMs: line.end * 1000)
        loadSubtitle(at: filePath)
    }
    
    func syncEnd() {
        guard let selId = selection, let line = lines.first(where: { $0.id == selId }) else { return }
        let time = bridge.getVideoTime()
        bridge.updateParagraphTimes(index: line.index, startMs: line.start * 1000, endMs: time * 1000)
        loadSubtitle(at: filePath)
    }

    func performUndo() {
        AppLog("User requested Undo")
        if bridge.undo() {
            loadSubtitle(at: filePath)
            self.statusMessage = "Undo successful"
        } else {
            self.statusMessage = "Nothing to undo"
        }
    }
    
    func showOcrDialog() {
        showOCR = true
    }
    
    func performOCR(engine: String, language: String) {
        statusMessage = "Starting OCR with \(engine) (\(language))..."
        // In a real implementation, this would trigger the LibSE OCR engine
        // which now has the NativeOcrStrategy registered.
        // For demonstration, we'll simulate progress.
        
        bridge.setProgressCallback { progress, msg in
            statusMessage = "OCR: \(Int(progress * 100))% - \(msg)"
            if progress >= 1.0 {
                statusMessage = "OCR Completed successfully."
                loadSubtitle(at: filePath)
            }
        }
        
        // bridge.startOcr(engine: engine, language: language) 
        // (This would be the next step in Phase 3)
    }
    
    func runFixCommonErrors() {
        let result = bridge.fixCommonErrors()
        self.fixCount = result.count
        self.fixLogLines = result.log.components(separatedBy: "\n").filter { !$0.isEmpty }
        if result.count > 0 {
            loadSubtitle(at: filePath)
        }
        showFixResults = true
    }
    
    func performRedo() {
        if bridge.redo() {
            loadSubtitle(at: filePath)
            self.statusMessage = "Redo successful"
        } else {
            self.statusMessage = "Nothing to redo"
        }
    }
    
    func performFindNext() {
        let startIndex = lines.firstIndex(where: { $0.id == selection }) ?? -1
        let foundIndex = bridge.findNext(text: findText, matchCase: matchCase, isRegex: isRegex, startIndex: startIndex + 1)
        if foundIndex != -1 {
            selection = lines[foundIndex].id
            statusMessage = "Found at line \(foundIndex + 1)"
        } else {
            statusMessage = "Text not found"
        }
    }
    
    func performReplaceAll() {
        let count = bridge.replaceAll(findText: findText, replaceText: replaceText, matchCase: matchCase, isRegex: isRegex)
        statusMessage = "Replaced \(count) occurrences"
        loadSubtitle(at: filePath)
    }
    
    func performTimeShift(ms: Double) {
        bridge.shiftTimes(milliseconds: ms)
        loadSubtitle(at: filePath)
    }

    func applyStyles() {
        let textHex = style.textColor.toHex() ?? "#FFFFFF"
        bridge.updateStyle(font: style.fontName, size: style.fontSize, color: textHex)
    }
    
    func saveFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.item]
        if panel.runModal() == .OK, let url = panel.url {
            AppLog("Saving file to: \(url.path)")
            _ = bridge.saveSubtitle(path: url.path)
            self.statusMessage = "File saved: \(url.lastPathComponent)"
        }
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.item]
        if panel.runModal() == .OK, let url = panel.url {
            AppLog("Opening file: \(url.path)")
            loadSubtitle(at: url.path)
        }
    }
    
    func openVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.video, .movie]
        if panel.runModal() == .OK, let url = panel.url {
            AppLog("User selected video: \(url.path)")
            bridge.playVideo(path: url.path)
            self.videoPath = url.path
            self.statusMessage = "Playing: \(url.lastPathComponent)"
        }
    }

    func exportVideo() {
        if videoPath.isEmpty { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        if panel.runModal() == .OK, let url = panel.url {
            AppLog("Starting video export: \(url.path)")
            self.exportProgress = 0.01
            bridge.exportVideo(videoPath: videoPath, subPath: filePath.isEmpty ? nil : filePath, outPath: url.path)
        }
    }

    func updateTranslation(_ index: Int, _ text: String) {
        bridge.updateTranslationText(index: index, text: text)
    }

    func loadSubtitle(at path: String) {
        if path.isEmpty { return }
        AppLog("Loading subtitle from: \(path)")
        _ = bridge.loadSubtitle(path: path)
        self.filePath = path
        let count = bridge.getLineCount()
        var newLines: [SubtitleLine] = []
        var newTranslations: [Int: String] = [:]
        
        for i in 0..<count {
            if let text = bridge.getParagraphText(index: i) {
                let times = bridge.getParagraphTimes(index: i)
                newLines.append(SubtitleLine(index: i, start: times.start, end: times.end, text: text))
                
                if let trans = bridge.getTranslationText(index: i) {
                    newTranslations[i] = trans
                }
            }
        }
        self.lines = newLines
        self.translationLines = newTranslations
        self.statusMessage = "Loaded \(count) lines"
    }

    func generateWaveform(currentTime: Double) -> NSImage? {
        let width = 800
        let height = 150
        if let cgImage = bridge.renderWaveform(width: width, height: height, currentTime: currentTime + waveformOffset, zoom: waveformZoom) {
            return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        }
        return nil
    }

    func isLineActive(_ line: SubtitleLine) -> Bool {
        return currentTime >= line.start && currentTime <= line.end
    }
}

// --- Supporting Structs ---

struct SubtitleStyle {
    var fontName: String = "Helvetica Neue"
    var fontSize: CGFloat = 20
    var textColor: Color = .white
    var outlineColor: Color = .black
}

struct VideoPlayerView: NSViewRepresentable {
    let bridge: SubtitleBridge
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // libmpv needs the raw pointer or window handle
        bridge.setVideoHandle(handle: Unmanaged.passUnretained(view).toOpaque())
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct WaveformView: View {
    let image: NSImage?
    var body: some View {
        if let img = image {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color.black.opacity(0.1)
        }
    }
}

extension Color {
    func toHex() -> String? {
        let nscolor = NSColor(self)
        guard let rgbColor = nscolor.usingColorSpace(.deviceRGB) else { return nil }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

struct FindReplaceView: View {
    @Binding var findText: String
    @Binding var replaceText: String
    @Binding var matchCase: Bool
    @Binding var isRegex: Bool
    @Environment(\.dismiss) var dismiss
    var onFindNext: () -> Void
    var onReplaceAll: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Find & Replace").font(.headline)
            VStack(alignment: .leading) {
                Text("Find").font(.caption).foregroundColor(.gray)
                TextField("Text to find", text: $findText).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading) {
                Text("Replace with").font(.caption).foregroundColor(.gray)
                TextField("Replacement text", text: $replaceText).textFieldStyle(.roundedBorder)
            }
            HStack {
                Toggle("Match Case", isOn: $matchCase).toggleStyle(.checkbox)
                Spacer()
                Toggle("Regex", isOn: $isRegex).toggleStyle(.checkbox)
            }
            HStack {
                Button("Close") { dismiss() }
                Spacer()
                Button("Replace All") { onReplaceAll() }
                Button("Find Next") { onFindNext() }.keyboardShortcut(.defaultAction)
            }
        }.padding().frame(width: 350)
    }
}

struct TimeShiftView: View {
    @Binding var shiftMs: Double
    @Environment(\.dismiss) var dismiss
    var onApply: (Double) -> Void
    var body: some View {
        VStack(spacing: 20) {
            Text("Bulk Time Shift").font(.headline)
            VStack(alignment: .leading) {
                Text("Adjustment (milliseconds)").font(.caption).foregroundColor(.gray)
                HStack {
                    TextField("", value: $shiftMs, format: .number).textFieldStyle(.roundedBorder)
                    Text("ms")
                }
            }
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Apply Shift") { onApply(shiftMs); dismiss() }.buttonStyle(.borderedProminent)
            }
        }.padding().frame(width: 300)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct FixResultsView: View {
    let count: Int
    let logLines: [String]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title)
                    .foregroundColor(.orange)
                Text("Fix Results")
                    .font(.title2.bold())
                Spacer()
                Text("\(count) items fixed")
                    .font(.caption)
                    .padding(6)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
            }
            
            if logLines.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    Text("Everything looks good!")
                        .font(.headline)
                    Text("No common errors were detected in this file.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(logLines, id: \.self) { log in
                            HStack(alignment: .top) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                    .padding(.top, 2)
                                Text(log)
                                    .font(.system(size: 12, design: .monospaced))
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(6)
                        }
                    }
                }
            }
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}
