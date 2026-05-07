import SwiftUI
import LibSENative

struct SettingsViewFixed: View {
    @AppStorage("defaultFont") private var defaultFont = "Helvetica Neue"
    @AppStorage("ffmpegPath") private var ffmpegPath = "/opt/homebrew/bin/ffmpeg"
    @AppStorage("autoSave") private var autoSave = true
    
    let fonts = ["Helvetica Neue", "Inter", "Roboto", "PingFang SC", "Courier New"]

    var body: some View {
        TabView {
            Form {
                Section(header: Text("FFmpeg Configuration")) {
                    HStack {
                        TextField("Path", text: $ffmpegPath)
                        Button("Select...") {
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = false
                            panel.canChooseDirectories = false
                            if panel.runModal() == .OK {
                                ffmpegPath = panel.url?.path ?? ffmpegPath
                            }
                        }
                    }
                }
                Toggle("Enable Auto-Save (Experimental)", isOn: $autoSave)
            }
            .padding()
            .tabItem { Label("General", systemImage: "gearshape") }
            
            Form {
                Section(header: Text("Editor Appearance")) {
                    Picker("Default Font", selection: $defaultFont) {
                        ForEach(fonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }
                }
            }
            .padding()
            .tabItem { Label("Appearance", systemImage: "paintpalette") }
        }
        .frame(width: 450, height: 250)
    }
}
