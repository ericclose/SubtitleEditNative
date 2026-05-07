using System.Runtime.InteropServices;

namespace LibSEBridge;

public static class MpvNative
{
    private const string LibName = "/opt/homebrew/lib/libmpv.dylib"; // macOS

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr mpv_create();

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    public static extern int mpv_initialize(IntPtr ctx);

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    public static extern int mpv_set_option_string(IntPtr ctx, string name, string data);

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    public static extern int mpv_command(IntPtr ctx, IntPtr args);

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    public static extern int mpv_command_string(IntPtr ctx, string args);

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr mpv_get_property_string(IntPtr ctx, string name);

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    public static extern void mpv_free(IntPtr data);

    [DllImport(LibName, CallingConvention = CallingConvention.Cdecl)]
    public static extern void mpv_terminate_destroy(IntPtr ctx);

    // 辅助方法：获取属性值
    public static string? GetProperty(IntPtr ctx, string name)
    {
        if (ctx == IntPtr.Zero) return null;
        IntPtr ptr = mpv_get_property_string(ctx, name);
        if (ptr == IntPtr.Zero) return null;
        string? result = Marshal.PtrToStringUTF8(ptr);
        mpv_free(ptr);
        return result;
    }
    public static void SendCommand(IntPtr ctx, params string[] args)
    {
        if (ctx == IntPtr.Zero) return;
        
        // 为简单起见，我们使用 mpv_command_string 或者手动构建指针数组
        // 这里我们使用最简单的 mpv_command_string 对于单字符串命令
        // 对于多参数命令，我们需要 mpv_command
        string cmd = string.Join(" ", args);
        mpv_command_string(ctx, cmd);
    }
}
