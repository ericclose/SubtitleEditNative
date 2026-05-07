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
        VStack(spacing: 0) {
            // Header Toolbar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SUBTITLE EDIT NATIVE").font(.system(size: 14, weight: .black))
                    Text(statusMessage).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer()
                
                Group {
                    Button(action: openVideo) { Label("Video", systemImage: "video.fill") }
                    Button(action: openFile) { Label("Subtitle", systemImage: "doc.text.fill") }
                    Button(action: { isTranslationMode.toggle() }) {
                        Label("Translate Mode", systemImage: "arrow.left.and.right.square")
                    }
                    .tint(isTranslationMode ? .green : .gray)
                    
                    Button(action: { showStyleEditor.toggle() }) { Image(systemName: "paintbrush.fill") }
                    .tint(showStyleEditor ? .orange : .blue)
                    
                    Menu {
                        Button(action: { showFindReplace = true }) { Label("Find & Replace", systemImage: "magnifyingglass") }
                        Button(action: { showTimeShift = true }) { Label("Time Shift", systemImage: "clock.arrow.2.circlepath") }
                        Button(action: runFixCommonErrors) { Label("Fix Common Errors", systemImage: "wrench.and.screwdriver.fill") }
                        Button(action: { showSpellCheck = true }) { Label("Spell Check", systemImage: "text.badge.checkmark") }
                    } label: {
                        Label("Tools", systemImage: "hammer.fill")
                    }
                    
                    Button(action: saveFile) { Image(systemName: "square.and.arrow.down") }
                    Button(action: exportVideo) { Image(systemName: "video.badge.plus") }
                }
                .buttonStyle(.bordered)
            }
            .padding(8)
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            
            Divider()
            
            // Main Content Area
            VSplitView {
                HSplitView {
                    // Left: List and Edit Area
                    VSplitView {
                        // Enhanced Subtitle Table (Phase 2)
                        SubtitleTableView(
                            lines: lines,
                            selection: $selection,
                            activeIndex: lines.firstIndex(where: { isLineActive($0) })
                        )
                        .frame(minHeight: 200)
                        
                        // Edit Area (Phase 1 Priority)
                        
                        // Edit Area (New Priority Feature)
                        EditAreaView(
                            selectedLine: Binding(
                                get: { lines.first(where: { $0.id == selection }) },
                                set: { _ in }
                            ),
                            onUpdateText: updateSubtitleLine,
                            onUpdateTimes: updateSubtitleTimes
                        )
                        .frame(height: 150)
                    }
                    .frame(minWidth: 400)
                    
                    // Right: Video Preview
                    ZStack(alignment: .bottom) {
                        VideoPlayerView(bridge: bridge)
                            .background(Color.black)
                        
                        // Controls Overlay
                        HStack(spacing: 20) {
                            Button(action: { bridge.seek(seconds: -5) }) { Image(systemName: "gobackward.5") }
                            Button(action: { bridge.togglePause() }) { Image(systemName: "playpause.fill").font(.title2) }
                            Button(action: { bridge.seek(seconds: 5) }) { Image(systemName: "goforward.5") }
                            Divider().frame(height: 20)
                            Button(action: syncStart) { Label("Sync Start", systemImage: "arrow.right.to.line") }.foregroundColor(.green)
                            Button(action: syncEnd) { Label("Sync End", systemImage: "arrow.left.to.line") }.foregroundColor(.red)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding(.bottom, 10)
                    }
                    .frame(minWidth: 300)
                }
                .background(
                    Group {
                        Button("") { insertAfter() }.keyboardShortcut("n", modifiers: .command)
                        Button("") { insertBefore() }.keyboardShortcut("n", modifiers: [.command, .shift])
                        Button("") { deleteLine() }.keyboardShortcut(.delete, modifiers: .command)
                        Button("") { mergeWithNext() }.keyboardShortcut("m", modifiers: .command)
                    }
                    .opacity(0)
                )
                
                // Bottom: Waveform
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("AUDIO WAVEFORM")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                        Spacer()
                        HStack(spacing: 12) {
                            Image(systemName: "minus.magnifyingglass")
                            Slider(value: $waveformZoom, in: 1...30).frame(width: 100)
                            Image(systemName: "plus.magnifyingglass")
                            Button("Reset View") { waveformOffset = 0; waveformZoom = 10 }
                                .buttonStyle(.borderless).font(.system(size: 10))
                        }
                    }
                    .padding(.horizontal)
                    
                    TimelineView(.animation) { context in
                        let time = bridge.getVideoTime()
                        
                        if let waveformImage = generateWaveform(currentTime: time) {
                            ZStack {
                                Image(nsImage: waveformImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                let percent = value.location.x / 800.0
                                                let offset = (percent - 0.5) * waveformZoom
                                                let targetTime = time + offset
                                                bridge.seek(seconds: targetTime)
                                            }
                                    )
                                
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                    }
                }
                .frame(height: 120)
                .background(Color.black.opacity(0.8))
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
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
            VStack(spacing: 20) {
                Text("Find and Replace").font(.headline)
                TextField("Find", text: $findText).textFieldStyle(.roundedBorder)
                TextField("Replace", text: $replaceText).textFieldStyle(.roundedBorder)
                HStack {
                    Toggle("Match Case", isOn: $matchCase)
                    Toggle("Regex", isOn: $isRegex)
                }
                HStack {
                    Button("Close") { showFindReplace = false }
                    Spacer()
                    Button("Find Next") { performFindNext() }
                    Button("Replace All") { performReplaceAll() }.buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 350)
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
            TimeShiftView(milliseconds: $shiftMs, onApply: performTimeShift)
        }
        .onChange(of: currentTime) { time in
            if let line = lines.first(where: { time >= $0.start && time <= $0.end }) {
                if selection != line.id {
                    selection = line.id
                }
            }
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
    
    func insertAfter() {
        guard let selId = selection, let line = lines.first(where: { $0.id == selId }) else { return }
        let newStart = line.end + 0.1
        let newEnd = newStart + 2.0
        if bridge.insertParagraph(index: line.index + 1, text: "", startMs: newStart * 1000, endMs: newEnd * 1000) {
            loadSubtitle(at: filePath)
            selection = lines.first(where: { $0.index == line.index + 1 })?.id
            statusMessage = "Line inserted after"
        }
    }
    
    func insertBefore() {
        guard let selId = selection, let line = lines.first(where: { $0.id == selId }) else { return }
        let newStart = max(0, line.start - 2.1)
        let newEnd = max(0.1, line.start - 0.1)
        if bridge.insertParagraph(index: line.index, text: "", startMs: newStart * 1000, endMs: newEnd * 1000) {
            loadSubtitle(at: filePath)
            selection = lines.first(where: { $0.index == line.index })?.id
            statusMessage = "Line inserted before"
        }
    }
    
    func deleteLine() {
        guard let selId = selection, let line = lines.first(where: { $0.id == selId }) else { return }
        if bridge.removeParagraph(index: line.index) {
            let idx = line.index
            loadSubtitle(at: filePath)
            if idx < lines.count {
                selection = lines[idx].id
            } else {
                selection = lines.last?.id
            }
            statusMessage = "Line deleted"
        }
    }
    
    func mergeWithNext() {
        guard let selId = selection, let idx = lines.firstIndex(where: { $0.id == selId }), idx < lines.count - 1 else { return }
        let current = lines[idx]
        let next = lines[idx + 1]
        let mergedText = current.text + "\n" + next.text
        
        if bridge.updateParagraph(index: current.index, text: mergedText) {
            if bridge.removeParagraph(index: next.index) {
                loadSubtitle(at: filePath)
                selection = lines[idx].id
                statusMessage = "Lines merged"
            }
        }
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
        if bridge.updateParagraph(index: index, text: text) {
            if let idx = lines.firstIndex(where: { $0.index == index }) {
                let old = lines[idx]
                lines[idx] = SubtitleLine(id: old.id, index: index, start: old.start, end: old.end, text: text, gap: old.gap)
            }
        }
    }
    
    func updateSubtitleTimes(index: Int, startMs: Double, endMs: Double) {
        bridge.updateParagraphTimes(index: index, startMs: startMs, endMs: endMs)
        if let idx = lines.firstIndex(where: { $0.index == index }) {
            let old = lines[idx]
            lines[idx] = SubtitleLine(id: old.id, index: index, start: startMs / 1000.0, end: endMs / 1000.0, text: old.text, gap: old.gap)
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
        updateSubtitleTimes(index: line.index, startMs: time * 1000, endMs: line.end * 1000)
    }
    
    func syncEnd() {
        guard let selId = selection, let line = lines.first(where: { $0.id == selId }) else { return }
        let time = bridge.getVideoTime()
        updateSubtitleTimes(index: line.index, startMs: line.start * 1000, endMs: time * 1000)
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
        
        var lastEnd: Double = 0
        for i in 0..<count {
            if let text = bridge.getParagraphText(index: i) {
                let times = bridge.getParagraphTimes(index: i)
                let gap = i > 0 ? (times.start - lastEnd) : nil
                newLines.append(SubtitleLine(index: i, start: times.start, end: times.end, text: text, gap: gap))
                lastEnd = times.end
                
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
        let height = 120
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        if let cgImage = bridge.renderWaveform(width: width, height: height, currentTime: currentTime, zoom: waveformZoom, scale: scale) {
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
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        // On macOS, passing the layer pointer is more reliable for mpv 'wid'
        if let layer = view.layer {
            bridge.setVideoHandle(handle: Unmanaged.passUnretained(layer).toOpaque())
        }
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
