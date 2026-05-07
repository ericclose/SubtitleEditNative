import SwiftUI
import AppKit
import LibSENative

// 定义聚焦动作协议，用于菜单栏与活动窗口通信
struct FocusedSubtitleActions {
    var openVideo: () -> Void
    var openSubtitle: () -> Void
    var saveSubtitle: () -> Void
    var exportVideo: () -> Void
    var showFind: () -> Void
    var showShift: () -> Void
    var undo: () -> Void
    var redo: () -> Void
    var runSTT: () -> Void
    var runTranslate: () -> Void
    var runMerge: () -> Void
    var runSpellCheck: () -> Void
}

struct FocusedSubtitleActionsKey: FocusedValueKey {
    typealias Value = FocusedSubtitleActions
}

extension FocusedValues {
    var subtitleActions: FocusedSubtitleActions? {
        get { self[FocusedSubtitleActionsKey.self] }
        set { self[FocusedSubtitleActionsKey.self] = newValue }
    }
}

@main
struct SENativeApp: App {
    @FocusedValue(\.subtitleActions) var actions

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            // 1. 文件菜单增强
            CommandGroup(replacing: .newItem) {
                Button("New Subtitle") {
                    // Logic for new
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    actions?.undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                Button("Redo") {
                    actions?.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Find & Replace...") {
                    actions?.showFind()
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            
            CommandGroup(after: .importExport) {
                Button("Open Video...") {
                    actions?.openVideo()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                
                Button("Open Subtitle...") {
                    actions?.openSubtitle()
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Save Subtitle") {
                    actions?.saveSubtitle()
                }
                .keyboardShortcut("s", modifiers: .command)
                
                Button("Merge Subtitle...") {
                    actions?.runMerge()
                }
                
                Divider()
                
                Button("Export Video (Hardcode)...") {
                    actions?.exportVideo()
                }
                .keyboardShortcut("e", modifiers: .command)
            }

            // 2. 字幕专用菜单
            CommandMenu("Subtitle") {
                Button("Adjust All Times (Shift)...") {
                    actions?.showShift()
                }
                .keyboardShortcut("g", modifiers: .command)
                
                Divider()
                
                Button("Auto Translate...") {
                    actions?.runTranslate()
                }
                
                Button("Speech to Text (Whisper)...") {
                    actions?.runSTT()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                
                Button("Spell Check...") {
                    actions?.runSpellCheck()
                }
                .keyboardShortcut("l", modifiers: .command)
            }
            
            // 3. 帮助与日志
            CommandGroup(replacing: .help) {
                Button("Subtitle Edit Native Help") {
                    if let url = URL(string: "https://github.com/SubtitleEdit/subtitleedit") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Divider()
                
                Button("View Logs in Finder...") {
                    AppLogger.shared.showLogsInFinder()
                }
            }
        }
        
        Settings {
            SettingsViewFixed()
        }
    }
}
