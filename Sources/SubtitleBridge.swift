import Foundation
import AppKit
import Vision

typealias NativeOcrCallback = @convention(c) (UnsafeRawPointer, Int32, Int32, Int32, UnsafePointer<Int8>, UnsafeMutablePointer<Int8>, Int32) -> Void

class NativeOCR {
    static func performOCR(imageBuffer: UnsafeRawPointer, width: Int32, height: Int32, stride: Int32, language: String) -> String {
        // SkiaSharp SKBitmap usually uses premultiplied last or first.
        // Assuming 8-bit RGBA for now as it's common for Skia -> Native.
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let dataProvider = CGDataProvider(dataInfo: nil, data: imageBuffer, size: Int(stride * height), releaseData: { _, _, _ in }) else { return "" }
        
        guard let cgImage = CGImage(
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: Int(stride),
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return "" }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = [language]
        request.recognitionLevel = .accurate
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let observations = request.results else { return "" }
            let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }
            return recognizedStrings.joined(separator: " ")
        } catch {
            print("OCR Error: \(error)")
            return ""
        }
    }
}

private let ocrTrampoline: NativeOcrCallback = { (buffer, w, h, stride, langPtr, resPtr, maxRes) in
    let lang = String(cString: langPtr)
    let result = NativeOCR.performOCR(imageBuffer: buffer, width: w, height: h, stride: stride, language: lang)
    
    // Copy result back to resPtr as C string
    result.withCString { cStr in
        strncpy(resPtr, cStr, Int(maxRes) - 1)
        resPtr[Int(maxRes) - 1] = 0
    }
}

public class SubtitleBridge {
    private var handle: UnsafeMutableRawPointer?
    private var context: UnsafeMutableRawPointer?
    
    typealias CreateContextFunc = @convention(c) () -> UnsafeMutableRawPointer?
    typealias DestroyContextFunc = @convention(c) (UnsafeMutableRawPointer) -> Void
    
    typealias RenderWaveformFastFunc = @convention(c) (UnsafeMutableRawPointer, Int32, Int32, Double, UnsafeMutablePointer<Int32>) -> UnsafeMutableRawPointer?
    typealias LoadSubtitleFunc = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<Int8>) -> Int32
    typealias GetParagraphTextFunc = @convention(c) (UnsafeMutableRawPointer, Int32) -> UnsafeMutableRawPointer?
    typealias GetParagraphTimesFunc = @convention(c) (UnsafeMutableRawPointer, Int32, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>) -> Int32
    typealias FreeStringFunc = @convention(c) (UnsafeMutableRawPointer) -> Void

    typealias SetVideoHandleFunc = @convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Void
    typealias UpdateParagraphTextFunc = @convention(c) (UnsafeMutableRawPointer, Int32, UnsafePointer<Int8>) -> Int32
    
    typealias PlayVideoFunc = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<Int8>) -> Void
    
    typealias TogglePauseFunc = @convention(c) (UnsafeMutableRawPointer) -> Void
    typealias VideoSeekFunc = @convention(c) (UnsafeMutableRawPointer, Double) -> Void
    typealias ExtractAudioFunc = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<Int8>) -> Void
    typealias GetVideoTimeFunc = @convention(c) (UnsafeMutableRawPointer) -> Double
    
    typealias UpdateStyleFunc = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<Int8>, Double, UnsafePointer<Int8>) -> Void
    
    typealias SaveSubtitleFunc = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<Int8>) -> Int32
    
    typealias ProgressCallback = @convention(c) (UnsafeMutableRawPointer, Double, UnsafePointer<Int8>) -> Void
    typealias SetProgressCallbackFunc = @convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Void
    typealias ExportVideoFunc = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<Int8>, UnsafePointer<Int8>?, UnsafePointer<Int8>) -> Void
    
    typealias FindNextFunc = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<Int8>, Int32, Int32, Int32) -> Int32
    typealias ReplaceAllFunc = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<Int8>, UnsafePointer<Int8>, Int32, Int32) -> Int32
    typealias ShiftTimesFunc = @convention(c) (UnsafeMutableRawPointer, Double) -> Void
    
    typealias SetLogCallbackFunc = @convention(c) (UnsafeMutableRawPointer) -> Void
    
    private static let logTrampoline: @convention(c) (Int32, UnsafePointer<Int8>) -> Void = { (level, msgPtr) in
        let msg = String(cString: msgPtr)
        let swiftLevel: LogLevel
        switch level {
        case 1: swiftLevel = .warning
        case 2: swiftLevel = .error
        default: swiftLevel = .info
        }
        AppLog("[.NET] \(msg)", level: swiftLevel)
    }
    
    typealias UndoFunc = @convention(c) (UnsafeMutableRawPointer) -> Int32
    typealias RedoFunc = @convention(c) (UnsafeMutableRawPointer) -> Int32
    
    typealias UpdateParagraphTimesFunc = @convention(c) (UnsafeMutableRawPointer, Int32, Double, Double) -> Void
    typealias SpeechToTextFunc = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<Int8>) -> Void
    typealias TranslateFunc = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<Int8>) -> Void
    typealias MergeSubtitlesFunc = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<Int8>) -> Int32
    typealias FixCommonErrorsFunc = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int32
    
    typealias InsertParagraphFunc = @convention(c) (UnsafeMutableRawPointer, Int32, UnsafePointer<Int8>, Double, Double) -> Int32
    typealias RemoveParagraphFunc = @convention(c) (UnsafeMutableRawPointer, Int32) -> Int32
    
    private var renderWaveformFn: RenderWaveformFastFunc?
    private var loadSubtitleFn: LoadSubtitleFunc?
    private var getParagraphTextFn: GetParagraphTextFunc?
    private var getParagraphTimesFn: GetParagraphTimesFunc?
    private var freeStringFn: FreeStringFunc?
    private var setVideoHandleFn: SetVideoHandleFunc?
    private var updateParagraphTextFn: UpdateParagraphTextFunc?
    private var updateParagraphTimesFn: UpdateParagraphTimesFunc?
    private var playVideoFn: PlayVideoFunc?
    private var togglePauseFn: TogglePauseFunc?
    private var videoSeekFn: VideoSeekFunc?
    private var extractAudioFn: ExtractAudioFunc?
    private var getVideoTimeFn: GetVideoTimeFunc?
    private var createContextFn: CreateContextFunc?
    private var destroyContextFn: DestroyContextFunc?
    private var updateStyleFn: UpdateStyleFunc?
    private var saveSubtitleFn: SaveSubtitleFunc?
    private var setProgressCallbackFn: SetProgressCallbackFunc?
    private var exportVideoFn: ExportVideoFunc?
    private var findNextFn: FindNextFunc?
    private var replaceAllFn: ReplaceAllFunc?
    private var shiftTimesFn: ShiftTimesFunc?
    private var undoFn: UndoFunc?
    private var redoFn: RedoFunc?
    private var sttFn: SpeechToTextFunc?
    private var translateFn: TranslateFunc?
    private var mergeFn: MergeSubtitlesFunc?
    private var fixCommonErrorsFn: FixCommonErrorsFunc?
    private var insertParagraphFn: InsertParagraphFunc?
    private var removeParagraphFn: RemoveParagraphFunc?
    
    typealias LoadTranslationFunc = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<Int8>) -> Int32
    typealias GetTranslationTextFunc = @convention(c) (UnsafeMutableRawPointer, Int32) -> UnsafeMutableRawPointer?
    typealias UpdateTranslationTextFunc = @convention(c) (UnsafeMutableRawPointer, Int32, UnsafePointer<Int8>) -> Void
    
    private var loadTranslationFn: LoadTranslationFunc?
    private var getTranslationTextFn: GetTranslationTextFunc?
    private var updateTranslationTextFn: UpdateTranslationTextFunc?

    public init() {
        let libPath = "./LibSEBridge.dylib"
        handle = dlopen(libPath, RTLD_NOW)
        if let h = handle {
            // ... (previous)
            loadTranslationFn = unsafeBitCast(dlsym(h, "se_load_translation"), to: LoadTranslationFunc.self)
            getTranslationTextFn = unsafeBitCast(dlsym(h, "se_get_translation_text"), to: GetTranslationTextFunc.self)
            updateTranslationTextFn = unsafeBitCast(dlsym(h, "se_update_translation_text"), to: UpdateTranslationTextFunc.self)
            
            // Re-assigning others for brevity in this replace call (ensure they remain)
            createContextFn = unsafeBitCast(dlsym(h, "se_create_context"), to: CreateContextFunc.self)
            destroyContextFn = unsafeBitCast(dlsym(h, "se_destroy_context"), to: DestroyContextFunc.self)
            loadSubtitleFn = unsafeBitCast(dlsym(h, "se_load_subtitle"), to: LoadSubtitleFunc.self)
            getParagraphTextFn = unsafeBitCast(dlsym(h, "se_get_paragraph_text"), to: GetParagraphTextFunc.self)
            getParagraphTimesFn = unsafeBitCast(dlsym(h, "se_get_paragraph_times"), to: GetParagraphTimesFunc.self)
            freeStringFn = unsafeBitCast(dlsym(h, "se_free_string"), to: FreeStringFunc.self)
            renderWaveformFn = unsafeBitCast(dlsym(h, "se_render_waveform_fast"), to: RenderWaveformFastFunc.self)
            setVideoHandleFn = unsafeBitCast(dlsym(h, "se_set_video_handle"), to: SetVideoHandleFunc.self)
            updateParagraphTextFn = unsafeBitCast(dlsym(h, "se_update_paragraph_text"), to: UpdateParagraphTextFunc.self)
            updateParagraphTimesFn = unsafeBitCast(dlsym(h, "se_update_paragraph_times"), to: UpdateParagraphTimesFunc.self)
            playVideoFn = unsafeBitCast(dlsym(h, "se_play_video"), to: PlayVideoFunc.self)
            togglePauseFn = unsafeBitCast(dlsym(h, "se_video_toggle_pause"), to: TogglePauseFunc.self)
            videoSeekFn = unsafeBitCast(dlsym(h, "se_video_seek"), to: VideoSeekFunc.self)
            extractAudioFn = unsafeBitCast(dlsym(h, "se_extract_audio"), to: ExtractAudioFunc.self)
            getVideoTimeFn = unsafeBitCast(dlsym(h, "se_video_get_time"), to: GetVideoTimeFunc.self)
            updateStyleFn = unsafeBitCast(dlsym(h, "se_update_style"), to: UpdateStyleFunc.self)
            saveSubtitleFn = unsafeBitCast(dlsym(h, "se_save_subtitle"), to: SaveSubtitleFunc.self)
            setProgressCallbackFn = unsafeBitCast(dlsym(h, "se_set_progress_callback"), to: SetProgressCallbackFunc.self)
            exportVideoFn = unsafeBitCast(dlsym(h, "se_export_video"), to: ExportVideoFunc.self)
            findNextFn = unsafeBitCast(dlsym(h, "se_find_next"), to: FindNextFunc.self)
            replaceAllFn = unsafeBitCast(dlsym(h, "se_replace_all"), to: ReplaceAllFunc.self)
            shiftTimesFn = unsafeBitCast(dlsym(h, "se_shift_times"), to: ShiftTimesFunc.self)
            undoFn = unsafeBitCast(dlsym(h, "se_undo"), to: UndoFunc.self)
            redoFn = unsafeBitCast(dlsym(h, "se_redo"), to: RedoFunc.self)
            sttFn = unsafeBitCast(dlsym(h, "se_speech_to_text"), to: SpeechToTextFunc.self)
            translateFn = unsafeBitCast(dlsym(h, "se_translate"), to: TranslateFunc.self)
            mergeFn = unsafeBitCast(dlsym(h, "se_merge_subtitles"), to: MergeSubtitlesFunc.self)
            fixCommonErrorsFn = unsafeBitCast(dlsym(h, "se_fix_common_errors"), to: FixCommonErrorsFunc.self)
            insertParagraphFn = unsafeBitCast(dlsym(h, "se_insert_paragraph"), to: InsertParagraphFunc.self)
            removeParagraphFn = unsafeBitCast(dlsym(h, "se_remove_paragraph"), to: RemoveParagraphFunc.self)
            
            let setOcrCallbackFn = unsafeBitCast(dlsym(h, "se_set_native_ocr_callback"), to: (@convention(c) (UnsafeMutableRawPointer) -> Void).self)
            setOcrCallbackFn(unsafeBitCast(ocrTrampoline, to: UnsafeMutableRawPointer.self))
            
            self.context = createContextFn?()
            
            if let setLogFn = dlsym(handle, "se_set_log_callback") {
                let fn = unsafeBitCast(setLogFn, to: SetLogCallbackFunc.self)
                fn(unsafeBitCast(SubtitleBridge.logTrampoline, to: UnsafeMutableRawPointer.self))
            }
        }
    }
    
    public func loadTranslation(path: String) -> Int {
        guard let ctx = context else { return -1 }
        return Int(loadTranslationFn?(ctx, path) ?? -1)
    }
    
    public func getTranslationText(index: Int) -> String? {
        guard let ctx = context, let cStr = getTranslationTextFn?(ctx, Int32(index)) else { return nil }
        let text = String(cString: cStr.assumingMemoryBound(to: Int8.self))
        freeStringFn?(cStr)
        return text
    }
    
    public func updateTranslationText(index: Int, text: String) {
        guard let ctx = context else { return }
        updateTranslationTextFn?(ctx, Int32(index), text)
    }
    
    public func updateParagraphTimes(index: Int, startMs: Double, endMs: Double) {
        guard let ctx = context else { return }
        updateParagraphTimesFn?(ctx, Int32(index), startMs, endMs)
    }
    
    public func speechToText(videoPath: String) {
        guard let ctx = context else { return }
        sttFn?(ctx, videoPath)
    }
    
    public func translate(targetLang: String) {
        guard let ctx = context else { return }
        translateFn?(ctx, targetLang)
    }
    
    public func mergeSubtitles(path: String) -> Bool {
        guard let ctx = context else { return false }
        return mergeFn?(ctx, path) == 1
    }
    
    public func fixCommonErrors() -> (count: Int, log: String) {
        guard let ctx = context else { return (0, "") }
        var logPtr: UnsafeMutableRawPointer?
        let count = fixCommonErrorsFn?(ctx, &logPtr) ?? 0
        var log = ""
        if let ptr = logPtr {
            log = String(cString: ptr.assumingMemoryBound(to: Int8.self))
            freeStringFn?(ptr)
        }
        return (Int(count), log)
    }
    
    public func undo() -> Bool {
        guard let ctx = context else { return false }
        return undoFn?(ctx) == 1
    }
    
    public func redo() -> Bool {
        guard let ctx = context else { return false }
        return redoFn?(ctx) == 1
    }
    
    public func findNext(text: String, matchCase: Bool, isRegex: Bool, startIndex: Int) -> Int {
        guard let ctx = context else { return -1 }
        return Int(findNextFn?(ctx, text, matchCase ? 1 : 0, isRegex ? 1 : 0, Int32(startIndex)) ?? -1)
    }
    
    public func replaceAll(findText: String, replaceText: String, matchCase: Bool, isRegex: Bool) -> Int {
        guard let ctx = context else { return 0 }
        return Int(replaceAllFn?(ctx, findText, replaceText, matchCase ? 1 : 0, isRegex ? 1 : 0) ?? 0)
    }
    
    public func shiftTimes(milliseconds: Double) {
        guard let ctx = context else { return }
        shiftTimesFn?(ctx, milliseconds)
    }
    
    private static var callbacks: [UnsafeMutableRawPointer: (Double, String) -> Void] = [:]
    
    private static let progressTrampoline: ProgressCallback = { (handle, progress, msgPtr) in
        let msg = String(cString: msgPtr)
        DispatchQueue.main.async {
            SubtitleBridge.callbacks[handle]?(progress, msg)
        }
    }

    public func setProgressCallback(_ callback: @escaping (Double, String) -> Void) {
        guard let ctx = context else { return }
        SubtitleBridge.callbacks[ctx] = callback
        setProgressCallbackFn?(ctx, unsafeBitCast(SubtitleBridge.progressTrampoline, to: UnsafeMutableRawPointer.self))
    }
    
    public func exportVideo(videoPath: String, subPath: String?, outPath: String) {
        guard let ctx = context else { return }
        exportVideoFn?(ctx, videoPath, subPath, outPath)
    }
    
    public func saveSubtitle(path: String) -> Bool {
        guard let ctx = context else { return false }
        return saveSubtitleFn?(ctx, path) == 1
    }
    
    public func updateStyle(font: String, size: Double, color: String) {
        guard let ctx = context else { return }
        updateStyleFn?(ctx, font, size, color)
    }
    
    deinit {
        if let ctx = context {
            destroyContextFn?(ctx)
        }
        if let h = handle {
            dlclose(h)
        }
    }
    
    public func getVideoTime() -> Double {
        guard let ctx = context else { return 0 }
        return getVideoTimeFn?(ctx) ?? 0
    }
    
    public func playVideo(path: String) {
        guard let ctx = context else { return }
        playVideoFn?(ctx, path)
        extractAudioFn?(ctx, path)
    }
    
    public func togglePause() {
        guard let ctx = context else { return }
        togglePauseFn?(ctx)
    }
    
    public func seek(seconds: Double) {
        guard let ctx = context else { return }
        videoSeekFn?(ctx, seconds)
    }
    
    public func setVideoHandle(handle: UnsafeMutableRawPointer) {
        guard let ctx = context else { return }
        setVideoHandleFn?(ctx, handle)
    }
    
    public func updateParagraph(index: Int, text: String) -> Bool {
        guard let ctx = context else { return false }
        return updateParagraphTextFn?(ctx, Int32(index), text) == 1
    }
    
    public func insertParagraph(index: Int, text: String, startMs: Double, endMs: Double) -> Bool {
        guard let ctx = context else { return false }
        return insertParagraphFn?(ctx, Int32(index), text, startMs, endMs) == 1
    }
    
    public func removeParagraph(index: Int) -> Bool {
        guard let ctx = context else { return false }
        return removeParagraphFn?(ctx, Int32(index)) == 1
    }
    
    public func renderWaveform(width: Int, height: Int, currentTime: Double, zoom: Double = 10.0, scale: CGFloat = 1.0) -> CGImage? {
        guard let ctx = context else { return nil }
        
        let getAudioFn = unsafeBitCast(dlsym(handle, "se_get_audio_samples"), to: (@convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>) -> UnsafePointer<Float>?).self)
        var count: Int32 = 0
        if let samples = getAudioFn(ctx, &count), count > 0 {
            // Use the new high-performance Swift renderer
            if let image = WaveformRenderer.renderWaveform(samples: samples, count: Int(count), width: width, height: height, currentTime: currentTime, windowSize: zoom, scale: scale) {
                return image
            }
        }

        // Fallback to C# renderer if Swift renderer fails or no samples yet
        var stride: Int32 = 0
        if let ptr = renderWaveformFn?(ctx, Int32(width), Int32(height), currentTime, &stride) {
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let dataProvider = CGDataProvider(data: Data(bytes: ptr, count: width * height * 4) as CFData)
            
            return CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: dataProvider!,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        }
        
        return nil
    }
    
    public func loadSubtitle(path: String) -> Int {
        guard let ctx = context else { return -1 }
        return Int(loadSubtitleFn?(ctx, path) ?? -1)
    }
    
    public func getLineCount() -> Int {
        guard let ctx = context else { return 0 }
        let getLineCountFn = unsafeBitCast(dlsym(handle, "se_get_line_count"), to: (@convention(c) (UnsafeMutableRawPointer) -> Int32).self)
        return Int(getLineCountFn(ctx))
    }
    
    public func getParagraphText(index: Int) -> String? {
        guard let ctx = context, let cStr = getParagraphTextFn?(ctx, Int32(index)) else { return nil }
        let text = String(cString: cStr.assumingMemoryBound(to: Int8.self))
        freeStringFn?(cStr)
        return text
    }
    
    public func getParagraphTimes(index: Int) -> (start: Double, end: Double) {
        guard let ctx = context else { return (0, 0) }
        var start: Double = 0
        var end: Double = 0
        _ = getParagraphTimesFn?(ctx, Int32(index), &start, &end)
        return (start / 1000.0, end / 1000.0) // Return in seconds
    }
}


