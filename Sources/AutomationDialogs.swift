import SwiftUI
import LibSENative

struct TranslateDialog: View {
    @Environment(\.dismiss) var dismiss
    @State private var targetLanguage = "Chinese"
    let languages = ["Chinese", "English", "Japanese", "French", "German", "Spanish", "Russian"]
    
    var onTranslate: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Auto Translate").font(.headline)
            
            VStack(alignment: .leading) {
                Text("Target Language").font(.caption).foregroundColor(.gray)
                Picker("", selection: $targetLanguage) {
                    ForEach(languages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Text("This will translate all lines using the selected provider (Google Translate V2).")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Translate Now") {
                    onTranslate(targetLanguage)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct STTDialog: View {
    @Environment(\.dismiss) var dismiss
    @State private var model = "base"
    @State private var language = "Auto Detect"
    
    let models = ["tiny", "base", "small", "medium", "large"]
    let languages = ["Auto Detect", "English", "Chinese", "Japanese", "Korean"]
    
    var onStart: (String, String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Speech-to-Text (Whisper)").font(.headline)
            
            Form {
                Picker("Whisper Model", selection: $model) {
                    ForEach(models, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                Picker("Language", selection: $language) {
                    ForEach(languages, id: \.self) { l in
                        Text(l).tag(l)
                    }
                }
            }
            
            Text("Whisper will process the audio track and generate a new subtitle.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Generate") {
                    onStart(model, language)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

public struct OCRDialog: View {
    @Environment(\.dismiss) var dismiss
    @State private var engine = "Native (Apple Vision)"
    @State private var language = "en"
    
    let engines = ["Native (Apple Vision)", "Tesseract", "Google Vision"]
    let languages = [
        ("English", "en"),
        ("Chinese (Simplified)", "zh-Hans"),
        ("Chinese (Traditional)", "zh-Hant"),
        ("French", "fr"),
        ("German", "de"),
        ("Italian", "it"),
        ("Japanese", "ja"),
        ("Korean", "ko"),
        ("Portuguese", "pt"),
        ("Russian", "ru"),
        ("Spanish", "es")
    ]
    
    public var onStart: (String, String) -> Void
    
    public init(onStart: @escaping (String, String) -> Void) {
        self.onStart = onStart
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "text.viewfinder")
                    .font(.title)
                    .foregroundColor(.cyan)
                Text("Subtitle OCR").font(.headline)
            }
            
            Form {
                Picker("OCR Engine", selection: $engine) {
                    ForEach(engines, id: \.self) { e in
                        Text(e).tag(e)
                    }
                }
                Picker("Language", selection: $language) {
                    ForEach(languages, id: \.1) { (name, code) in
                        Text(name).tag(code)
                    }
                }
            }
            
            Text("Use this for image-based subtitles (e.g. BD-SUP, DVD-SUB). Native engine uses macOS Vision for best performance.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Start OCR") {
                    onStart(engine, language)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
