using System.Runtime.InteropServices;
using Nikse.SubtitleEdit.Core.Common;
using Nikse.SubtitleEdit.Core.Interfaces;
using Nikse.SubtitleEdit.Core.SubtitleFormats;
using Nikse.SubtitleEdit.Core.Forms.FixCommonErrors;
using System.Text;

namespace LibSEBridge;

public class NativeFixCallbacks : IFixCallbacks
{
    public List<string> FixLog = new();
    public int FixCount = 0;

    public bool AllowFix(Paragraph p, string action) => true;
    public void AddFixToListView(Paragraph p, string action, string before, string after) 
    {
        FixCount++;
        FixLog.Add($"{action}: {before} -> {after}");
    }
    public void AddFixToListView(Paragraph p, string action, string before, string after, bool isChecked)
    {
        if (isChecked) AddFixToListView(p, action, before, after);
    }
    public void LogStatus(string sender, string message) { }
    public void LogStatus(string sender, string message, bool isImportant) { }
    public void UpdateFixStatus(int fixes, string message) { }
    public bool IsName(string candidate) => false;
    public HashSet<string> GetAbbreviations() => new();
    public void AddToTotalErrors(int count) { }
    public void AddToDeleteIndices(int index) { }
    
    public SubtitleFormat Format => new SubRip();
    public Encoding Encoding => Encoding.UTF8;
    public string Language => "en";
}

public static class FixEngine
{
    public static int RunCommonFixes(Subtitle subtitle, out string log)
    {
        var callbacks = new NativeFixCallbacks();
        
        var fixers = new List<IFixCommonError>
        {
            new FixEmptyLines(),
            new FixOverlappingDisplayTimes(),
            new FixShortDisplayTimes(),
            new FixLongDisplayTimes(),
            new FixInvalidItalicTags(),
            new FixUnneededSpaces(),
            new FixMissingSpaces(),
            new FixShortLines(),
            new FixLongLines(),
            new FixDoubleDash(),
            new FixDoubleApostrophes()
        };

        foreach (var fixer in fixers)
        {
            fixer.Fix(subtitle, callbacks);
        }

        log = string.Join("\n", callbacks.FixLog);
        return callbacks.FixCount;
    }
}
