using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using SkiaSharp;
using Nikse.SubtitleEdit.Core.VobSub.Ocr.Service;

namespace LibSEBridge
{
    public delegate void NativeOcrDelegate(IntPtr imageBuffer, int width, int height, int stride, string language, IntPtr resultBuffer, int resultMaxSize);

    public class NativeOcrStrategy : IOcrStrategy
    {
        private static NativeOcrDelegate? _ocrDelegate;

        public static void SetDelegate(NativeOcrDelegate? ocrDelegate)
        {
            _ocrDelegate = ocrDelegate;
        }

        public string GetName() => "Apple Vision OCR (Native)";

        public string GetUrl() => "https://developer.apple.com/documentation/vision";

        public List<string> PerformOcr(string language, List<SKBitmap> images)
        {
            var results = new List<string>();
            if (_ocrDelegate == null) return results;

            foreach (var bitmap in images)
            {
                var info = bitmap.Info;
                var pixels = bitmap.GetPixels();
                
                // Allocate a buffer for the result string (UTF-8)
                int maxResultSize = 4096;
                IntPtr resultPtr = Marshal.AllocHGlobal(maxResultSize);
                
                try
                {
                    _ocrDelegate(pixels, info.Width, info.Height, bitmap.RowBytes, language, resultPtr, maxResultSize);
                    string? result = Marshal.PtrToStringAnsi(resultPtr); // Bridge handles encoding
                    results.Add(result ?? string.Empty);
                }
                finally
                {
                    Marshal.FreeHGlobal(resultPtr);
                }
            }

            return results;
        }

        public int GetMaxImageSize() => 4096;
        public int GetMaximumRequestArraySize() => 100;

        public List<OcrLanguage> GetLanguages()
        {
            return new List<OcrLanguage>
            {
                new OcrLanguage { Code = "en" },
                new OcrLanguage { Code = "zh-Hans" },
                new OcrLanguage { Code = "zh-Hant" },
                new OcrLanguage { Code = "fr" },
                new OcrLanguage { Code = "de" },
                new OcrLanguage { Code = "it" },
                new OcrLanguage { Code = "ja" },
                new OcrLanguage { Code = "ko" },
                new OcrLanguage { Code = "pt" },
                new OcrLanguage { Code = "ru" },
                new OcrLanguage { Code = "es" }
            };
        }
    }
}
