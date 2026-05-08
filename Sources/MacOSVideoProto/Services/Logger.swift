import Foundation
import AppKit

enum LogLevel: String {
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
    case debug = "DEBUG"
}

class Logger {
    static let shared = Logger()
    private let logURL: URL
    private let queue = DispatchQueue(label: "com.innovation.logger")
    
    private init() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        logURL = desktop.appendingPathComponent("SubtitleEdit_Debug.log")
        
        // Reset log and write header
        let header = """
        ====================================================
        SubtitleEdit Native Debug Log
        Started: \(Date().description)
        OS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Process: \(ProcessInfo.processInfo.processName) (\(ProcessInfo.processInfo.processIdentifier))
        Physical Memory: \(ProcessInfo.processInfo.physicalMemory / 1024 / 1024 / 1024) GB
        ====================================================
        
        """
        try? header.write(to: logURL, atomically: true, encoding: .utf8)
    }
    
    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let thread = Thread.isMainThread ? "Main" : "Bg"
        let fullMessage = "[\(timestamp)] [\(level.rawValue)] [\(thread)] \(message)\n"
        
        print(fullMessage)
        
        queue.async {
            if let data = fullMessage.data(using: .utf8) {
                if let fileHandle = try? FileHandle(forWritingTo: self.logURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            }
        }
    }
    
    func error(_ message: String, error: Error? = nil) {
        var msg = message
        if let e = error {
            msg += " | Details: \(e.localizedDescription)"
        }
        log(msg, level: .error)
    }
}
