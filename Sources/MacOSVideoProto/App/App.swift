import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct MacOSVideoProtoApp: App {
    @StateObject private var player = VLCPlayer()
    
    var body: some Scene {
        WindowGroup {
            ContentView(player: player)
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Video...") {
                    openVideoPicker()
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Open Subtitles...") {
                    openSubtitlePicker()
                }
                .keyboardShortcut("i", modifiers: .command)
            }
            
            CommandMenu("Edit") {
                Button("Undo") {
                    player.undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                
                Button("Redo") {
                    player.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
        }
    }
    
    private func openVideoPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .video, .quickTimeMovie, .mpeg4Movie]
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                player.loadFile(url: url)
            }
        }
    }
    
    private func openSubtitlePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "srt")!,
            UTType(filenameExtension: "vtt")!,
            UTType(filenameExtension: "ass")!,
            UTType(filenameExtension: "ssa")!
        ]
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                if let content = try? String(contentsOf: url) {
                    if let subtitle = SubtitleParser.parse(content: content, fileName: url.lastPathComponent) {
                        player.subtitles = subtitle.paragraphs
                        player.saveHistory() // Initial snapshot
                    }
                }
            }
        }
    }
}
