using System.Runtime.InteropServices;
using System.Collections.Concurrent;
using System.Threading;
using System.Linq;
using SkiaSharp;
using Nikse.SubtitleEdit.Core.Common;
using Nikse.SubtitleEdit.Core.SubtitleFormats;

namespace LibSEBridge;

// 定义回调委托：Swift 侧需要提供一个匹配此签名的函数
public delegate void SubtitleOperationCallback(int status, IntPtr messagePtr);
public delegate void ProgressCallback(IntPtr handle, double progress, IntPtr messagePtr);
public delegate void NativeLogDelegate(int level, IntPtr message);

public class SubtitleContext
{
    public GCHandle PixelLock;
    public GCHandle AudioLock;
    public SKBitmap? ActiveBitmap;
    public Subtitle? CurrentSubtitle;
    public Subtitle? CurrentTranslationSubtitle;
    public IntPtr MpvHandle = IntPtr.Zero;
    public float[] AudioSamples = new float[0];
    public ProgressCallback? OnProgress;
    
    // History Management
    public Stack<string> UndoStack = new();
    public Stack<string> RedoStack = new();
}

public static class NativeExports
{
    private static NativeLogDelegate? _logCallback;

    [UnmanagedCallersOnly(EntryPoint = "se_set_log_callback")]
    public static void SetLogCallback(IntPtr callbackPtr)
    {
        if (callbackPtr == IntPtr.Zero) _logCallback = null;
        else _logCallback = Marshal.GetDelegateForFunctionPointer<NativeLogDelegate>(callbackPtr);
        DoLog("Log callback registered in .NET Core");
    }

    public static void DoLog(string message, int level = 0)
    {
        if (_logCallback == null) {
            Console.WriteLine($"[{level}] [.NET] " + message);
            return;
        }
        IntPtr msgPtr = Marshal.StringToCoTaskMemUTF8(message);
        try { _logCallback?.Invoke(level, msgPtr); }
        catch { }
        finally { Marshal.FreeCoTaskMem(msgPtr); }
    }

    private static ConcurrentDictionary<IntPtr, SubtitleContext> _contexts = new();
    private static long _nextId = 1;

    [UnmanagedCallersOnly(EntryPoint = "se_create_context")]
    public static IntPtr CreateContext()
    {
        var ctx = new SubtitleContext();
        var handle = (IntPtr)Interlocked.Increment(ref _nextId);
        _contexts[handle] = ctx;
        DoLog($"Context created with handle {handle}");
        return handle;
    }

    [UnmanagedCallersOnly(EntryPoint = "se_destroy_context")]
    public static void DestroyContext(IntPtr handle)
    {
        if (_contexts.TryRemove(handle, out var ctx))
        {
            if (ctx.PixelLock.IsAllocated) ctx.PixelLock.Free();
            if (ctx.AudioLock.IsAllocated) ctx.AudioLock.Free();
            if (ctx.MpvHandle != IntPtr.Zero) MpvNative.mpv_terminate_destroy(ctx.MpvHandle);
        }
    }

    private static SubtitleContext? GetContext(IntPtr handle) => _contexts.TryGetValue(handle, out var ctx) ? ctx : null;

    [UnmanagedCallersOnly(EntryPoint = "se_set_video_handle")]
    public unsafe static void SetVideoHandle(IntPtr handle, IntPtr nativeWindowHandle)
    {
        var ctx = GetContext(handle);
        if (ctx == null) return;

        if (ctx.MpvHandle != IntPtr.Zero)
        {
            MpvNative.mpv_terminate_destroy(ctx.MpvHandle);
        }

        ctx.MpvHandle = MpvNative.mpv_create();
        if (ctx.MpvHandle == IntPtr.Zero) return;

        MpvNative.mpv_set_option_string(ctx.MpvHandle, "wid", ((long)nativeWindowHandle).ToString());
        MpvNative.mpv_set_option_string(ctx.MpvHandle, "vo", "libmpv");
        MpvNative.mpv_initialize(ctx.MpvHandle);
        DoLog($"Context {handle}: Mpv initialized with handle 0x{nativeWindowHandle:X}");
    }

    [UnmanagedCallersOnly(EntryPoint = "se_play_video")]
    public unsafe static void PlayVideo(IntPtr handle, IntPtr pathPtr)
    {
        var ctx = GetContext(handle);
        if (ctx == null || ctx.MpvHandle == IntPtr.Zero) return;
        
        string? path = Marshal.PtrToStringUTF8(pathPtr);
        if (string.IsNullOrEmpty(path)) return;

        MpvNative.SendCommand(ctx.MpvHandle, "loadfile", $"\"{path}\"");
    }

    [UnmanagedCallersOnly(EntryPoint = "se_video_toggle_pause")]
    public unsafe static void TogglePause(IntPtr handle)
    {
        var ctx = GetContext(handle);
        if (ctx == null || ctx.MpvHandle == IntPtr.Zero) return;
        MpvNative.SendCommand(ctx.MpvHandle, "cycle", "pause");
    }

    [UnmanagedCallersOnly(EntryPoint = "se_video_get_time")]
    public unsafe static double GetVideoTime(IntPtr handle)
    {
        var ctx = GetContext(handle);
        if (ctx == null || ctx.MpvHandle == IntPtr.Zero) return 0;
        string? timeStr = MpvNative.GetProperty(ctx.MpvHandle, "time-pos");
        if (double.TryParse(timeStr, out double time)) return time;
        return 0;
    }

    [UnmanagedCallersOnly(EntryPoint = "se_video_seek")]
    public unsafe static void VideoSeek(IntPtr handle, double seconds)
    {
        var ctx = GetContext(handle);
        if (ctx == null || ctx.MpvHandle == IntPtr.Zero) return;
        MpvNative.SendCommand(ctx.MpvHandle, "seek", seconds.ToString(), "absolute");
    }

    [UnmanagedCallersOnly(EntryPoint = "se_extract_audio")]
    public unsafe static void ExtractAudio(IntPtr handle, IntPtr pathPtr)
    {
        var ctx = GetContext(handle);
        if (ctx == null) return;

        string? path = Marshal.PtrToStringUTF8(pathPtr);
        if (string.IsNullOrEmpty(path) || !File.Exists(path)) return;

        Task.Run(() => {
            try {
                var psi = new System.Diagnostics.ProcessStartInfo {
                    FileName = "/opt/homebrew/bin/ffmpeg",
                    Arguments = $"-i \"{path}\" -f s16le -ac 1 -ar 8000 -t 30 pipe:1",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    CreateNoWindow = true
                };

                using var process = System.Diagnostics.Process.Start(psi);
                if (process == null) return;

                using var ms = new MemoryStream();
                process.StandardOutput.BaseStream.CopyTo(ms);
                process.WaitForExit();

                byte[] rawData = ms.ToArray();
                int sampleCount = rawData.Length / 2;
                ctx.AudioSamples = new float[sampleCount];

                for (int i = 0; i < sampleCount; i++)
                {
                    short sample = BitConverter.ToInt16(rawData, i * 2);
                    ctx.AudioSamples[i] = sample / 32768f;
                }

                // Unpin old and pin new
                if (ctx.AudioLock.IsAllocated) ctx.AudioLock.Free();
                ctx.AudioLock = GCHandle.Alloc(ctx.AudioSamples, GCHandleType.Pinned);

                DoLog($"Context {handle}: Real audio extracted: {ctx.AudioSamples.Length} samples");
            } catch (Exception ex) {
                DoLog($"Context {handle}: FFmpeg Error: {ex.Message}", 2);
            }
        });
    }

    [UnmanagedCallersOnly(EntryPoint = "se_render_waveform_fast")]
    public unsafe static IntPtr RenderWaveformFast(IntPtr handle, int width, int height, double currentTime, int* stride)
    {
        var ctx = GetContext(handle);
        if (ctx == null) return IntPtr.Zero;

        if (ctx.PixelLock.IsAllocated) ctx.PixelLock.Free();

        var info = new SKImageInfo(width, height, SKColorType.Rgba8888, SKAlphaType.Premul);
        ctx.ActiveBitmap = new SKBitmap(info);
        using var canvas = new SKCanvas(ctx.ActiveBitmap);
        canvas.Clear(SKColors.Transparent);

        float midY = height / 2f;
        using var paint = new SKPaint { 
            Color = SKColors.Orange.WithAlpha(180), 
            StrokeWidth = 1, IsAntialias = true, Style = SKPaintStyle.Stroke 
        };

        if (ctx.AudioSamples.Length > 0)
        {
            double windowSize = 10.0;
            double startTime = currentTime - (windowSize / 2.0);
            float samplesPerSecond = 8000;
            float pxPerSecond = width / (float)windowSize;

            for (int x = 0; x < width; x++)
            {
                double timeAtX = startTime + (x / (double)pxPerSecond);
                int sampleIdx = (int)(timeAtX * samplesPerSecond);
                if (sampleIdx >= 0 && sampleIdx < ctx.AudioSamples.Length)
                {
                    float val = ctx.AudioSamples[sampleIdx] * (height / 2.5f);
                    canvas.DrawLine(x, midY - val, x, midY + val, paint);
                }
            }

            if (ctx.CurrentSubtitle != null)
            {
                using var subPaint = new SKPaint { Color = SKColors.Yellow.WithAlpha(100), Style = SKPaintStyle.Fill };
                foreach (var p in ctx.CurrentSubtitle.Paragraphs)
                {
                    double start = p.StartTime.TotalSeconds;
                    double end = p.EndTime.TotalSeconds;
                    if (end < startTime || start > startTime + windowSize) continue;
                    float xStart = (float)((start - startTime) * pxPerSecond);
                    float xEnd = (float)((end - startTime) * pxPerSecond);
                    canvas.DrawRect(xStart, 0, xEnd - xStart, height, subPaint);
                }
            }
        }
        else
        {
            canvas.DrawLine(0, midY, width, midY, paint);
        }

        using var cursorPaint = new SKPaint { Color = SKColors.Red, StrokeWidth = 2 };
        canvas.DrawLine(width / 2f, 0, width / 2f, height, cursorPaint);

        if (stride != null) *stride = ctx.ActiveBitmap.RowBytes;
        IntPtr pixels = ctx.ActiveBitmap.GetPixels();
        ctx.PixelLock = GCHandle.Alloc(ctx.ActiveBitmap, GCHandleType.Normal);
        return pixels;
    }

    [UnmanagedCallersOnly(EntryPoint = "se_load_subtitle")]
    public unsafe static int LoadSubtitle(IntPtr handle, IntPtr pathPtr)
    {
        var ctx = GetContext(handle);
        if (ctx == null) return -1;

        string? path = Marshal.PtrToStringUTF8(pathPtr);
        if (string.IsNullOrEmpty(path) || !File.Exists(path)) {
            DoLog($"Load failed: File not found {path}", 2); // Error
            return -1;
        }

        try
        {
            DoLog($"Loading subtitle: {path}");
            ctx.CurrentSubtitle = Subtitle.Parse(path);
            ctx.UndoStack.Clear();
            ctx.RedoStack.Clear();
            return ctx.CurrentSubtitle?.Paragraphs.Count ?? 0;
        }
        catch (Exception ex)
        {
            DoLog($"Load error: {ex.Message}", 2); // Error
            return -2;
        }
    }

    [UnmanagedCallersOnly(EntryPoint = "se_get_paragraph_text")]
    public unsafe static IntPtr GetParagraphText(IntPtr handle, int index)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentSubtitle == null || index < 0 || index >= ctx.CurrentSubtitle.Paragraphs.Count)
            return IntPtr.Zero;

        return Marshal.StringToCoTaskMemUTF8(ctx.CurrentSubtitle.Paragraphs[index].Text);
    }

    [UnmanagedCallersOnly(EntryPoint = "se_get_paragraph_times")]
    public unsafe static int GetParagraphTimes(IntPtr handle, int index, double* start, double* end)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentSubtitle == null || index < 0 || index >= ctx.CurrentSubtitle.Paragraphs.Count)
            return 0;

        var p = ctx.CurrentSubtitle.Paragraphs[index];
        if (start != null) *start = p.StartTime.TotalMilliseconds;
        if (end != null) *end = p.EndTime.TotalMilliseconds;
        return 1;
    }

    [UnmanagedCallersOnly(EntryPoint = "se_update_paragraph_times")]
    public static void UpdateParagraphTimes(IntPtr handle, int index, double startMs, double endMs)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentSubtitle == null || index < 0 || index >= ctx.CurrentSubtitle.Paragraphs.Count) return;
        
        DoPushHistory(handle);
        var p = ctx.CurrentSubtitle.Paragraphs[index];
        p.StartTime.TotalMilliseconds = startMs;
        p.EndTime.TotalMilliseconds = endMs;
    }

    [UnmanagedCallersOnly(EntryPoint = "se_update_paragraph_text")]
    public unsafe static int UpdateParagraphText(IntPtr handle, int index, IntPtr textPtr)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentSubtitle == null || index < 0 || index >= ctx.CurrentSubtitle.Paragraphs.Count)
            return 0;

        string? text = Marshal.PtrToStringUTF8(textPtr);
        if (text != null)
        {
            ctx.CurrentSubtitle.Paragraphs[index].Text = text;
            return 1;
        }
        return 0;
    }

    [UnmanagedCallersOnly(EntryPoint = "se_find_next")]
    public unsafe static int FindNext(IntPtr handle, IntPtr textPtr, int matchCase, int isRegex, int startIndex)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentSubtitle == null) return -1;
        string? text = Marshal.PtrToStringUTF8(textPtr);
        if (string.IsNullOrEmpty(text)) return -1;

        try {
            if (isRegex == 1) {
                var options = matchCase == 1 ? System.Text.RegularExpressions.RegexOptions.None : System.Text.RegularExpressions.RegexOptions.IgnoreCase;
                var regex = new System.Text.RegularExpressions.Regex(text, options);
                for (int i = startIndex; i < ctx.CurrentSubtitle.Paragraphs.Count; i++) {
                    if (regex.IsMatch(ctx.CurrentSubtitle.Paragraphs[i].Text)) return i;
                }
            } else {
                var comparison = matchCase == 1 ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase;
                for (int i = startIndex; i < ctx.CurrentSubtitle.Paragraphs.Count; i++) {
                    if (ctx.CurrentSubtitle.Paragraphs[i].Text.Contains(text, comparison)) return i;
                }
            }
        } catch { }
        return -1;
    }

    [UnmanagedCallersOnly(EntryPoint = "se_replace_all")]
    public unsafe static int ReplaceAll(IntPtr handle, IntPtr findPtr, IntPtr replacePtr, int matchCase, int isRegex)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentSubtitle == null) return 0;
        DoPushHistory(handle);
        string? findText = Marshal.PtrToStringUTF8(findPtr);
        string? replaceText = Marshal.PtrToStringUTF8(replacePtr);
        if (string.IsNullOrEmpty(findText)) return 0;

        int count = 0;
        try {
            if (isRegex == 1) {
                var options = matchCase == 1 ? System.Text.RegularExpressions.RegexOptions.None : System.Text.RegularExpressions.RegexOptions.IgnoreCase;
                var regex = new System.Text.RegularExpressions.Regex(findText, options);
                foreach (var p in ctx.CurrentSubtitle.Paragraphs) {
                    if (regex.IsMatch(p.Text)) {
                        p.Text = regex.Replace(p.Text, replaceText ?? "");
                        count++;
                    }
                }
            } else {
                var comparison = matchCase == 1 ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase;
                foreach (var p in ctx.CurrentSubtitle.Paragraphs) {
                    if (p.Text.Contains(findText, comparison)) {
                        p.Text = p.Text.Replace(findText, replaceText ?? "", comparison);
                        count++;
                    }
                }
            }
        } catch { }
        return count;
    }

    public static void DoPushHistory(IntPtr handle)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentSubtitle == null) return;
        ctx.UndoStack.Push(ctx.CurrentSubtitle.ToText(new SubRip()));
        ctx.RedoStack.Clear();
    }

    [UnmanagedCallersOnly(EntryPoint = "se_push_history")]
    public static void PushHistory(IntPtr handle) => DoPushHistory(handle);

    [UnmanagedCallersOnly(EntryPoint = "se_undo")]
    public static int Undo(IntPtr handle)
    {
        var ctx = GetContext(handle);
        if (ctx == null || ctx.UndoStack.Count == 0) return 0;
        
        ctx.RedoStack.Push(ctx.CurrentSubtitle!.ToText(new SubRip()));
        string last = ctx.UndoStack.Pop();
        ctx.CurrentSubtitle = Subtitle.Parse(last.SplitToLines(), "srt");
        return 1;
    }

    [UnmanagedCallersOnly(EntryPoint = "se_redo")]
    public static int Redo(IntPtr handle)
    {
        var ctx = GetContext(handle);
        if (ctx == null || ctx.RedoStack.Count == 0) return 0;
        
        ctx.UndoStack.Push(ctx.CurrentSubtitle!.ToText(new SubRip()));
        string next = ctx.RedoStack.Pop();
        ctx.CurrentSubtitle = Subtitle.Parse(next.SplitToLines(), "srt");
        return 1;
    }

    [UnmanagedCallersOnly(EntryPoint = "se_shift_times")]
    public static void ShiftTimes(IntPtr handle, double milliseconds)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentSubtitle == null) return;
        DoPushHistory(handle);
        
        foreach (var p in ctx.CurrentSubtitle.Paragraphs)
        {
            p.StartTime.TotalMilliseconds += milliseconds;
            p.EndTime.TotalMilliseconds += milliseconds;
        }
    }

    [UnmanagedCallersOnly(EntryPoint = "se_save_subtitle")]
    public unsafe static int SaveSubtitle(IntPtr handle, IntPtr pathPtr)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentSubtitle == null) return -1;

        string? path = Marshal.PtrToStringUTF8(pathPtr);
        if (string.IsNullOrEmpty(path)) return -1;

        try
        {
            // 根据后缀名自动查找格式
            string ext = Path.GetExtension(path).ToLower();
            SubtitleFormat? format = SubtitleFormat.AllSubtitleFormats.FirstOrDefault(f => f.Extension == ext);
            
            // 默认回退到 SubRip (SRT)
            format ??= new SubRip();

            File.WriteAllText(path, ctx.CurrentSubtitle.ToText(format), System.Text.Encoding.UTF8);
            return 1;
        }
        catch (Exception ex)
        {
            DoLog($"Save Error: {ex.Message}", 2);
            return -2;
        }
    }

    [UnmanagedCallersOnly(EntryPoint = "se_set_progress_callback")]
    public static void SetProgressCallback(IntPtr handle, IntPtr callbackPtr)
    {
        var ctx = GetContext(handle);
        if (ctx == null) return;
        ctx.OnProgress = Marshal.GetDelegateForFunctionPointer<ProgressCallback>(callbackPtr);
    }

    [UnmanagedCallersOnly(EntryPoint = "se_export_video")]
    public unsafe static void ExportVideo(IntPtr handle, IntPtr videoPathPtr, IntPtr subPathPtr, IntPtr outPathPtr)
    {
        var ctx = GetContext(handle);
        if (ctx == null) return;

        string? videoPath = Marshal.PtrToStringUTF8(videoPathPtr);
        string? subPath = Marshal.PtrToStringUTF8(subPathPtr);
        string? outPath = Marshal.PtrToStringUTF8(outPathPtr);

        if (string.IsNullOrEmpty(videoPath) || string.IsNullOrEmpty(outPath)) return;

        Task.Run(() => {
            try {
                // 如果没有提供外挂字幕路径，尝试保存当前内存中的字幕到临时文件
                string finalSubPath = subPath ?? "";
                bool isTempSub = false;
                if (string.IsNullOrEmpty(finalSubPath) && ctx.CurrentSubtitle != null)
                {
                    finalSubPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".srt");
                    File.WriteAllText(finalSubPath, ctx.CurrentSubtitle.ToText(new SubRip()), System.Text.Encoding.UTF8);
                    isTempSub = true;
                }

                // FFmpeg Hardcode Subtitles: -vf "subtitles=filename"
                // 注意：macOS 下路径需要转义，尤其是 subtitles 滤镜
                string escapedSubPath = finalSubPath.Replace("\\", "/").Replace(":", "\\:");
                var psi = new System.Diagnostics.ProcessStartInfo {
                    FileName = "/opt/homebrew/bin/ffmpeg",
                    Arguments = $"-y -i \"{videoPath}\" -vf \"subtitles='{escapedSubPath}'\" -c:a copy \"{outPath}\"",
                    UseShellExecute = false,
                    RedirectStandardError = true, // FFmpeg 进度在 stderr
                    CreateNoWindow = true
                };

                using var process = System.Diagnostics.Process.Start(psi);
                if (process == null) return;

                // 简单的进度解析逻辑 (解析 FFmpeg 的 "time=HH:MM:SS" 输出)
                while (!process.StandardError.EndOfStream)
                {
                    string? line = process.StandardError.ReadLine();
                    if (line != null && line.Contains("time="))
                    {
                        // 这是一个简单的演示，实际需要解析总时长并对比
                        IntPtr msgPtr = Marshal.StringToCoTaskMemUTF8(line);
                        ctx.OnProgress?.Invoke(handle, 0.5, msgPtr); // 暂时硬编码 0.5 进度演示
                        Marshal.FreeCoTaskMem(msgPtr);
                    }
                }

                process.WaitForExit();
                if (isTempSub) File.Delete(finalSubPath);

                IntPtr donePtr = Marshal.StringToCoTaskMemUTF8("Export Finished!");
                ctx.OnProgress?.Invoke(handle, 1.0, donePtr);
                Marshal.FreeCoTaskMem(donePtr);
            } catch (Exception ex) {
                DoLog($"Export Error: {ex.Message}", 2);
            }
        });
    }

    [UnmanagedCallersOnly(EntryPoint = "se_update_style")]
    public unsafe static void UpdateStyle(IntPtr handle, IntPtr fontPtr, double size, IntPtr colorPtr)
    {
        var ctx = GetContext(handle);
        if (ctx == null || ctx.MpvHandle == IntPtr.Zero) return;

        string? font = Marshal.PtrToStringUTF8(fontPtr);
        string? color = Marshal.PtrToStringUTF8(colorPtr);

        if (!string.IsNullOrEmpty(font))
            MpvNative.SendCommand(ctx.MpvHandle, "set", "sub-font", font);
        
        MpvNative.SendCommand(ctx.MpvHandle, "set", "sub-font-size", size.ToString());

        if (!string.IsNullOrEmpty(color))
        {
            // mpv color is in hex format but usually needs a specific prefix or format
            // example: "set sub-color #RRGGBB"
            MpvNative.SendCommand(ctx.MpvHandle, "set", "sub-color", color);
        }

        DoLog($"Context {handle}: Style updated: {font}, {size}pt, {color}");
    }

    [UnmanagedCallersOnly(EntryPoint = "se_get_line_count")]
    public static int GetLineCount(IntPtr handle) => GetContext(handle)?.CurrentSubtitle?.Paragraphs.Count ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "se_free_string")]
    public static void FreeString(IntPtr ptr) => Marshal.FreeCoTaskMem(ptr);

    [UnmanagedCallersOnly(EntryPoint = "se_speech_to_text")]
    public static void SpeechToText(IntPtr handle, IntPtr videoPathPtr)
    {
        var ctx = GetContext(handle);
        if (ctx == null) return;
        string? videoPath = Marshal.PtrToStringUTF8(videoPathPtr);
        if (string.IsNullOrEmpty(videoPath)) return;

        Task.Run(async () => {
            try {
                // 1. Audio Extraction (16-bit PCM 16kHz for Whisper)
                string audioPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".wav");
                IntPtr msgStart = Marshal.StringToCoTaskMemUTF8("Extracting audio (16kHz PCM)...");
                ctx.OnProgress?.Invoke(handle, 0.1, msgStart);
                Marshal.FreeCoTaskMem(msgStart);

                var ffmpeg = new System.Diagnostics.ProcessStartInfo {
                    FileName = "/opt/homebrew/bin/ffmpeg",
                    Arguments = $"-y -i \"{videoPath}\" -ar 16000 -ac 1 -c:a pcm_s16le \"{audioPath}\"",
                    UseShellExecute = false, CreateNoWindow = true
                };
                System.Diagnostics.Process.Start(ffmpeg)?.WaitForExit();

                // 2. Real Whisper.cpp Integration
                string whisperPath = "/opt/homebrew/bin/whisper-cpp";
                if (File.Exists(whisperPath))
                {
                    IntPtr msgWhisper = Marshal.StringToCoTaskMemUTF8("Running Whisper.cpp engine...");
                    ctx.OnProgress?.Invoke(handle, 0.3, msgWhisper);
                    Marshal.FreeCoTaskMem(msgWhisper);

                    string srtPath = audioPath + ".srt";
                    var whisper = new System.Diagnostics.ProcessStartInfo {
                        FileName = whisperPath,
                        Arguments = $"-m /opt/homebrew/share/whisper-cpp/models/ggml-base.bin -f \"{audioPath}\" -osrt",
                        UseShellExecute = false, CreateNoWindow = true
                    };
                    System.Diagnostics.Process.Start(whisper)?.WaitForExit();

                    if (File.Exists(srtPath))
                    {
                        DoPushHistory(handle);
                        ctx.CurrentSubtitle = Subtitle.Parse(srtPath);
                        File.Delete(srtPath);
                    }
                }
                else
                {
                    // Fallback to simulation if whisper-cpp not found
                    await Task.Delay(2000);
                    DoPushHistory(handle);
                    ctx.CurrentSubtitle ??= new Subtitle();
                    ctx.CurrentSubtitle.Paragraphs.Add(new Paragraph("Whisper binary not found. Simulation mode.", 1000, 4000));
                }

                if (File.Exists(audioPath)) File.Delete(audioPath);
                
                IntPtr msgDone = Marshal.StringToCoTaskMemUTF8("STT Process Complete");
                ctx.OnProgress?.Invoke(handle, 1.0, msgDone);
                Marshal.FreeCoTaskMem(msgDone);
            } catch (Exception ex) {
                DoLog("STT Error: " + ex.Message, 2);
            }
        });
    }

    [UnmanagedCallersOnly(EntryPoint = "se_translate")]
    public static void Translate(IntPtr handle, IntPtr targetLanguagePtr)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentSubtitle == null) return;
        string? targetLang = Marshal.PtrToStringUTF8(targetLanguagePtr) ?? "en";

        Task.Run(async () => {
            try {
                DoPushHistory(handle);
                // 使用 GoogleTranslateV2 作为示例
                var translator = new Nikse.SubtitleEdit.Core.AutoTranslate.GoogleTranslateV2();
                
                int total = ctx.CurrentSubtitle.Paragraphs.Count;
                for (int i = 0; i < total; i++)
                {
                    var p = ctx.CurrentSubtitle.Paragraphs[i];
                    try {
                        // 模拟异步翻译过程（实际调用网络 API）
                        // 注意：这里为了演示使用简单替换，实际应调用 translator.Translate(...)
                        p.Text = "[TR-" + targetLang + "] " + p.Text;
                        
                        double progress = (double)(i + 1) / total;
                        IntPtr msgPtr = Marshal.StringToCoTaskMemUTF8($"Translating line {i + 1}/{total}...");
                        ctx.OnProgress?.Invoke(handle, progress, msgPtr);
                        Marshal.FreeCoTaskMem(msgPtr);
                    } catch { }
                    
                    if (i % 10 == 0) await Task.Delay(50); // 避免 UI 假死
                }
                
                IntPtr donePtr = Marshal.StringToCoTaskMemUTF8("Translation Finished");
                ctx.OnProgress?.Invoke(handle, 1.0, donePtr);
                Marshal.FreeCoTaskMem(donePtr);
            } catch (Exception ex) {
                DoLog("Translate Error: " + ex.Message, 2);
            }
        });
    }

    [UnmanagedCallersOnly(EntryPoint = "se_merge_subtitles")]
    public unsafe static int MergeSubtitles(IntPtr handle, IntPtr otherPathPtr)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentSubtitle == null) return 0;
        string? otherPath = Marshal.PtrToStringUTF8(otherPathPtr);
        if (string.IsNullOrEmpty(otherPath) || !File.Exists(otherPath)) return 0;

        try {
            DoPushHistory(handle);
            var otherSub = new Subtitle();
            otherSub.LoadSubtitle(otherPath, out _, null);
            foreach (var p in otherSub.Paragraphs) {
                ctx.CurrentSubtitle.Paragraphs.Add(new Paragraph(p));
            }
            ctx.CurrentSubtitle.Sort(Nikse.SubtitleEdit.Core.Enums.SubtitleSortCriteria.StartTime);
            return 1;
        } catch {
            return -1;
        }
    }

    [UnmanagedCallersOnly(EntryPoint = "se_load_translation")]
    public unsafe static int LoadTranslation(IntPtr handle, IntPtr pathPtr)
    {
        var ctx = GetContext(handle);
        if (ctx == null) return -1;
        string? path = Marshal.PtrToStringUTF8(pathPtr);
        if (string.IsNullOrEmpty(path) || !File.Exists(path)) return -1;
        ctx.CurrentTranslationSubtitle = Subtitle.Parse(path);
        return ctx.CurrentTranslationSubtitle?.Paragraphs.Count ?? 0;
    }

    [UnmanagedCallersOnly(EntryPoint = "se_get_translation_text")]
    public unsafe static IntPtr GetTranslationText(IntPtr handle, int index)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentTranslationSubtitle == null || index < 0 || index >= ctx.CurrentTranslationSubtitle.Paragraphs.Count)
            return IntPtr.Zero;
        return Marshal.StringToCoTaskMemUTF8(ctx.CurrentTranslationSubtitle.Paragraphs[index].Text);
    }

    [UnmanagedCallersOnly(EntryPoint = "se_update_translation_text")]
    public unsafe static void UpdateTranslationText(IntPtr handle, int index, IntPtr textPtr)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentTranslationSubtitle == null || index < 0 || index >= ctx.CurrentTranslationSubtitle.Paragraphs.Count) return;
        string? text = Marshal.PtrToStringUTF8(textPtr);
        ctx.CurrentTranslationSubtitle.Paragraphs[index].Text = text ?? "";
    }

    [UnmanagedCallersOnly(EntryPoint = "se_fix_common_errors")]
    public unsafe static int FixCommonErrors(IntPtr handle, IntPtr* logPtr)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentSubtitle == null) return 0;
        
        DoPushHistory(handle);
        int count = FixEngine.RunCommonFixes(ctx.CurrentSubtitle, out string log);
        
        if (logPtr != null)
        {
            *logPtr = Marshal.StringToCoTaskMemUTF8(log);
        }
        
        return count;
    }

    [UnmanagedCallersOnly(EntryPoint = "se_set_native_ocr_callback")]
    public static void SetNativeOcrCallback(IntPtr callbackPtr)
    {
        if (callbackPtr == IntPtr.Zero)
        {
            NativeOcrStrategy.SetDelegate(null);
            return;
        }

        var del = Marshal.GetDelegateForFunctionPointer<NativeOcrDelegate>(callbackPtr);
        NativeOcrStrategy.SetDelegate(del);
    }

    [UnmanagedCallersOnly(EntryPoint = "se_get_audio_samples")]
    public unsafe static IntPtr GetAudioSamples(IntPtr handle, int* count)
    {
        var ctx = GetContext(handle);
        if (ctx == null || ctx.AudioSamples.Length == 0 || !ctx.AudioLock.IsAllocated)
        {
            if (count != null) *count = 0;
            return IntPtr.Zero;
        }

        if (count != null) *count = ctx.AudioSamples.Length;
        return ctx.AudioLock.AddrOfPinnedObject();
    }

    [UnmanagedCallersOnly(EntryPoint = "se_insert_paragraph")]
    public unsafe static int InsertParagraph(IntPtr handle, int index, IntPtr textPtr, double startMs, double endMs)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentSubtitle == null) return 0;

        DoPushHistory(handle);
        string? text = Marshal.PtrToStringUTF8(textPtr) ?? "";
        var p = new Paragraph(text, startMs, endMs);
        
        if (index < 0) ctx.CurrentSubtitle.Paragraphs.Insert(0, p);
        else if (index >= ctx.CurrentSubtitle.Paragraphs.Count) ctx.CurrentSubtitle.Paragraphs.Add(p);
        else ctx.CurrentSubtitle.Paragraphs.Insert(index, p);
        
        return 1;
    }

    [UnmanagedCallersOnly(EntryPoint = "se_remove_paragraph")]
    public static int RemoveParagraph(IntPtr handle, int index)
    {
        var ctx = GetContext(handle);
        if (ctx?.CurrentSubtitle == null || index < 0 || index >= ctx.CurrentSubtitle.Paragraphs.Count) return 0;

        DoPushHistory(handle);
        ctx.CurrentSubtitle.Paragraphs.RemoveAt(index);
        return 1;
    }
}
