import Foundation
import AppKit

// 1. 定义 C 兼容的回调签名
typealias SubtitleOperationCallback = @convention(c) (Int32, UnsafePointer<Int8>) -> Void

// 2. 函数类型定义
typealias RenderWaveformFastFunc = @convention(c) (Int32, Int32, UnsafeMutablePointer<Int32>) -> UnsafeRawPointer?
typealias StartAsyncJobFunc = @convention(c) (UnsafeMutableRawPointer) -> Void
typealias LoadSubtitleFunc = @convention(c) (UnsafePointer<Int8>) -> Int32
typealias GetParagraphTextFunc = @convention(c) (Int32) -> UnsafePointer<Int8>?
typealias GetParagraphTimesFunc = @convention(c) (Int32, UnsafeMutablePointer<Double>, UnsafeMutablePointer<Double>) -> Int32
typealias FreeStringFunc = @convention(c) (UnsafeMutableRawPointer) -> Void

// 加载库
let libPath = "./LibSEBridge.dylib"
guard let handle = dlopen(libPath, RTLD_NOW) else { 
    print("Failed to load library: \(String(cString: dlerror()))")
    exit(1) 
}

func getFunction<T>(name: String) -> T? {
    guard let sym = dlsym(handle, name) else { return nil }
    return unsafeBitCast(sym, to: T.self)
}

// 独立的、不捕获任何变量的回调函数
let myNativeCallback: SubtitleOperationCallback = { (status, msgPtr) in
    let message = String(cString: msgPtr)
    print("\n[Swift CALLBACK] Received status \(status) from .NET!")
    print("[Swift CALLBACK] Message: \(message)")
}

if let loadSubtitle: LoadSubtitleFunc = getFunction(name: "se_load_subtitle"),
   let getParagraphText: GetParagraphTextFunc = getFunction(name: "se_get_paragraph_text"),
   let getParagraphTimes: GetParagraphTimesFunc = getFunction(name: "se_get_paragraph_times"),
   let freeString: FreeStringFunc = getFunction(name: "se_free_string"),
   let startAsyncJob: StartAsyncJobFunc = getFunction(name: "se_start_async_job") {

    print("--- P4/P5 PoC: 综合功能测试 ---")

    // 1. 测试零拷贝波形渲染 (P4)
    if let renderFast: RenderWaveformFastFunc = getFunction(name: "se_render_waveform_fast") {
        var stride: Int32 = 0
        if let pixelPtr = renderFast(100, 100, &stride) {
            print("[Swift] Received ZERO-COPY buffer at \(pixelPtr), Stride: \(stride)")
            // 尝试读取第一个像素 (RGBA)
            let pixels = pixelPtr.bindMemory(to: UInt32.self, capacity: 1)
            print("[Swift] First pixel color (Hex): \(String(format: "%08X", pixels.pointee))")
        }
    }

    // 2. 测试加载字幕 (P5)
    let srtPath = "test.srt"
    let lineCount = loadSubtitle(srtPath)
    print("[Swift] Loaded '\(srtPath)', Line Count: \(lineCount)")

    if lineCount > 0 {
        for i in 0..<lineCount {
            var start: Double = 0
            var end: Double = 0
            if getParagraphTimes(i, &start, &end) == 1 {
                if let cStr = getParagraphText(i) {
                    let text = String(cString: cStr)
                    print("[Swift] Line \(i+1): [\(start) -> \(end)] \(text)")
                    freeString(UnsafeMutableRawPointer(mutating: cStr))
                }
            }
        }
    }

    // 2. 测试原生异步回调
    print("\n[Swift] Starting async job in .NET...")
    let callbackPtr = unsafeBitCast(myNativeCallback, to: UnsafeMutableRawPointer.self)
    startAsyncJob(callbackPtr)

    print("[Swift] Waiting for .NET to call us back...")
    Thread.sleep(forTimeInterval: 2.0)

    print("--- P5 测试完成 ---")
} else {
    print("Failed to find some functions.")
}

dlclose(handle)
