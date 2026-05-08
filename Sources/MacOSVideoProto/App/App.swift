import SwiftUI
import AppKit

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
                    openFilePicker()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
    
    private func openFilePicker() {
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
}
