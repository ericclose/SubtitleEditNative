import SwiftUI
import LibSENative
import AppKit

struct SpellCheckView: View {
    @Environment(\.dismiss) var dismiss
    var lines: [SubtitleLine]
    var onUpdateLine: (Int, String) -> Void
    
    @State private var currentIndex = 0
    @State private var currentText = ""
    @State private var suggestions: [String] = []
    @State private var hasError = false
    @State private var errorRange: NSRange?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Spell Check").font(.headline)
            
            if currentIndex < lines.count {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Line \(currentIndex + 1)").font(.caption).foregroundColor(.gray)
                    
                    TextEditor(text: $currentText)
                        .frame(height: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                    
                    if hasError {
                        Text("Suggestions:").font(.caption).foregroundColor(.gray)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button(suggestion) {
                                        replaceError(with: suggestion)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    } else {
                        Text("No errors found in this line.").foregroundColor(.green).font(.caption)
                    }
                }
            } else {
                Text("Spell check complete!").foregroundColor(.green)
            }
            
            HStack {
                Button("Close") { dismiss() }
                Spacer()
                if currentIndex < lines.count {
                    Button("Skip") { nextLine() }
                    Button("Next Error") { findNextError() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 350)
        .onAppear {
            loadCurrentLine()
            findNextError()
        }
    }
    
    func loadCurrentLine() {
        if currentIndex < lines.count {
            currentText = lines[currentIndex].text
            checkCurrentText()
        }
    }
    
    func checkCurrentText() {
        let spellChecker = NSSpellChecker.shared
        let range = spellChecker.checkSpelling(of: currentText, startingAt: 0)
        if range.location != NSNotFound {
            hasError = true
            errorRange = range
            suggestions = spellChecker.guesses(forWordRange: range, in: currentText, language: nil, inSpellDocumentWithTag: 0) ?? []
        } else {
            hasError = false
            errorRange = nil
            suggestions = []
        }
    }
    
    func replaceError(with replacement: String) {
        guard let range = errorRange, let swiftRange = Range(range, in: currentText) else { return }
        currentText.replaceSubrange(swiftRange, with: replacement)
        onUpdateLine(lines[currentIndex].index, currentText)
        checkCurrentText()
    }
    
    func nextLine() {
        currentIndex += 1
        loadCurrentLine()
    }
    
    func findNextError() {
        while currentIndex < lines.count {
            checkCurrentText()
            if hasError { return }
            currentIndex += 1
            if currentIndex < lines.count {
                currentText = lines[currentIndex].text
            }
        }
    }
}
