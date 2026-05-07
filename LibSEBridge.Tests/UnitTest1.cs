using NUnit.Framework;
using Nikse.SubtitleEdit.Core.Common;
using Nikse.SubtitleEdit.Core.Enums;
using Nikse.SubtitleEdit.Core.SubtitleFormats;
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using SkiaSharp;

namespace LibSEBridge.Tests
{
    public class SubtitleLogicTests
    {
        [Test]
        public void TestUndoRedoStack()
        {
            var sub = new Subtitle();
            sub.Paragraphs.Add(new Paragraph("Hello", 0, 1000));
            
            var history = new System.Collections.Generic.Stack<string>();
            history.Push(sub.ToText(new SubRip()));
            
            sub.Paragraphs[0].Text = "Changed";
            Assert.That(sub.Paragraphs[0].Text, Is.EqualTo("Changed"));
            
            if (history.Count > 0) {
                var prev = history.Pop();
                var lines = Nikse.SubtitleEdit.Core.Common.StringExtensions.SplitToLines(prev);
                sub = Subtitle.Parse(lines, "srt");
            }
            
            Assert.That(sub.Paragraphs[0].Text, Is.EqualTo("Hello"));
        }

        [Test]
        public void TestNativeOcrBridge()
        {
            bool callbackCalled = false;
            string testResult = "Recognized Text";
            
            // Register a mock callback
            NativeOcrStrategy.SetDelegate(new NativeOcrDelegate((buffer, w, h, stride, lang, res, max) => {
                callbackCalled = true;
                byte[] bytes = System.Text.Encoding.UTF8.GetBytes(testResult);
                Marshal.Copy(bytes, 0, res, Math.Min(bytes.Length, max - 1));
                Marshal.WriteByte(res, Math.Min(bytes.Length + 1, max - 1), 0);
            }));

            var strategy = new NativeOcrStrategy();
            var results = strategy.PerformOcr("en", new List<SKBitmap> { new SKBitmap(10, 10) });

            Assert.That(callbackCalled, Is.True, "Native OCR callback should be called");
            Assert.That(results[0], Is.EqualTo(testResult), "Should return the text from native callback");
            
            // Cleanup
            NativeOcrStrategy.SetDelegate(null);
        }

        [Test]
        public void TestSubtitleSorting()
        {
            var sub = new Subtitle();
            sub.Paragraphs.Add(new Paragraph("Line 2", 2000, 3000));
            sub.Paragraphs.Add(new Paragraph("Line 1", 0, 1000));
            sub.Sort(SubtitleSortCriteria.StartTime);
            Assert.That(sub.Paragraphs[0].Text, Is.EqualTo("Line 1"));
        }

        [Test]
        public void TestRegexFindReplace()
        {
            var sub = new Subtitle();
            sub.Paragraphs.Add(new Paragraph("User logged in at 10:00", 0, 1000));
            sub.Paragraphs.Add(new Paragraph("Admin logged in at 11:00", 2000, 3000));
            
            var findText = @"\d{2}:\d{2}";
            var replaceText = "TIME";
            var regex = new System.Text.RegularExpressions.Regex(findText);
            
            int count = 0;
            foreach (var p in sub.Paragraphs)
            {
                if (regex.IsMatch(p.Text))
                {
                    p.Text = regex.Replace(p.Text, replaceText);
                    count++;
                }
            }

            Assert.That(count, Is.EqualTo(2));
            Assert.That(sub.Paragraphs[0].Text, Is.EqualTo("User logged in at TIME"));
            Assert.That(sub.Paragraphs[1].Text, Is.EqualTo("Admin logged in at TIME"));
        }

        [Test]
        public void TestFixCommonErrors()
        {
            var sub = new Subtitle();
            // 1. Overlapping times (One: 0-5000, Two: 500-6000) -> Overlap of 4500ms
            // Durations are 5000ms, which is > default minimum of 1000ms.
            sub.Paragraphs.Add(new Paragraph("One", 0, 5000));
            sub.Paragraphs.Add(new Paragraph("Two", 500, 6000));
            
            // 2. Unneeded spaces
            sub.Paragraphs.Add(new Paragraph("Three  spaces", 8000, 9000));
            
            // 3. Empty line
            sub.Paragraphs.Add(new Paragraph("   ", 10000, 11000));
            
            sub.Renumber();
            
            string log;
            int count = FixEngine.RunCommonFixes(sub, out log);
            
            TestContext.Out.WriteLine("Fix Log:\n" + log);
            
            Assert.That(count, Is.GreaterThan(0), "Should have found some errors");
            TestContext.Out.WriteLine($"Paragraph 0: {sub.Paragraphs[0]}");
            TestContext.Out.WriteLine($"Paragraph 1: {sub.Paragraphs[1]}");
            
            // Check unneeded spaces
            Assert.That(sub.Paragraphs[2].Text, Is.EqualTo("Three spaces"), "Should fix double spaces");
            
            // Check overlap
            double p0End = sub.Paragraphs[0].EndTime.TotalMilliseconds;
            double p1Start = sub.Paragraphs[1].StartTime.TotalMilliseconds;
            Assert.That(p0End, Is.LessThanOrEqualTo(p1Start), $"Should fix overlap. P0 End: {p0End}, P1 Start: {p1Start}");
        }
    }
}
