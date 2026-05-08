import Foundation
import AppKit

/// VLCBridge with Hard-Reset and Robust Seek support
class VLCBridge: @unchecked Sendable {
    private var handle: UnsafeMutableRawPointer?
    private var instance: OpaquePointer?
    private var mediaPlayer: OpaquePointer?
    
    private typealias NewInstanceFunc = @convention(c) (Int32, UnsafePointer<UnsafePointer<CChar>?>?) -> OpaquePointer?
    private typealias ReleaseInstanceFunc = @convention(c) (OpaquePointer?) -> Void
    private typealias MediaPlayerNewFunc = @convention(c) (OpaquePointer?) -> OpaquePointer?
    private typealias MediaPlayerReleaseFunc = @convention(c) (OpaquePointer?) -> Void
    private typealias MediaNewPathFunc = @convention(c) (OpaquePointer?, UnsafePointer<CChar>?) -> OpaquePointer?
    private typealias MediaReleaseFunc = @convention(c) (OpaquePointer?) -> Void
    private typealias MediaPlayerSetMediaFunc = @convention(c) (OpaquePointer?, OpaquePointer?) -> Void
    private typealias MediaPlayerPlayFunc = @convention(c) (OpaquePointer?) -> Int32
    private typealias MediaPlayerPauseFunc = @convention(c) (OpaquePointer?) -> Void
    private typealias MediaPlayerStopFunc = @convention(c) (OpaquePointer?) -> Void
    private typealias MediaPlayerSetNSObjectFunc = @convention(c) (OpaquePointer?, UnsafeMutableRawPointer?) -> Void
    private typealias MediaPlayerGetTimeFunc = @convention(c) (OpaquePointer?) -> Int64
    private typealias MediaPlayerSetTimeFunc = @convention(c) (OpaquePointer?, Int64) -> Void
    private typealias MediaPlayerGetLengthFunc = @convention(c) (OpaquePointer?) -> Int64
    private typealias MediaPlayerSetRateFunc = @convention(c) (OpaquePointer?, Float) -> Int32
    private typealias MediaPlayerGetRateFunc = @convention(c) (OpaquePointer?) -> Float
    private typealias MediaPlayerIsPlayingFunc = @convention(c) (OpaquePointer?) -> Int32
    private typealias AudioGetVolumeFunc = @convention(c) (OpaquePointer?) -> Int32
    private typealias AudioSetVolumeFunc = @convention(c) (OpaquePointer?, Int32) -> Int32
    private typealias MediaPlayerGetStateFunc = @convention(c) (OpaquePointer?) -> Int32
    private typealias MediaPlayerGetPositionFunc = @convention(c) (OpaquePointer?) -> Float
    private typealias MediaPlayerSetPositionFunc = @convention(c) (OpaquePointer?, Float) -> Void

    private var _newInstance: NewInstanceFunc?
    private var _releaseInstance: ReleaseInstanceFunc?
    private var _mediaPlayerNew: MediaPlayerNewFunc?
    private var _mediaPlayerRelease: MediaPlayerReleaseFunc?
    private var _mediaNewPath: MediaNewPathFunc?
    private var _mediaRelease: MediaReleaseFunc?
    private var _mediaPlayerSetMedia: MediaPlayerSetMediaFunc?
    private var _mediaPlayerPlay: MediaPlayerPlayFunc?
    private var _mediaPlayerPause: MediaPlayerPauseFunc?
    private var _mediaPlayerStop: MediaPlayerStopFunc?
    private var _mediaPlayerSetNSObject: MediaPlayerSetNSObjectFunc?
    private var _mediaPlayerGetTime: MediaPlayerGetTimeFunc?
    private var _mediaPlayerSetTime: MediaPlayerSetTimeFunc?
    private var _mediaPlayerGetLength: MediaPlayerGetLengthFunc?
    private var _mediaPlayerSetRate: MediaPlayerSetRateFunc?
    private var _mediaPlayerGetRate: MediaPlayerGetRateFunc?
    private var _mediaPlayerIsPlaying: MediaPlayerIsPlayingFunc?
    private var _audioGetVolume: AudioGetVolumeFunc?
    private var _audioSetVolume: AudioSetVolumeFunc?
    private var _mediaPlayerGetState: MediaPlayerGetStateFunc?
    private var _mediaPlayerGetPosition: MediaPlayerGetPositionFunc?
    private var _mediaPlayerSetPosition: MediaPlayerSetPositionFunc?

    init() {
        let bundlePath = Bundle.main.bundlePath
        let frameworksPath = "\(bundlePath)/Contents/Frameworks"
        let libvlcPath = "\(frameworksPath)/libvlc.dylib"
        let pluginsPath = "\(bundlePath)/Contents/MacOS/plugins"
        
        var finalLibPath = libvlcPath
        var finalPluginsPath = pluginsPath
        
        if !FileManager.default.fileExists(atPath: libvlcPath) {
            finalLibPath = "/Applications/VLC.app/Contents/MacOS/lib/libvlc.dylib"
            finalPluginsPath = "/Applications/VLC.app/Contents/MacOS/plugins"
        }
        
        handle = dlopen(finalLibPath, RTLD_NOW)
        
        if let h = handle {
            _newInstance = unsafeBitCast(dlsym(h, "libvlc_new"), to: NewInstanceFunc.self)
            _releaseInstance = unsafeBitCast(dlsym(h, "libvlc_release"), to: ReleaseInstanceFunc.self)
            _mediaPlayerNew = unsafeBitCast(dlsym(h, "libvlc_media_player_new"), to: MediaPlayerNewFunc.self)
            _mediaPlayerRelease = unsafeBitCast(dlsym(h, "libvlc_media_player_release"), to: MediaPlayerReleaseFunc.self)
            _mediaNewPath = unsafeBitCast(dlsym(h, "libvlc_media_new_path"), to: MediaNewPathFunc.self)
            _mediaRelease = unsafeBitCast(dlsym(h, "libvlc_media_release"), to: MediaReleaseFunc.self)
            _mediaPlayerSetMedia = unsafeBitCast(dlsym(h, "libvlc_media_player_set_media"), to: MediaPlayerSetMediaFunc.self)
            _mediaPlayerPlay = unsafeBitCast(dlsym(h, "libvlc_media_player_play"), to: MediaPlayerPlayFunc.self)
            _mediaPlayerPause = unsafeBitCast(dlsym(h, "libvlc_media_player_pause"), to: MediaPlayerPauseFunc.self)
            _mediaPlayerStop = unsafeBitCast(dlsym(h, "libvlc_media_player_stop"), to: MediaPlayerStopFunc.self)
            _mediaPlayerSetNSObject = unsafeBitCast(dlsym(h, "libvlc_media_player_set_nsobject"), to: MediaPlayerSetNSObjectFunc.self)
            _mediaPlayerGetTime = unsafeBitCast(dlsym(h, "libvlc_media_player_get_time"), to: MediaPlayerGetTimeFunc.self)
            _mediaPlayerSetTime = unsafeBitCast(dlsym(h, "libvlc_media_player_set_time"), to: MediaPlayerSetTimeFunc.self)
            _mediaPlayerGetLength = unsafeBitCast(dlsym(h, "libvlc_media_player_get_length"), to: MediaPlayerGetLengthFunc.self)
            _mediaPlayerSetRate = unsafeBitCast(dlsym(h, "libvlc_media_player_set_rate"), to: MediaPlayerSetRateFunc.self)
            _mediaPlayerGetRate = unsafeBitCast(dlsym(h, "libvlc_media_player_get_rate"), to: MediaPlayerGetRateFunc.self)
            _mediaPlayerIsPlaying = unsafeBitCast(dlsym(h, "libvlc_media_player_is_playing"), to: MediaPlayerIsPlayingFunc.self)
            _audioGetVolume = unsafeBitCast(dlsym(h, "libvlc_audio_get_volume"), to: AudioGetVolumeFunc.self)
            _audioSetVolume = unsafeBitCast(dlsym(h, "libvlc_audio_set_volume"), to: AudioSetVolumeFunc.self)
            _mediaPlayerGetState = unsafeBitCast(dlsym(h, "libvlc_media_player_get_state"), to: MediaPlayerGetStateFunc.self)
            _mediaPlayerGetPosition = unsafeBitCast(dlsym(h, "libvlc_media_player_get_position"), to: MediaPlayerGetPositionFunc.self)
            _mediaPlayerSetPosition = unsafeBitCast(dlsym(h, "libvlc_media_player_set_position"), to: MediaPlayerSetPositionFunc.self)

            setenv("VLC_PLUGIN_PATH", finalPluginsPath, 1)
            let args: [String] = [
                "--extraintf=",
                "--vout=macosx",
                "--plugin-path=\(finalPluginsPath)",
                "--no-lua",
                "--no-sub-autodetect-file",
                "--no-osd",
                "--quiet"
            ]
            
            // Correct way to handle C-style string arrays to avoid dangling pointers
            let cArgs = args.map { strdup($0) }
            defer {
                for ptr in cArgs { free(ptr) }
            }
            
            // Map mutable pointers to immutable ones for the C function call
            var cArgsConst = cArgs.map { UnsafePointer<CChar>($0) }
            instance = _newInstance?(Int32(args.count), &cArgsConst)
            
            if let inst = instance {
                mediaPlayer = _mediaPlayerNew?(inst)
            }
        }
    }

    func setDrawable(_ view: NSView) {
        guard let player = mediaPlayer else { return }
        _mediaPlayerSetNSObject?(player, Unmanaged.passUnretained(view).toOpaque())
    }

    func loadMedia(path: String) {
        Logger.shared.log("VLCBridge: Loading media from \(path)")
        guard let inst = instance, let player = mediaPlayer else { 
            Logger.shared.log("VLCBridge: Cannot load media, bridge not initialized", level: .error)
            return 
        }
        path.withCString { cPath in
            let media = _mediaNewPath?(inst, cPath)
            if let m = media {
                _mediaPlayerSetMedia?(player, m)
                _mediaRelease?(m)
                Logger.shared.log("VLCBridge: Media attached to player")
            } else {
                Logger.shared.log("VLCBridge: Failed to create media from path", level: .error)
            }
        }
    }

    func play() { _ = _mediaPlayerPlay?(mediaPlayer) }
    func pause() { _mediaPlayerPause?(mediaPlayer) }
    func stop() { _mediaPlayerStop?(mediaPlayer) }
    
    var time: Double {
        get {
            let ms = _mediaPlayerGetTime?(mediaPlayer) ?? 0
            return Double(ms) / 1000.0
        }
        set {
            if state == 6 { // Ended
                _mediaPlayerStop?(mediaPlayer)
                _ = _mediaPlayerPlay?(mediaPlayer)
                _mediaPlayerPause?(mediaPlayer)
            }
            _mediaPlayerSetTime?(mediaPlayer, Int64(newValue * 1000.0))
        }
    }
    
    var position: Float {
        get { _mediaPlayerGetPosition?(mediaPlayer) ?? 0.0 }
        set {
            if state == 6 { // Ended
                _mediaPlayerStop?(mediaPlayer)
                _ = _mediaPlayerPlay?(mediaPlayer)
                _mediaPlayerPause?(mediaPlayer)
            }
            _mediaPlayerSetPosition?(mediaPlayer, newValue)
        }
    }
    
    var duration: Double {
        let ms = _mediaPlayerGetLength?(mediaPlayer) ?? 0
        return Double(ms) / 1000.0
    }
    
    var rate: Float {
        get { return _mediaPlayerGetRate?(mediaPlayer) ?? 1.0 }
        set { _ = _mediaPlayerSetRate?(mediaPlayer, newValue) }
    }
    
    var isPlaying: Bool {
        return (_mediaPlayerIsPlaying?(mediaPlayer) ?? 0) != 0
    }
    
    var volume: Int {
        get { Int(_audioGetVolume?(mediaPlayer) ?? 100) }
        set { _ = _audioSetVolume?(mediaPlayer, Int32(newValue)) }
    }
    
    var state: Int32 {
        return _mediaPlayerGetState?(mediaPlayer) ?? 0
    }

    deinit {
        if let player = mediaPlayer { _mediaPlayerRelease?(player) }
        if let inst = instance { _releaseInstance?(inst) }
    }
}
